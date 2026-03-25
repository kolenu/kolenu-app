import 'package:flutter/material.dart';

import '../models/prayer.dart';
import '../services/default_playlist_service.dart';
import '../services/prayer_catalog_loader.dart';
import '../services/progress_service.dart';
import '../widgets/kolenu_logo.dart';
import 'prayer_catalog_welcome.dart';
import 'prayer_list_screen.dart';
import 'settings_screen.dart';

/// Home hub: Continue Learning, Start Learning pillars, Community Voices, Settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PrayerListItem> _prayers = [];
  bool _loading = true;
  String? _error;

  static const List<String> _startLearningBuckets = <String>[
    'daily',
    'synagogue',
    '__shabbat_holidays',
    'home_life',
    '__jewish_songs',
  ];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ({PrayerCatalogSnapshot snapshot, bool cacheWasCleared}) loaded =
          await PrayerCatalogLoader.loadCatalog();
      if (loaded.cacheWasCleared && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security key changed. Connecting to the cloud...'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _prayers = loaded.snapshot.prayers;
        _loading = false;
      });
      if (mounted) await runPrayerCatalogWelcomeFlow(context);
    } catch (e, st) {
      debugPrint('HomeScreen load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString();
        _loading = false;
      });
    }
  }

  String _titleForId(String id) {
    final PrayerListItem? p =
        _prayers.where((PrayerListItem x) => x.id == id).firstOrNull;
    return p?.title ?? id.replaceAll('_', ' ');
  }

  PrayerListItem? _pickSuggestion({
    required String? lastPracticedId,
    required Set<String> completed,
  }) {
    for (final PrayerListItem p in _prayers) {
      if (p.id == lastPracticedId) continue;
      if (!completed.contains(p.id)) return p;
    }
    for (final PrayerListItem p in _prayers) {
      if (p.id != lastPracticedId) return p;
    }
    return null;
  }

  Future<void> _playDefaultPlaylist() async {
    final List<String> ids = await DefaultPlaylistService.getPlaylistForPlayback();
    if (ids.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Playlist is empty. Add prayers in Edit default playlist.',
          ),
        ),
      );
      return;
    }
    final String firstId = ids.first;
    final PrayerListItem? item =
        _prayers.where((PrayerListItem p) => p.id == firstId).firstOrNull;
    if (item == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prayer not found in list.')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PrayerListScreen(
          autoOpenPrayerId: item.id,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final Object? result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SettingsScreen(),
      ),
    );
    if (result == 'play_playlist' && mounted) {
      await _playDefaultPlaylist();
    }
  }

  void _openCategory(String bucket) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            PrayerListScreen(categoryBucket: bucket),
      ),
    );
  }

  void _openBrowseAll() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const PrayerListScreen(),
      ),
    );
  }

  void _continuePrayer(String prayerId) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PrayerListScreen(
          autoOpenPrayerId: prayerId,
          popRouteAfterReader: true,
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          letterSpacing: 0.08,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load prayers',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadCatalog,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadCatalog,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    const Center(child: KolenuLogo(size: 88)),
                    const SizedBox(height: 8),
                    _sectionHeader(context, 'Continue Learning'),
                    FutureBuilder<
                        ({
                          String? lastId,
                          String date,
                          Set<String> completed,
                        })>(
                      future: () async {
                        final ({String? prayerId, String date}) last =
                            await ProgressService.getLastPracticed();
                        final Set<String> completed =
                            await ProgressService.getCompletedPrayerIds();
                        return (
                          lastId: last.prayerId,
                          date: last.date,
                          completed: completed,
                        );
                      }(),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<
                            ({
                              String? lastId,
                              String date,
                              Set<String> completed,
                            })> snap,
                      ) {
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        final ({
                          String? lastId,
                          String date,
                          Set<String> completed,
                        }) data = snap.data!;
                        final List<Widget> rows = <Widget>[];
                        if (data.lastId != null &&
                            _prayers.any((PrayerListItem p) => p.id == data.lastId)) {
                          final String title = _titleForId(data.lastId!);
                          final String subtitle;
                          if (data.date.isEmpty) {
                            subtitle = 'Tap to continue';
                          } else {
                            final String when =
                                ProgressService.formatRelativeDate(data.date);
                            subtitle = data.completed.contains(data.lastId)
                                ? 'Practiced · $when'
                                : 'Continue · $when';
                          }
                          rows.add(
                            _HomeListCard(
                              title: title,
                              subtitle: subtitle,
                              icon: Icons.history_rounded,
                              onTap: () => _continuePrayer(data.lastId!),
                            ),
                          );
                        }
                        final PrayerListItem? suggestion = _pickSuggestion(
                          lastPracticedId: data.lastId,
                          completed: data.completed,
                        );
                        if (suggestion != null &&
                            (data.lastId == null ||
                                suggestion.id != data.lastId)) {
                          rows.add(
                            _HomeListCard(
                              title: suggestion.title ??
                                  suggestion.id.replaceAll('_', ' '),
                              subtitle: data.completed.contains(suggestion.id)
                                  ? 'Practiced before — open again anytime'
                                  : 'Not started',
                              icon: Icons.menu_book_outlined,
                              onTap: () => _continuePrayer(suggestion.id),
                            ),
                          );
                        }
                        if (rows.isEmpty) {
                          return Text(
                            'Open a prayer below to start learning.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        }
                        return Column(children: rows);
                      },
                    ),
                    _sectionHeader(context, 'Start Learning'),
                    ..._startLearningBuckets.map(
                      (String bucket) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _HomeListCard(
                          title: prayerCategoryDisplayName(bucket),
                          icon: Icons.auto_stories_outlined,
                          onTap: () => _openCategory(bucket),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openBrowseAll,
                      child: const Text('See all prayers'),
                    ),
                    _sectionHeader(context, 'Community Voices'),
                    const _HomeListCard(
                      title: 'Listen to student recordings',
                      subtitle: 'Coming soon',
                      icon: Icons.record_voice_over_outlined,
                      enabled: false,
                    ),
                    _sectionHeader(context, 'Settings'),
                    _HomeListCard(
                      title: 'Display, audio speed, voice style',
                      subtitle: 'Open settings',
                      icon: Icons.settings_outlined,
                      onTap: _openSettings,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HomeListCard extends StatelessWidget {
  const _HomeListCard({
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? subtitleLine = subtitle;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 26,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (subtitleLine != null && subtitleLine.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitleLine,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
