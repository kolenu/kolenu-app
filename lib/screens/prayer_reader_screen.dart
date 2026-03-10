import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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
  int _currentPage = 0;

  /// Word hint mode: Hebrew only, or show translation/transliteration below each word.
  WordHintMode _wordHintMode = WordHintMode.hebrewOnly;
  int? _tappedWordIndex;
  PlaybackSpeed _playbackSpeed = PlaybackSpeed.normal;
  PlaybackMode _playbackMode = PlaybackMode.playOnce;
  bool _playButtonPressed = false;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<bool>? _playingSub;
  late AnimationController _pulseController;
  bool _controlsVisible = true;
  Timer? _controlsAutoHideTimer;
  Timer? _tapRevealTimer;
  int? _activePointerId;
  Offset? _pointerDownPosition;
  bool _pointerMoved = false;

  static const Duration _controlsAutoHideDelay = Duration(seconds: 3);
  static const Duration _tapRevealDebounce = Duration(milliseconds: 120);
  static const double _tapMovementThreshold = 12.0;

  static const String _prayersAssetPath = 'assets/audio';

  /// Base path for this prayer's assets (e.g. "shema" when file is "shema/content.json", else "").
  String get _prayerAssetBase {
    final f = widget.prayerFile;
    final i = f.lastIndexOf('/');
    return i >= 0 ? f.substring(0, i) : '';
  }

  /// Number of sentences shown on each screen page (more text per page).
  static const int _sentencesPerPage = 2;

  int _pageCount(PrayerContent c) {
    if (c.sentences.isEmpty) return c.words.isEmpty ? 1 : 1;
    return (c.sentences.length + _sentencesPerPage - 1) ~/ _sentencesPerPage;
  }

  int _startWordIndexForPage(PrayerContent c, int page) {
    if (c.words.isEmpty) return 0;
    if (c.sentences.isEmpty) return 0;
    if (page <= 0) return 0;
    final firstSentence = (page * _sentencesPerPage).clamp(
      0,
      c.sentences.length - 1,
    );
    if (firstSentence == 0) return 0;
    final endPrev = c.sentenceEndWordIndex(firstSentence - 1);
    return endPrev < 0 ? 0 : endPrev + 1;
  }

  int _endWordIndexForPage(PrayerContent c, int page) {
    if (c.words.isEmpty) return 0;
    if (c.sentences.isEmpty) return c.words.length - 1;
    final lastSentence = ((page + 1) * _sentencesPerPage - 1).clamp(
      0,
      c.sentences.length - 1,
    );
    final end = c.sentenceEndWordIndex(lastSentence);
    return end < 0 ? c.words.length - 1 : end;
  }

  int _sentenceIndexForWord(PrayerContent c, int wordIndex) {
    if (c.sentences.isEmpty || wordIndex < 0) return 0;
    for (var s = 0; s < c.sentences.length; s++) {
      final endIdx = c.sentenceEndWordIndex(s);
      if (endIdx >= 0 && wordIndex <= endIdx) return s;
    }
    return (c.sentences.length - 1).clamp(0, c.sentences.length);
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
        } else {
          _pulseController.stop();
          _pulseController.reset();
          _cancelControlsAutoHide();
          if (!_controlsVisible) {
            setState(() => _controlsVisible = true);
          }
        }
      }
    });
    _loadPlaybackSpeed();
    _loadLoopPreference();
    _loadContent();
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
    _cancelControlsAutoHide();
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
        if (audioFile == null) _audioError = 'Could not find .mp3';
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
      // In play-once mode, stay on last word when past end. In loop-one, allow
      // pointer to jump back when audio restarts.
      if (_playbackMode != PlaybackMode.loopOne &&
          _currentWordIndex == (content?.words.length ?? 0) - 1 &&
          newIndex < _currentWordIndex) {
        return;
      }
      setState(() {
        _currentWordIndex = newIndex;
      });
      if (content != null &&
          content.sentences.isNotEmpty &&
          _currentWordIndex >= 0) {
        final sentence = _sentenceIndexForWord(content, _currentWordIndex);
        final pageForSentence = sentence ~/ _sentencesPerPage;
        if (pageForSentence != _currentPage) {
          setState(() {
            _currentPage = pageForSentence;
          });
        }
      }
    });
    await _playerStateSub?.cancel();
    _playerStateSub = _player.playerStateStream.listen((state) async {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        if (_playbackMode == PlaybackMode.loopPlaylist &&
            widget.playlistIds != null &&
            widget.playlistIds!.length > 1) {
          _advanceToNextInPlaylist();
        } else if (_playbackMode == PlaybackMode.playOnce) {
          await _player.stop();
          if (mounted) setState(() {});
        }
      }
    });
    await _player.play();
    if (mounted) setState(() {});
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
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    setState(() {});
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
    if (_player.playing) {
      _scheduleAutoHideControls();
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
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

  Future<void> _setPlaybackSpeed(PlaybackSpeed speed) async {
    setState(() => _playbackSpeed = speed);
    await _player.setSpeed(speed.rate);
    await PlaybackSpeedPreferenceService.setSpeed(speed);
  }

  Future<void> _seekToContentTime(double contentSec) async {
    final content = _content;
    if (content == null) return;
    final duration = _contentDurationSeconds(content);
    if (duration <= 0) return;
    final offset = content.audioOffsetSeconds;
    final pos = _player.position.inMilliseconds / 1000.0;
    final contentPos = (pos - offset).clamp(0.0, double.infinity);
    final cycle = contentPos >= duration ? (contentPos / duration).floor() : 0;
    final seekSec = offset + cycle * duration + contentSec;
    await _player.seek(Duration(milliseconds: (seekSec * 1000).round()));
  }

  Future<void> _goToPage(int page) async {
    final content = _content;
    if (content == null) return;
    final pageCount = _pageCount(content);
    final newPage = page.clamp(0, pageCount - 1);
    if (!mounted) return;
    setState(() => _currentPage = newPage);
    if (content.audio != null &&
        _audioError == null &&
        content.words.isNotEmpty) {
      final startWordIdx = _startWordIndexForPage(content, newPage);
      if (startWordIdx < content.words.length) {
        final startSec = content.words[startWordIdx].start;
        await _seekToContentTime(startSec);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controlsHiddenForFocus = _player.playing && !_controlsVisible;
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            height: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _content?.title ?? widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      _content?.titleHebrew ?? widget.titleHebrew,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.localSongFolderId != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.offline_pin_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
        actions: controlsHiddenForFocus
            ? const []
            : [
                if (_content != null &&
                    _content!.words.isNotEmpty &&
                    _content!.audio != null &&
                    _audioError == null)
                  PopupMenuButton<WordHintMode>(
                    tooltip: 'Word hints',
                    onSelected: (mode) {
                      setState(() {
                        _wordHintMode = mode;
                        if (mode == WordHintMode.hebrewOnly) {
                          _tappedWordIndex = null;
                        }
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
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _WordHintIcon(mode: _wordHintMode, size: 28),
                    ),
                  ),
                if (_content != null &&
                    _content!.audio != null &&
                    _audioError == null)
                  PopupMenuButton<PlaybackSpeed>(
                    tooltip: 'Playback speed',
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
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.speed_rounded,
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
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
      body: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: _buildBody(),
          ),
        ),
      ),
      bottomNavigationBar: _content != null && !controlsHiddenForFocus
          ? _buildPlayBar()
          : null,
    );
  }

  Widget _buildPlayBar() {
    final content = _content!;
    final hasAudio = content.audio != null && _audioError == null;
    final playing = _player.playing;
    final pageCount = _pageCount(content);
    final canPrev = _currentPage > 0;
    final canNext = _currentPage < pageCount - 1;
    final progress = pageCount > 0 ? (_currentPage + 1) / pageCount : 1.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 4,
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  label: canPrev ? 'Previous page' : 'Previous page (disabled)',
                  button: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          onPressed: canPrev
                              ? () => _goToPage(_currentPage - 1)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prev',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (hasAudio)
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
                            borderRadius: BorderRadius.circular(28),
                            child: InkWell(
                              onTap: () async {
                                if (playing) {
                                  await _pause();
                                } else {
                                  await _play();
                                }
                              },
                              borderRadius: BorderRadius.circular(28),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
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
                                    const SizedBox(width: 10),
                                    Text(
                                      playing ? 'Pause' : 'Play',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        fontSize: 18,
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
                if (hasAudio) const SizedBox(width: 12),
                if (hasAudio)
                  Semantics(
                    label: 'Playback mode: ${_playbackMode.label}',
                    button: true,
                    child: IconButton(
                      icon: Icon(
                        _playbackMode == PlaybackMode.loopOne
                            ? Icons.repeat_one_rounded
                            : _playbackMode == PlaybackMode.loopPlaylist
                            ? Icons.repeat_rounded
                            : Icons.replay_rounded,
                        color: Theme.of(context).colorScheme.primary,
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
                          await _playerStateSub?.cancel();
                          _playerStateSub = _player.playerStateStream.listen((
                            state,
                          ) async {
                            if (!mounted) return;
                            if (state.processingState ==
                                ProcessingState.completed) {
                              if (_playbackMode == PlaybackMode.loopPlaylist &&
                                  widget.playlistIds != null &&
                                  widget.playlistIds!.length > 1) {
                                _advanceToNextInPlaylist();
                              } else if (_playbackMode ==
                                  PlaybackMode.playOnce) {
                                await _player.stop();
                                if (mounted) setState(() {});
                              }
                            }
                          });
                        }
                      },
                    ),
                  ),
                if (hasAudio) const SizedBox(width: 12),
                Semantics(
                  label: canNext ? 'Next page' : 'Next page (disabled)',
                  button: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          onPressed: canNext
                              ? () => _goToPage(_currentPage + 1)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
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
              if (_hasRecordingMetadata(content)) ...[
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
              ConstrainedBox(
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
                      return FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: viewportWidth - padding * 2,
                          ),
                          child: _buildWordByWord(content, alignment),
                        ),
                      );
                    },
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
                    fontSize: i == 0 ? 30 : 26,
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
          fontSize: 24,
          letterSpacing: 0.02,
        ),
        textAlign: textAlign,
      );
    }
    final start = _startWordIndexForPage(content, _currentPage);
    final end = _endWordIndexForPage(content, _currentPage);

    return Wrap(
      textDirection: TextDirection.rtl,
      alignment: wrapAlign,
      runAlignment: wrapAlign,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = start; i <= end && i < words.length; i++)
          _buildWordChip(words[i], i),
      ],
    );
  }

  Widget _buildWordChip(WordSegment w, int i) {
    final isCurrent = i == _currentWordIndex;
    final isTapped = i == _tappedWordIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: GestureDetector(
        onTap: () async {
          // Seek to word start and play if audio available
          if (_content != null && w.start >= 0) {
            final offset = _content!.audioOffsetSeconds;
            final seekPos = Duration(
              milliseconds: ((w.start + offset) * 1000).round(),
            );
            await _player.seek(seekPos);
            if (!_player.playing) {
              await _player.play();
            }
            // Update pointer immediately so it shows without waiting for position stream
            if (mounted && _content != null) {
              setState(() {
                _currentWordIndex = i;
                if (_content!.sentences.isNotEmpty) {
                  final sentence = _sentenceIndexForWord(_content!, i);
                  _currentPage = sentence ~/ _sentencesPerPage;
                }
              });
            }
          } else {
            // No audio, just toggle translation display
            setState(() {
              _tappedWordIndex = _tappedWordIndex == i ? null : i;
            });
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isCurrent ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primaryContainer
                      : (isTapped
                            ? Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest
                            : null),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  w.word,
                  textDirection: TextDirection.rtl,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 24,
                    height: 1.8,
                    letterSpacing: 0.02,
                    fontWeight: isCurrent ? FontWeight.w600 : null,
                    color: isCurrent
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            if (_wordHintMode == WordHintMode.translation &&
                w.translation != null &&
                w.translation!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  w.translation!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              )
            else if (_wordHintMode == WordHintMode.transliteration)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  w.transliteration != null && w.transliteration!.isNotEmpty
                      ? w.transliteration!
                      : TransliterationService.transliterate(w.word),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textDirection: TextDirection.ltr,
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
}
