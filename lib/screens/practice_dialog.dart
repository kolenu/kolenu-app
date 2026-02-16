import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Dialog for practicing pronunciation: record your voice, then play back.
/// Phase 3 shell; no comparison with reference yet.
class PracticeDialog extends StatefulWidget {
  const PracticeDialog({
    super.key,
    this.sentenceText,
    this.difficulty,
    this.sentenceIndex,
    this.totalSentences,
    this.practicedCount,
  });

  final String? sentenceText;
  /// Optional difficulty level (L1–L4) for difficulty-based hints.
  final String? difficulty;
  final int? sentenceIndex;
  final int? totalSentences;
  final int? practicedCount;

  @override
  State<PracticeDialog> createState() => _PracticeDialogState();
}

class _PracticeDialogState extends State<PracticeDialog> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _playbackPlayer = AudioPlayer();
  bool _recording = false;
  String? _recordedPath;
  bool _playing = false;
  String? _permissionError;
  StreamSubscription<PlayerState>? _playSub;

  @override
  void dispose() {
    _playSub?.cancel();
    _recorder.dispose();
    _playbackPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    if (await _recorder.hasPermission()) return;
    if (mounted) {
      setState(() => _permissionError = 'Microphone permission is needed to practice.');
    }
  }

  Future<void> _startRecording() async {
    await _checkPermission();
    if (_permissionError != null) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/kolenu_practice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(const RecordConfig(), path: path);
      if (mounted) {
        setState(() {
          _recording = true;
          _recordedPath = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _permissionError = e.toString());
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (mounted) {
        setState(() {
          _recording = false;
          _recordedPath = path;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _playRecording() async {
    if (_recordedPath == null || !File(_recordedPath!).existsSync()) return;
    if (!mounted) return;
    setState(() => _playing = true);
    try {
      await _playbackPlayer.setFilePath(_recordedPath!);
      _playSub?.cancel();
      _playSub = _playbackPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playing = false);
        }
      });
      await _playbackPlayer.play();
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _stopPlayback() async {
    await _playbackPlayer.stop();
    if (mounted) setState(() => _playing = false);
  }

  /// Hint text based on difficulty level (L1–L4).
  static String _difficultyHint(String? difficulty) {
    switch (difficulty) {
      case 'L1':
        return 'Take your time — this is an easy one to learn.';
      case 'L2':
        return 'You\'re building confidence. Focus on clear pronunciation.';
      case 'L3':
        return 'Follow the traditional phrasing and rhythm.';
      case 'L4':
        return 'Advanced — pay attention to full liturgical style.';
      default:
        return 'Use "Repeat" in the reader to hear the sentence again, then say it aloud and record.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difficultyHint = widget.difficulty != null
        ? _difficultyHint(widget.difficulty)
        : _difficultyHint(null);
    return AlertDialog(
      title: const Text('Practice'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.practicedCount != null &&
              widget.totalSentences != null &&
              widget.totalSentences! > 0) ...[
            Text(
              '${widget.practicedCount} of ${widget.totalSentences} sentences practiced in this session',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (widget.sentenceText != null) ...[
            Text(
              difficultyHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.sentenceText!,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          if (_permissionError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _permissionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_recording && _recordedPath == null)
                FilledButton.icon(
                  icon: const Icon(Icons.mic),
                  label: const Text('Record'),
                  onPressed: _permissionError == null ? _startRecording : null,
                ),
              if (_recording)
                FilledButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  onPressed: _stopRecording,
                ),
              if (_recordedPath != null && !_recording) ...[
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                  label: Text(_playing ? 'Stop' : 'Play back'),
                  onPressed: _playing ? _stopPlayback : _playRecording,
                ),
              ],
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
