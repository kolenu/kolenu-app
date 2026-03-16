import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:just_audio/just_audio.dart';

import '../data/playback_mode.dart';
import '../data/playback_speed.dart';
import '../models/prayer.dart';
import '../services/audio_decryption_service.dart';
import '../services/loop_preference_service.dart';
import '../services/text_alignment_preference_service.dart';
import '../services/playback_speed_preference_service.dart';
import '../services/prayer_service.dart';
import '../services/song_download_service.dart';
import '../services/transliteration_service.dart';
import 'settings_screen.dart';

/// What to show below each Hebrew word.
enum WordHintMode { hebrewOnly, translation, transliteration }

/// Icon for word hint mode (Hebrew א, א|A, א|abc) - uses Flutter Text so Hebrew renders.
class _WordHintIcon extends StatelessWidget {
  const _WordHintIcon({required this.mode, this.size = 56});

  final WordHintMode mode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = colorScheme.primaryContainer;
    final fgColor = colorScheme.onPrimaryContainer;

    final child = switch (mode) {
      WordHintMode.hebrewOnly => Text(
        'א',
        style: TextStyle(fontSize: 36, color: fgColor),
      ),
      WordHintMode.translation => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('א', style: TextStyle(fontSize: 28, color: fgColor)),
          const SizedBox(width: 4),
          Text('A', style: TextStyle(fontSize: 28, color: fgColor)),
        ],
      ),
      WordHintMode.transliteration => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('א', style: TextStyle(fontSize: 24, color: fgColor)),
          const SizedBox(width: 4),
          Text('abc', style: TextStyle(fontSize: 18, color: fgColor)),
        ],
      ),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      alignment: Alignment.center,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}

class PrayerReaderScreen extends StatefulWidget {
  const PrayerReaderScreen({
    super.key,
    required this.prayerId,
    required this.prayerFile,
    required this.title,
    required this.titleHebrew,
    this.selectedRecordingId,
    this.difficulty,
    this.localSongFolderId,
    this.playlistIds,
    this.currentPlaylistIndex = 0,
  });

  final String prayerId;
  final String prayerFile;
  final String title;
  final String titleHebrew;

  /// If set, use this recording's audio when prayer has multiple recordings.
  final String? selectedRecordingId;

  /// Optional difficulty level (L1–L4) for practice hints.
  final String? difficulty;

  /// When set, load content and audio from local Songs/ folder (cloud download).
  final String? localSongFolderId;

  /// When set, we're playing from a playlist; used for loop-playlist mode.
  final List<String>? playlistIds;

  /// Index of current prayer in [playlistIds].
  final int currentPlaylistIndex;

  @override
  State<PrayerReaderScreen> createState() => _PrayerReaderScreenState();
}

