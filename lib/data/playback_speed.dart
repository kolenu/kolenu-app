/// Playback speed for prayer audio.
/// Order represents pedagogical progression: Practice → Synagogue → Fluent
enum PlaybackSpeed {
  slow, // Practice speed - for first-time learners
  normal, // Synagogue speed - real-world pace
  fast, // Fluent speed - confident mastery
}

extension PlaybackSpeedExtension on PlaybackSpeed {
  /// Pedagogically correct display name for UI.
  String get displayName {
    switch (this) {
      case PlaybackSpeed.slow:
        return 'Practice speed';
      case PlaybackSpeed.normal:
        return 'Synagogue speed';
      case PlaybackSpeed.fast:
        return 'Fluent speed';
    }
  }

  /// Playback rate multiplier (0.7× for slow, 1.0× for normal, 1.25× for fast).
  double get rate {
    switch (this) {
      case PlaybackSpeed.slow:
        return 0.7;
      case PlaybackSpeed.normal:
        return 1.0;
      case PlaybackSpeed.fast:
        return 1.25;
    }
  }

  /// Short description for tooltips/help text.
  String get description {
    switch (this) {
      case PlaybackSpeed.slow:
        return 'Clear and slow for learning';
      case PlaybackSpeed.normal:
        return 'Natural synagogue pace';
      case PlaybackSpeed.fast:
        return 'Fast for confident readers';
    }
  }
}
