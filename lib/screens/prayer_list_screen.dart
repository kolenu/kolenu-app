import 'package:flutter/material.dart';

import '../config/cdn_config.dart';
import '../models/prayer.dart';
import '../services/cloud_index_service.dart';
import '../services/default_playlist_service.dart';
import '../services/last_played_service.dart';
import '../services/prayer_service.dart';
import '../services/progress_service.dart';
import '../services/song_download_service.dart' show SongDownloadService, isSubscribed;
import 'playlist_screen.dart';
import 'prayer_reader_screen.dart';
import 'settings_screen.dart';

class PrayerListScreen extends StatefulWidget {
  const PrayerListScreen({super.key});

  @override
  State<PrayerListScreen> createState() => _PrayerListScreenState();
}

class _PrayerListScreenState extends State<PrayerListScreen> {
  List<PrayerListItem> _prayers = [];
  List<VersionOption>? _indexVersions;
  bool _useCloudIndex = false;
  int _streak = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrayers();
  }

  Future<void> _playPlaylist() async {
    final ids = await DefaultPlaylistService.getPlaylistForPlayback();
    if (ids.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist is empty. Add prayers in Edit default playlist.')),
      );
      return;
    }
    final firstId = ids.first;
    final found = _prayers.where((p) => p.id == firstId);
    final item = found.isEmpty ? null : found.first;
    if (item == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prayer not found in list.')),
      );
      return;
    }
    _openReader(item);
  }

  Future<void> _loadPrayers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _prayers = [];
    });
    try {
      PrayerIndex? index;
      bool usedCloud = false;

      if (CdnConfig.isCloudEnabled) {
        index = await CloudIndexService.fetchIndex();
        if (index != null) {
          usedCloud = true;
        } else {
          index = await CloudIndexService.loadFromCache();
          if (index != null) usedCloud = true;
        }
      }

      if (index == null) {
        final status = CloudIndexService.lastFetchStatus;
        if (status == 401) {
          throw Exception('Authentication failed. Please try again.');
        }
        throw Exception('Check internet connection and try again.');
      }
      if (!mounted) return;
      final streak = await ProgressService.getStreak();
      if (!mounted) return;
      setState(() {
        _prayers = index!.prayers;
        _indexVersions = index!.versions;
        _useCloudIndex = usedCloud;
        _streak = streak;
        _loading = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        _loading = false;
      });
      debugPrint('PrayerListScreen load error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Kolenu'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'play_playlist') {
                await _playPlaylist();
              } else if (value == 'playlist') {
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const PlaylistScreen(),
                  ),
                );
              } else if (value == 'settings') {
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'play_playlist', child: Text('Play default playlist')),
              const PopupMenuItem(value: 'playlist', child: Text('Edit default playlist')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No prayers yet.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Downloading index from server...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Could not load prayers',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'Retry loading prayers',
                button: true,
                child: FilledButton(
                  onPressed: _loadPrayers,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_prayers.isEmpty) {
      return const Center(child: Text('No prayers yet.'));
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_streak > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome back',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _streak == 1
                              ? 'Good to see you here today.'
                              : 'You’ve been here $_streak days in a row — we’re glad you’re here.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ..._buildGroupedPrayerTiles(theme),
      ],
    );
  }

  static const List<String?> _categoryOrder = [
    'daily',
    'synagogue',
    'home_life',
    'non_prayer_songs',
    'shabbat',
    'camp_youth',
    'hanukkah',
    'holidays',
    'uncategorized',
    null,
  ];

  List<MapEntry<String?, List<PrayerListItem>>> _groupPrayersByCategory(List<PrayerListItem> prayers) {
    final map = <String?, List<PrayerListItem>>{};
    for (final p in prayers) {
      final cat = p.category;
      map.putIfAbsent(cat, () => []).add(p);
    }
    final result = <MapEntry<String?, List<PrayerListItem>>>[];
    for (final cat in _categoryOrder) {
      final list = map.remove(cat);
      if (list != null && list.isNotEmpty) result.add(MapEntry(cat, list));
    }
    for (final e in map.entries) {
      if (e.value.isNotEmpty) result.add(e);
    }
    return result;
  }

  List<Widget> _buildGroupedPrayerTiles(ThemeData theme) {
    final grouped = _groupPrayersByCategory(_prayers);
    return grouped.expand((entry) {
      final category = entry.key;
      final prayers = entry.value;
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            prayerCategoryDisplayName(category),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...prayers.map((item) {
          return Semantics(
            label: '${item.title}, ${item.titleHebrew}. Double tap to open.',
            button: true,
            child: ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              title: Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  item.titleHebrew,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () => _openReader(item),
            ),
          );
        }),
      ];
    }).toList();
  }

  Future<void> _openReader(PrayerListItem item) async {
    String? songFolderId;
    String prayerFile = '${item.id}/${item.file}';

    final recordingsForPrayer = item.recordings;
    if (recordingsForPrayer != null &&
        recordingsForPrayer.isNotEmpty &&
        _indexVersions != null &&
        _indexVersions!.isNotEmpty) {
      final lastPlayed = await LastPlayedService.getLastPlayedVersion(item.id);
      if (!mounted) return;
      final recordingsSet = recordingsForPrayer.toSet();
      final list = _indexVersions!
          .where((v) => recordingsSet.contains(v.id))
          .toList();
      if (list.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recording found for this prayer')),
        );
        return;
      }
      final selected = await showDialog<String?>(
        context: context,
        builder: (context) => _VersionPickerDialog(
          prayerTitle: item.title,
          versions: list,
          useFolderLayout: true,
          lastPlayedVersionId: lastPlayed,
        ),
      );
      if (!mounted) return;
      if (selected == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recording found for this prayer')),
        );
        return;
      }
      songFolderId = selected;
      prayerFile = selected.contains('/')
          ? '$selected/${item.file}'
          : '${item.id}/$selected/${item.file}';
    } else if (_useCloudIndex) {
      songFolderId = item.id;
      prayerFile = '${item.id}/${item.file}';
    }

    if (_useCloudIndex && songFolderId != null) {
      final downloaded = await SongDownloadService.isSongDownloaded(songFolderId);
      if (!downloaded) {
        if (!isSubscribed()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription required')),
          );
          return;
        }
        final success = await _downloadAndOpenReader(
          item,
          songFolderId,
          prayerFile,
        );
        if (!success) return;
      } else {
        _openReaderWithVersion(item, songFolderId, prayerFile, songFolderId);
      }
    } else {
      _openReaderWithVersion(item, songFolderId, prayerFile, null);
    }
  }

  Future<bool> _downloadAndOpenReader(
    PrayerListItem item,
    String songFolderId,
    String prayerFile,
  ) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadDialog(songFolderId: songFolderId),
    );
    if (!mounted) return false;
    if (success == true) {
      _openReaderWithVersion(item, songFolderId, prayerFile, songFolderId);
      return true;
    }
    return false;
  }

  void _openReaderWithVersion(
    PrayerListItem item,
    String? selectedVersionId,
    String prayerFile, [
    String? localSongFolderId,
  ]) {
    if (selectedVersionId != null) {
      LastPlayedService.setLastPlayedVersion(item.id, selectedVersionId);
    }
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    ProgressService.recordOpenDate(dateStr);
    ProgressService.markPrayerCompleted(item.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PrayerReaderScreen(
          prayerId: item.id,
          prayerFile: prayerFile,
          title: item.title,
          titleHebrew: item.titleHebrew,
          selectedVersionId: selectedVersionId,
          difficulty: item.difficulty,
          localSongFolderId: localSongFolderId,
        ),
      ),
    ).then((_) {
      if (mounted) _loadPrayers();
    });
  }

}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.songFolderId});

  final String songFolderId;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  bool _downloading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      await SongDownloadService.downloadSong(widget.songFolderId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_error != null ? 'Download failed' : 'Downloading'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_downloading) const CircularProgressIndicator(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_error != null)
          FilledButton(
            onPressed: () {
              setState(() {
                _error = null;
                _downloading = true;
              });
              _download();
            },
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

class _VersionPickerDialog extends StatelessWidget {
  const _VersionPickerDialog({
    required this.prayerTitle,
    required this.versions,
    this.useFolderLayout = false,
    this.lastPlayedVersionId,
  });

  final String prayerTitle;
  final List<VersionOption> versions;
  /// True when each version has a folder with matching .json + .mp3 (index versions).
  final bool useFolderLayout;
  final String? lastPlayedVersionId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('$prayerTitle — Choose version'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...versions.map((v) {
              final hasAudio = useFolderLayout || (v.audio != null && v.audio!.isNotEmpty);
              final isLastPlayed = v.id == lastPlayedVersionId;
              return ListTile(
                title: Row(
                  children: [
                    Expanded(child: Text(v.displayLabel)),
                    if (isLastPlayed)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          'Last played',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: hasAudio ? null : const Text('No audio', style: TextStyle(color: Colors.grey)),
                enabled: hasAudio,
                onTap: hasAudio ? () => Navigator.of(context).pop<String?>(v.id) : null,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<String?>(null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
