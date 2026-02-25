/// Playback mode for audio: loop current, loop playlist, or play once.
enum PlaybackMode {
  /// Loop the current audio from the beginning.
  loopOne,

  /// When playing from playlist, continue to next and loop back when done.
  loopPlaylist,

  /// Stop after playing the whole audio once.
  playOnce,
}

extension PlaybackModeExtension on PlaybackMode {
  String get label {
    switch (this) {
      case PlaybackMode.loopOne:
        return 'Loop current';
      case PlaybackMode.loopPlaylist:
        return 'Loop playlist';
      case PlaybackMode.playOnce:
        return 'Play once';
    }
  }
}