class _PrayerReaderScreenState extends State<PrayerReaderScreen>
    with SingleTickerProviderStateMixin {
  PrayerContent? _content;
  bool _loading = true;
  String? _error;
  String? _audioError;

  late AudioPlayer _player;
  File? _currentAudioFile; // Track temporary decrypted audio file for cleanup
  StreamSubscription<Duration>? _positionSub;
  int _currentWordIndex = -1;
  double _currentContentSeconds = 0;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _currentWordKey = GlobalKey();

  /// Word hint mode: Hebrew only, or show translation/transliteration below each word.
  WordHintMode _wordHintMode = WordHintMode.hebrewOnly;
  int? _tappedWordIndex;
  double _prayerTextScale = 1.0;
  double _scaleStart = 1.0;
  PlaybackSpeed _playbackSpeed = PlaybackSpeed.normal;
  PlaybackMode _playbackMode = PlaybackMode.playOnce;
  bool _playButtonPressed = false;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<bool>? _playingSub;
  late AnimationController _pulseController;
  bool _controlsVisible = true;
  Timer? _controlsAutoHideTimer;
  Timer? _tapRevealTimer;
  Timer? _autoScrollTimer;
  Timer? _visibilityCheckTimer;
  DateTime? _autoScrollPausedUntil;
  int? _activePointerId;
  Offset? _pointerDownPosition;
  bool _pointerMoved = false;

  static const Duration _controlsAutoHideDelay = Duration(seconds: 3);
  static const Duration _tapRevealDebounce = Duration(milliseconds: 120);
  static const Duration _autoScrollAfterIdle = Duration(seconds: 3);
  static const Duration _autoScrollPauseAfterUserScroll = Duration(seconds: 3);
  static const Duration _visibilityCheckInterval = Duration(seconds: 1);
  static const double _tapMovementThreshold = 12.0;
  static const double _minPrayerScale = 0.6;
  static const double _maxPrayerScale = 2.0;

  /// After this many loops, ask if user is still listening (saves battery).
  static const int _stillListeningThreshold = 10;

  int _singleLoopCount = 0;
  int _playlistCycleCount = 0;
  bool _waitingForStillListeningResponse = false;

  static const String _prayersAssetPath = 'assets/audio';

  /// Base path for this prayer's assets (e.g. "shema" when file is "shema/content.json", else "").
  String get _prayerAssetBase {
    final f = widget.prayerFile;
    final i = f.lastIndexOf('/');
    return i >= 0 ? f.substring(0, i) : '';
  }

  /// Duration of the text content in seconds (last word end). When audio is longer, we loop.
  double _contentDurationSeconds(PrayerContent? c) {
    if (c == null || c.words.isEmpty) return 0;
    return c.words.last.end;
  }

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _playingSub = _player.playingStream.listen((playing) {
      if (mounted) {
        if (playing) {
          _pulseController.repeat(reverse: true);
          _scheduleAutoHideControls();
          _scheduleVisibilityChecks();
        } else {
          _pulseController.stop();
          _pulseController.reset();
          _cancelControlsAutoHide();
          _visibilityCheckTimer?.cancel();
          _visibilityCheckTimer = null;
          if (!_controlsVisible) {
            setState(() => _controlsVisible = true);
          }
        }
      }
    });
    _loadPlaybackSpeed();
    _loadLoopPreference();
    _loadContent();
    _scrollController.addListener(_onScrollPositionChanged);
  }

  void _onScrollPositionChanged() {
    _autoScrollPausedUntil = DateTime.now().add(
      _autoScrollPauseAfterUserScroll,
    );
    _cancelAutoScrollTimer();
  }

  void _scheduleVisibilityChecks() {
    _visibilityCheckTimer?.cancel();
    void scheduleNext() {
      _visibilityCheckTimer = Timer(_visibilityCheckInterval, () {
        if (!mounted || !_player.playing) return;
        _visibilityCheckTimer = null;
        if (_currentWordIndex >= 0) {
          _ensureCurrentWordVisible();
        }
        if (mounted && _player.playing) {
          scheduleNext();
        }
      });
    }

    scheduleNext();
  }

  Future<void> _loadPlaybackSpeed() async {
    final speed = await PlaybackSpeedPreferenceService.getSpeed();
    if (mounted) {
      setState(() => _playbackSpeed = speed);
    }
  }

  Future<void> _loadLoopPreference() async {
    final mode = await LoopPreferenceService.getPlaybackMode();
    if (mounted) {
      setState(() => _playbackMode = mode);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollPositionChanged);
    _scrollController.dispose();
    _cancelControlsAutoHide();
    _cancelAutoScrollTimer();
    _visibilityCheckTimer?.cancel();
    _tapRevealTimer?.cancel();
    _playingSub?.cancel();
    _pulseController.dispose();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    // Clean up temporary decrypted audio file
    if (_currentAudioFile != null) {
      AudioDecryptionService.deleteTemporaryFile(_currentAudioFile!);
    }
    super.dispose();
  }

  Future<void> _loadContent() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      PrayerContent content;
      String? audioFile;

      if (widget.localSongFolderId != null) {
        content = await PrayerService.loadPrayerContentFromLocal(
          widget.localSongFolderId!,
          id: widget.prayerId,
          title: widget.title,
          titleHebrew: widget.titleHebrew,
        );
        audioFile = 'audio.enc';
      } else {
        content = await PrayerService.loadPrayerContent(
          widget.prayerFile,
          id: widget.prayerId,
          title: widget.title,
          titleHebrew: widget.titleHebrew,
        );
        audioFile = content.resolveAudioFile(widget.selectedRecordingId, []);
      }

      if (!mounted) return;
      setState(() {
        _content = content;
        _loading = false;
        if (audioFile == null) _audioError = 'Audio is not available for this prayer.';
      });
      if (audioFile != null) {
        if (widget.localSongFolderId != null) {
          await _initAudioFromLocal(widget.localSongFolderId!);
        } else {
          final base = _prayerAssetBase;
          final path = base.isEmpty ? audioFile : '$base/$audioFile';
          await _initAudio(path);
        }
      }
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      debugPrint('PrayerReaderScreen load error: $e\n$st');
    }
  }

  Future<void> _initAudioFromLocal(String songFolderId) async {
    try {
      final songPath = await SongDownloadService.getSongPath(songFolderId);
      final encryptedFile = File('$songPath/audio.enc');
      if (!await encryptedFile.exists()) {
        throw Exception('audio.enc not found');
      }
      final decryptedFile = await AudioDecryptionService.decryptFromFile(
        encryptedFile,
      );
      _currentAudioFile = decryptedFile;
      await _player.setFilePath(decryptedFile.path);
      await _setupPlayerAndSync();
    } catch (e, st) {
      debugPrint('Audio init error (local): $e\n$st');
      if (mounted) {
        setState(() => _audioError = 'Could not find .mp3');
      }
    }
  }

  Future<void> _initAudio(String audioFile) async {
    try {
      final encryptedFile = audioFile.endsWith('.enc')
          ? audioFile
          : audioFile.replaceAll('.mp3', '.enc');
      final assetPath = '$_prayersAssetPath/$encryptedFile';

      final decryptedFile = await AudioDecryptionService.decryptAudioFile(
        assetPath,
      );
      _currentAudioFile = decryptedFile;
      await _player.setFilePath(decryptedFile.path);
      await _setupPlayerAndSync();
    } catch (e, st) {
      debugPrint('Audio init error: $e\n$st');
      if (mounted) {
        setState(() => _audioError = 'Could not find .mp3');
      }
    }
  }

  Future<void> _setupPlayerAndSync() async {
    await _player.setSpeed(_playbackSpeed.rate);
    final loopOne = _playbackMode == PlaybackMode.loopOne;
    await _player.setLoopMode(loopOne ? LoopMode.one : LoopMode.off);
    final offset = _content?.audioOffsetSeconds ?? 0;
    if (offset > 0) {
      await _player.seek(Duration(milliseconds: (offset * 1000).round()));
    }
    await _positionSub?.cancel();
    _positionSub = _player.positionStream.listen((pos) {
      if (!mounted) return;
      double sec = pos.inMilliseconds / 1000.0;
      final content = _content;
      final offset = content?.audioOffsetSeconds ?? 0;
      sec = (sec - offset).clamp(0.0, double.infinity);
      final duration = content != null ? _contentDurationSeconds(content) : 0.0;
      if (duration > 0) {
        if (_playbackMode == PlaybackMode.loopOne) {
          sec = sec % duration;
        } else if (sec > duration) {
          sec = duration;
        }
      }
      final secForSync = sec;
      final newIndex = _wordIndexAtPosition(secForSync);

      // Pronounce-word-only mode: pause when we reach the word's end
      // In play-once mode, stay on last word when past end. In loop-one, allow
      // pointer to jump back when audio restarts.
      if (_playbackMode != PlaybackMode.loopOne &&
          _currentWordIndex == (content?.words.length ?? 0) - 1 &&
          newIndex < _currentWordIndex) {
        return;
      }
      final wasAtEnd =
          content != null &&
          content.words.isNotEmpty &&
          _currentWordIndex == content.words.length - 1;
      final wordChanged = newIndex != _currentWordIndex;
      setState(() {
        _currentWordIndex = newIndex;
        _currentContentSeconds = secForSync;
      });
      if (wordChanged && newIndex >= 0 && _player.playing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ensureCurrentWordVisible();
        });
      }
      if (newIndex <= 0 && wasAtEnd) {
        if (_playbackMode == PlaybackMode.loopOne) {
          _singleLoopCount++;
          if (_singleLoopCount >= _stillListeningThreshold &&
              !_waitingForStillListeningResponse) {
            _waitingForStillListeningResponse = true;
            _pause();
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              final keepGoing = await _showStillListeningDialog(
                count: _singleLoopCount,
                isLoopOne: true,
              );
              if (!mounted) return;
              _waitingForStillListeningResponse = false;
              if (keepGoing) {
                _singleLoopCount = 0;
                await _play();
              }
              if (mounted) setState(() {});
            });
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });
    await _rebuildPlayerStateSub();
    await _player.play();
    if (mounted) setState(() {});
  }

  Future<void> _rebuildPlayerStateSub() async {
    await _playerStateSub?.cancel();
    _playerStateSub = _player.playerStateStream.listen((state) async {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        if (_playbackMode == PlaybackMode.loopPlaylist &&
            widget.playlistIds != null &&
            widget.playlistIds!.length > 1) {
          final ids = widget.playlistIds!;
          final nextIndex = (widget.currentPlaylistIndex + 1) % ids.length;
          if (nextIndex == 0) {
            _playlistCycleCount++;
          }
          if (nextIndex == 0 &&
              _playlistCycleCount >= _stillListeningThreshold &&
              !_waitingForStillListeningResponse) {
            _waitingForStillListeningResponse = true;
            await _pause();
            if (!mounted) return;
            final keepGoing = await _showStillListeningDialog(
              count: _playlistCycleCount,
              isLoopOne: false,
            );
            if (!mounted) return;
            _waitingForStillListeningResponse = false;
            if (keepGoing) {
              _playlistCycleCount = 0;
              _advanceToNextInPlaylist();
            } else {
              Navigator.of(context).pop();
            }
          } else {
            _advanceToNextInPlaylist();
          }
        } else if (_playbackMode == PlaybackMode.playOnce) {
          await _player.stop();
          if (mounted) {
            setState(() => _currentWordIndex = -1);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
        }
      }
    });
  }

  void _advanceToNextInPlaylist() {
    final ids = widget.playlistIds;
    if (ids == null || ids.isEmpty) return;
    final nextIndex = (widget.currentPlaylistIndex + 1) % ids.length;
    final nextId = ids[nextIndex];
    Navigator.of(context).pop({'play_next': nextId, 'playlist_ids': ids});
  }

  /// Small lead (seconds) so highlight appears slightly before word is heard.
  /// Compensates for perception and display latency.
  static const double _syncLeadSeconds = 0.06;

  int _wordIndexAtPosition(double sec) {
    final words = _content?.words ?? [];
    if (words.isEmpty) return -1;

    // Apply sync lead so highlight appears slightly before word
    final secForLookup = sec + _syncLeadSeconds;

    // Find the word that contains this time
    for (var i = 0; i < words.length; i++) {
      if (secForLookup >= words[i].start && secForLookup < words[i].end) {
        return i;
      }
    }

    // If past last word, stay on last word and don't jump back
    if (secForLookup >= words.last.end) {
      return words.length - 1;
    }

    // If before first word
    if (secForLookup < words.first.start) return -1;

    // In a gap between words: switch to next word at midpoint of gap
    for (var i = 0; i < words.length - 1; i++) {
      final gapStart = words[i].end;
      final gapEnd = words[i + 1].start;
      if (secForLookup >= gapStart && secForLookup < gapEnd) {
        final gapMid = (gapStart + gapEnd) / 2;
        return secForLookup >= gapMid ? i + 1 : i;
      }
    }

    return -1;
  }

  Future<void> _play() async {
    await _player.play();
    _scheduleAutoHideControls();
    setState(() {});
  }

  Future<void> _pause() async {
    await _player.pause();
    _cancelControlsAutoHide();
    setState(() {
      if (!_controlsVisible) _controlsVisible = true;
    });
  }

  /// Returns true if user wants to keep playing, false to stop.
  Future<bool> _showStillListeningDialog({
    required bool isLoopOne,
    required int count,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Still learning?'),
        content: Text(
          isLoopOne
              ? 'You\'ve repeated this prayer $count times. '
                    'Are you still here? Tap "Keep going" to continue, or "Pause" if you\'re done for now.'
              : 'You\'ve gone through the playlist $count times. '
                    'Are you still here? Tap "Keep going" to continue, or "Pause" if you\'re done for now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Pause'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keep going'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _resetLoopCountOnUserActivity() {
    if (_waitingForStillListeningResponse) return;
    _singleLoopCount = 0;
    _playlistCycleCount = 0;
    _cancelAutoScrollTimer();
  }

  /// Auto-scroll when the current word chip (Hebrew + highlight + translation/
  /// transliteration) is not fully visible.
  /// - Only starts a timer if none is already running (avoids reset-every-1s bug).
  /// - Paused for [_autoScrollPauseAfterUserScroll] after any user scroll/zoom.
  void _ensureCurrentWordVisible() {
    final ctx = _currentWordKey.currentContext;
    if (ctx == null) return;
    final object = ctx.findRenderObject();
    if (object == null || !object.attached) return;
    final box = object as RenderBox;
    final viewport = RenderAbstractViewport.maybeOf(object);
    if (viewport == null) return;
    final viewportBox = viewport as RenderBox;
    final objectRect = box.localToGlobal(Offset.zero) & box.size;
    final viewportRectGlobal =
        viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    final fullyVisible =
        viewportRectGlobal.contains(objectRect.topLeft) &&
        viewportRectGlobal.contains(objectRect.bottomRight);

    if (fullyVisible) {
      _cancelAutoScrollTimer();
      return;
    }

    if (_autoScrollPausedUntil != null &&
        DateTime.now().isBefore(_autoScrollPausedUntil!)) {
      return;
    }

    // Only start a new timer if one isn't already counting down.
    _autoScrollTimer ??= Timer(_autoScrollAfterIdle, _performAutoScroll);
  }

  void _performAutoScroll() {
    _autoScrollTimer = null;
    if (!mounted) return;
    if (_autoScrollPausedUntil != null &&
        DateTime.now().isBefore(_autoScrollPausedUntil!)) {
      return;
    }
    final c = _currentWordKey.currentContext;
    if (c == null) return;
    // Remove listener during programmatic scroll so it doesn't trigger the
    // user-scroll pause, then re-add it on the next frame.
    _scrollController.removeListener(_onScrollPositionChanged);
    Scrollable.ensureVisible(c, duration: Duration.zero, alignment: 0.15);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollController.addListener(_onScrollPositionChanged);
    });
  }

  void _cancelAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _cancelControlsAutoHide() {
    _controlsAutoHideTimer?.cancel();
    _controlsAutoHideTimer = null;
  }

  void _scheduleAutoHideControls() {
    _cancelControlsAutoHide();
    if (!_player.playing) return;
    _controlsAutoHideTimer = Timer(_controlsAutoHideDelay, () {
      if (!mounted || !_player.playing) return;
      if (_controlsVisible) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _handleScreenTouch() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleAutoHideControls();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _resetLoopCountOnUserActivity();
    if (_activePointerId != null) return;
    _activePointerId = event.pointer;
    _pointerDownPosition = event.position;
    _pointerMoved = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointerId || _pointerDownPosition == null) {
      return;
    }
    if (_pointerMoved) return;
    if ((event.position - _pointerDownPosition!).distance >=
        _tapMovementThreshold) {
      _pointerMoved = true;
      _resetLoopCountOnUserActivity();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointerId) return;
    final isTap = !_pointerMoved;
    _resetPointerTracking();
    if (isTap) {
      _scheduleTapReveal();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointerId) return;
    _resetPointerTracking();
  }

  void _resetPointerTracking() {
    _activePointerId = null;
    _pointerDownPosition = null;
    _pointerMoved = false;
  }

  void _scheduleTapReveal() {
    _tapRevealTimer?.cancel();
    _tapRevealTimer = Timer(_tapRevealDebounce, () {
      if (!mounted) return;
      _handleScreenTouch();
    });
  }

  void _showTapTips(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How to use',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _buildTipRow(
                ctx,
                Icons.touch_app_rounded,
                'Tap a word',
                'Play full audio from that word',
              ),
              const SizedBox(height: 12),
              _buildTipRow(
                ctx,
                Icons.play_arrow_rounded,
                'Play button',
                'Play full audio from current position',
              ),
              const SizedBox(height: 12),
              _buildTipRow(
                ctx,
                Icons.pinch_rounded,
                'Pinch to zoom',
                'Use two fingers to zoom the prayer text in or out',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipRow(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _setPlaybackSpeed(PlaybackSpeed speed) async {
    setState(() => _playbackSpeed = speed);
    await _player.setSpeed(speed.rate);
    await PlaybackSpeedPreferenceService.setSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    final controlsHiddenForFocus = _player.playing && !_controlsVisible;
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.primary,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
              height: 1,
            ),
          ),
          automaticallyImplyLeading: !controlsHiddenForFocus,
          flexibleSpace: controlsHiddenForFocus
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _controlsVisible = true);
                    _scheduleAutoHideControls();
                  },
                )
              : null,
          leading: controlsHiddenForFocus
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 26),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
          title: controlsHiddenForFocus
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _content?.title ?? widget.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              _content?.titleHebrew ?? widget.titleHebrew,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    fontSize: 15,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          actions: controlsHiddenForFocus
              ? const []
              : [
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded, size: 26),
                    tooltip: 'Tips',
                    onPressed: () => _showTapTips(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 26),
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Container(
                color: Theme.of(context).colorScheme.surface,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: _buildBody(),
                ),
              ),
              if (controlsHiddenForFocus && _content != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 80,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      setState(() => _controlsVisible = true);
                      _scheduleAutoHideControls();
                    },
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _content != null && !controlsHiddenForFocus
            ? _buildPlayBar()
            : null,
      ),
    );
  }

  Widget _buildPlayBar() {
    final content = _content!;
    final hasAudio = content.audio != null && _audioError == null;
    final playing = _player.playing;
    final wordCount = content.words.length;
    final progress = wordCount > 0 && _currentWordIndex >= 0
        ? (_currentWordIndex + 1) / wordCount
        : 0.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: 'Playback mode: ${_playbackMode.label}',
                  child: Semantics(
                    label: 'Playback mode: ${_playbackMode.label}',
                    button: true,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: Icon(
                        _playbackMode == PlaybackMode.loopOne
                            ? Icons.repeat_one_rounded
                            : _playbackMode == PlaybackMode.loopPlaylist
                            ? Icons.repeat_rounded
                            : Icons.replay_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 26,
                      ),
                      onPressed: () async {
                        final chosen = await showModalBottomSheet<PlaybackMode>(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Playback mode',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                ...PlaybackMode.values.map(
                                  (m) => ListTile(
                                    title: Text(m.label),
                                    subtitle: Text(
                                      m == PlaybackMode.playOnce
                                          ? 'Stop after one play'
                                          : m == PlaybackMode.loopOne
                                          ? 'Repeat this prayer'
                                          : 'Continue to next in playlist',
                                      style: Theme.of(ctx).textTheme.bodySmall,
                                    ),
                                    trailing: _playbackMode == m
                                        ? Icon(
                                            Icons.check,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          )
                                        : null,
                                    onTap: () => Navigator.pop(ctx, m),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        if (chosen != null && mounted) {
                          setState(() => _playbackMode = chosen);
                          await LoopPreferenceService.setPlaybackMode(chosen);
                          await _player.setLoopMode(
                            chosen == PlaybackMode.loopOne
                                ? LoopMode.one
                                : LoopMode.off,
                          );
                          await _rebuildPlayerStateSub();
                        }
                      },
                    ),
                  ),
                ),
                if (content.words.isNotEmpty && hasAudio) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<WordHintMode>(
                    tooltip: 'Word hints',
                    padding: EdgeInsets.zero,
                    onSelected: (mode) {
                      setState(() {
                        _wordHintMode = mode;
                        _tappedWordIndex = null;
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: WordHintMode.hebrewOnly,
                        child: Row(
                          children: [
                            _WordHintIcon(
                              mode: WordHintMode.hebrewOnly,
                              size: 40,
                            ),
                            SizedBox(width: 12),
                            Text('Hebrew Only'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: WordHintMode.translation,
                        child: Row(
                          children: [
                            _WordHintIcon(
                              mode: WordHintMode.translation,
                              size: 40,
                            ),
                            SizedBox(width: 12),
                            Text('Translation'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: WordHintMode.transliteration,
                        child: Row(
                          children: [
                            _WordHintIcon(
                              mode: WordHintMode.transliteration,
                              size: 40,
                            ),
                            SizedBox(width: 12),
                            Text('Transliteration'),
                          ],
                        ),
                      ),
                    ],
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: _WordHintIcon(mode: _wordHintMode, size: 28),
                      ),
                    ),
                  ),
                ],
                if (hasAudio) ...[
                  const SizedBox(width: 8),
                  Semantics(
                    label: playing ? 'Pause' : 'Play',
                    button: true,
                    child: GestureDetector(
                      onTapDown: (_) =>
                          setState(() => _playButtonPressed = true),
                      onTapUp: (_) =>
                          setState(() => _playButtonPressed = false),
                      onTapCancel: () =>
                          setState(() => _playButtonPressed = false),
                      child: AnimatedScale(
                        scale: _playButtonPressed ? 0.96 : 1.0,
                        duration: const Duration(milliseconds: 100),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulseScale = playing
                                ? 1.0 + (_pulseController.value * 0.02)
                                : 1.0;
                            return Transform.scale(
                              scale: pulseScale,
                              child: child,
                            );
                          },
                          child: Material(
                            elevation: 3,
                            color: Theme.of(context).colorScheme.primary,
                            shadowColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              onTap: () async {
                                if (playing) {
                                  await _pause();
                                } else {
                                  await _play();
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      playing
                                          ? Icons.graphic_eq_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      playing ? 'Pause' : 'Play',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (hasAudio) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<PlaybackSpeed>(
                    tooltip: 'Playback speed',
                    padding: EdgeInsets.zero,
                    initialValue: _playbackSpeed,
                    onSelected: _setPlaybackSpeed,
                    itemBuilder: (context) => PlaybackSpeed.values.map((speed) {
                      final selected = speed == _playbackSpeed;
                      return PopupMenuItem<PlaybackSpeed>(
                        value: speed,
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 20,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              speed.displayName,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.speed_rounded,
                          size: 26,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
                if (content.words.isNotEmpty && _currentWordIndex >= 0) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Scroll to current word',
                    child: IconButton(
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(44, 44),
                      ),
                      icon: Icon(
                        Icons.center_focus_strong_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        final ctx = _currentWordKey.currentContext;
                        if (ctx != null) {
                          _scrollController.removeListener(
                            _onScrollPositionChanged,
                          );
                          Scrollable.ensureVisible(
                            ctx,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: 0.15,
                          );
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              _scrollController.addListener(
                                _onScrollPositionChanged,
                              );
                            }
                          });
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasRecordingMetadata(PrayerContent content) {
    return (content.performerName != null &&
            content.performerName!.isNotEmpty) ||
        (content.audioLicense != null && content.audioLicense!.isNotEmpty) ||
        (content.textLicense != null && content.textLicense!.isNotEmpty) ||
        (content.attribution != null && content.attribution!.isNotEmpty);
  }

  String _recordingMetadataLine(PrayerContent content) {
    final parts = <String>[];
    if (content.performerName != null && content.performerName!.isNotEmpty) {
      parts.add(content.performerName!);
    }
    if (content.audioLicense != null && content.audioLicense!.isNotEmpty) {
      parts.add('Audio: ${content.audioLicense!}');
    }
    if (content.textLicense != null && content.textLicense!.isNotEmpty) {
      parts.add('Text: ${content.textLicense!}');
    }
    if (content.attribution != null && content.attribution!.isNotEmpty) {
      parts.add(content.attribution!);
    }
    return parts.join(' · ');
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _content == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'This prayer is not available.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final content = _content!;
    const padding = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        final viewportWidth = constraints.maxWidth;
        final hasMeta = _hasRecordingMetadata(content);
        final topSectionHeight =
            60.0 +
            (_audioError != null ? 80.0 : 0) +
            (content.description != null && content.description!.isNotEmpty
                ? 40.0
                : 0) +
            (hasMeta ? 32.0 : 0);
        final minTextHeight = (viewportHeight - padding * 2 - topSectionHeight)
            .clamp(200.0, double.infinity);
        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_audioError != null)
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _audioError!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_audioError != null) const SizedBox(height: 16),
              if (content.description != null &&
                  content.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  content.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              if (hasMeta) ...[
                const SizedBox(height: 8),
                Text(
                  _recordingMetadataLine(content),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) {
                  _scaleStart = _prayerTextScale;
                  if (_player.playing) {
                    _autoScrollPausedUntil = DateTime.now().add(
                      _autoScrollPauseAfterUserScroll,
                    );
                    _cancelAutoScrollTimer();
                  }
                },
                onScaleUpdate: (d) {
                  if (_player.playing) {
                    _autoScrollPausedUntil = DateTime.now().add(
                      _autoScrollPauseAfterUserScroll,
                    );
                  }
                  setState(() {
                    _prayerTextScale = (_scaleStart * d.scale).clamp(
                      _minPrayerScale,
                      _maxPrayerScale,
                    );
                  });
                },
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: minTextHeight,
                      maxWidth: viewportWidth - padding * 2,
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: ValueListenableBuilder<TextAlignmentOption>(
                        valueListenable:
                            TextAlignmentPreferenceService.optionNotifier,
                        builder: (context, alignment, _) {
                          return _buildWordByWord(
                            content,
                            alignment,
                            _prayerTextScale,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWordByWord(
    PrayerContent content,
    TextAlignmentOption alignment,
    double scale,
  ) {
    final textAlign = alignment.textAlign;
    final wrapAlign = alignment == TextAlignmentOption.rtl
        ? WrapAlignment.start
        : WrapAlignment.center;
    final words = content.words;
    if (words.isEmpty) {
      final lines = content.lines;
      if (lines != null && lines.isNotEmpty) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lines.length; i++) ...[
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == 0 ? 32 : 20,
                  top: i == 0 ? 0 : 4,
                ),
                child: Text(
                  lines[i],
                  textDirection: TextDirection.rtl,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.8,
                    fontSize: (i == 0 ? 30.0 : 26.0) * scale,
                    letterSpacing: 0.02,
                    fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
                    color: i == 0
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                  textAlign: textAlign,
                ),
              ),
            ],
          ],
        );
      }
      return Text(
        content.text,
        textDirection: TextDirection.rtl,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.8,
          fontSize: 24 * scale,
          letterSpacing: 0.02,
        ),
        textAlign: textAlign,
      );
    }
    return Wrap(
      textDirection: TextDirection.rtl,
      alignment: wrapAlign,
      runAlignment: wrapAlign,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < words.length; i++)
          _buildWordChip(
            words[i],
            i,
            scale,
            key: i == _currentWordIndex ? _currentWordKey : null,
          ),
      ],
    );
  }

  Widget _buildWordChip(WordSegment w, int i, double scale, {Key? key}) {
    final isCurrent = i == _currentWordIndex;
    final isTapped = i == _tappedWordIndex;
    final progress = _wordProgressForCurrentWord(w, i);
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      child: GestureDetector(
        onTap: () async {
          // Single tap: play full audio from this word (also used to show controls)
          if (_content != null && _audioError == null && w.start >= 0) {
            final offset = _content!.audioOffsetSeconds;
            final seekPos = Duration(
              milliseconds: ((w.start + offset) * 1000).round(),
            );
            await _player.seek(seekPos);
            if (!mounted) return;
            if (!_player.playing) {
              await _player.play();
            }
            if (mounted && _content != null) {
              setState(() {
                _currentWordIndex = i;
                _currentContentSeconds = w.start;
              });
            }
          } else {
            setState(() {
              _tappedWordIndex = _tappedWordIndex == i ? null : i;
            });
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: isTapped
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : null,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      w.word,
                      textDirection: TextDirection.rtl,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 24 * scale,
                        height: 1.8,
                        letterSpacing: 0.02,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: constraints.maxWidth * progress,
                                height: 3,
                                child: Container(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_wordHintMode == WordHintMode.translation)
              Builder(
                builder: (context) {
                  final hint =
                      (w.translation != null && w.translation!.isNotEmpty)
                          ? w.translation!
                          : (w.transliteration != null &&
                                  w.transliteration!.isNotEmpty)
                          ? w.transliteration!
                          : TransliterationService.transliterate(w.word);
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        hint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12 * scale,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  );
                },
              )
            else if (_wordHintMode == WordHintMode.transliteration)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    w.transliteration != null && w.transliteration!.isNotEmpty
                        ? w.transliteration!
                        : TransliterationService.transliterate(w.word),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12 * scale,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              )
            else if (isTapped &&
                (w.translation != null && w.translation!.isNotEmpty ||
                    (w.transliteration != null &&
                        w.transliteration!.isNotEmpty) ||
                    TransliterationService.transliterate(w.word).isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  w.translation ??
                      w.transliteration ??
                      TransliterationService.transliterate(w.word),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12 * scale,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _wordProgressForCurrentWord(WordSegment w, int index) {
    if (index != _currentWordIndex) return 0;
    final duration = w.end - w.start;
    if (duration <= 0) return 1;
    final sec = _currentContentSeconds + _syncLeadSeconds;
    return ((sec - w.start) / duration).clamp(0.0, 1.0);
  }
}
