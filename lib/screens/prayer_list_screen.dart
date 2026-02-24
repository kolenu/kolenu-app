import 'package:flutter/material.dart';

import '../config/cdn_config.dart';
import '../models/prayer.dart';
import '../services/broadcast_message_service.dart';
import '../services/cache_keys_service.dart';
import '../services/offline_tip_service.dart';
import '../services/cloud_index_service.dart';
import '../services/default_playlist_service.dart';
import '../services/last_played_service.dart';
import '../services/prayer_service.dart' show PrayerIndex, PrayerService;
import '../services/progress_service.dart';
import '../services/song_download_service.dart'
    show SongDownloadService, isSubscribed;
import 'prayer_reader_screen.dart';
import 'settings_screen.dart';

class PrayerListScreen extends StatefulWidget {
  const PrayerListScreen({super.key});

  @override
  State<PrayerListScreen> createState() => _PrayerListScreenState();
}

class _PrayerListScreenState extends State<PrayerListScreen> {
  List<PrayerListItem> _prayers = [];
  List<RecordingOption>? _indexRecordings;
  bool _useCloudIndex = false;
  bool _loading = true;
  String? _error;
  String _loadingMessage = 'Connecting to the cloud...';

  @override
  void initState() {
    super.initState();
    _loadPrayers();
  }

  Future<void> _maybeShowOfflineTip() async {
    if (!CdnConfig.isCloudEnabled) return;
    final shown = await OfflineTipService.hasShownTip();
    if (shown) return;
    if (!mounted) return;
    await OfflineTipService.markTipShown();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tap a prayer to download it for offline listening. The pin icon shows which prayers are cached.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<void> _maybeShowBroadcastMessages() async {
    final messages = await BroadcastMessageService.fetchMessagesToShow();
    if (!mounted || messages.isEmpty) return;
    for (final msg in messages) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(msg.title),
          content: SingleChildScrollView(child: Text(msg.body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _playPlaylist() async {
    final ids = await DefaultPlaylistService.getPlaylistForPlayback();
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
    if (!context.mounted) return;
    // ignore: use_build_context_synchronously - guarded by mounted check above
    await _openReader(item, context);
  }

  Future<void> _loadPrayers() async {
    if (!mounted) return;
    final forceCloudRefresh =
        await CacheKeysService.consumeCacheClearedMessage();
    setState(() {
      _loading = true;
      _error = null;
      _prayers = [];
      _loadingMessage = 'Connecting to the cloud...';
    });

    if (forceCloudRefresh && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security key changed. Connecting to the cloud...'),
          duration: Duration(seconds: 4),
        ),
      );
    }

    try {
      PrayerIndex? index;
      bool usedCloud = false;

      if (CdnConfig.isCloudEnabled) {
        index = await CloudIndexService.fetchIndex();
        if (index != null) {
          usedCloud = true;
        } else if (!forceCloudRefresh) {
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
      final resolvedIndex = index;
      if (!mounted) return;
      setState(() {
        _prayers = resolvedIndex.prayers;
        _indexRecordings = resolvedIndex.recordings;
        _useCloudIndex = usedCloud;
        _loading = false;
      });
      if (mounted) await _maybeShowOfflineTip();
      if (mounted) await _maybeShowBroadcastMessages();
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString();
        _loading = false;
      });
      debugPrint('PrayerListScreen load error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Kolenu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              final result = await Navigator.of(context).push<Object?>(
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              if (result == 'play_playlist' && mounted) {
                await _playPlaylist();
              }
            },
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
                _loadingMessage,
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
                label: 'Retry cloud connection',
                button: true,
                child: FilledButton(
                  onPressed: _loadPrayers,
                  child: const Text('Retry Cloud Connection'),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: _buildGroupedPrayerTiles(theme),
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

  List<MapEntry<String?, List<PrayerListItem>>> _groupPrayersByCategory(
    List<PrayerListItem> prayers,
  ) {
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

  Future<int> _countCachedRecordings(List<String> recordingIds) async {
    int count = 0;
    for (final id in recordingIds) {
      if (await SongDownloadService.isSongDownloaded(id)) count++;
    }
    return count;
  }

  List<Widget> _buildGroupedPrayerTiles(ThemeData theme) {
    final grouped = _groupPrayersByCategory(_prayers);
    return grouped.map((entry) {
      final category = entry.key;
      final prayers = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 20),
              child: Text(
                prayerCategoryDisplayName(category).toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.5,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ...prayers.map((item) {
          final recordingIds = _useCloudIndex
              ? (item.recordings != null && item.recordings!.isNotEmpty
                    ? item.recordings!
                    : [item.id])
              : <String>[];
          final hasRecordings = recordingIds.isNotEmpty;
          return Builder(
            builder: (tileContext) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                        color: Colors.black.withValues(alpha: 0.04),
                      ),
                    ],
                  ),
                  child: Semantics(
                    label:
                        '${item.title}, ${item.titleHebrew}. Double tap to open.',
                    button: true,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.6),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.titleHebrew,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      trailing: hasRecordings
                          ? FutureBuilder<int>(
                              future: _countCachedRecordings(recordingIds),
                              builder: (ctx, snap) {
                                final cached = snap.data ?? 0;
                                final total = recordingIds.length;
                                final anyCached = cached > 0;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (anyCached)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.offline_pin_rounded,
                                              size: 18,
                                              color: theme.colorScheme.primary,
                                            ),
                                            if (total > 1) ...[
                                              const SizedBox(width: 2),
                                              Text(
                                                '$cached/$total',
                                                style: theme.textTheme.labelSmall
                                                    ?.copyWith(
                                                      color:
                                                          theme.colorScheme.primary,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                );
                              },
                            )
                          : Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                      onTap: () => _openReader(item, tileContext),
                    ),
                  ),
                ),
              );
            },
          );
        }),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _openReader(
    PrayerListItem item,
    BuildContext tileContext,
  ) async {
    String? songFolderId;
    String prayerFile = '${item.id}/${item.file}';

    final recordingsForPrayer = item.recordings;
    if (recordingsForPrayer != null &&
        recordingsForPrayer.isNotEmpty &&
        _indexRecordings != null &&
        _indexRecordings!.isNotEmpty) {
      final lastPlayed = await LastPlayedService.getLastPlayedRecording(
        item.id,
      );
      if (!mounted) return;
      final recordingsSet = recordingsForPrayer.toSet();
      final list = _indexRecordings!
          .where((v) => recordingsSet.contains(v.id))
          .toList();
      if (list.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recording found for this prayer')),
        );
        return;
      }
      if (!tileContext.mounted) return;
      final selected = await _showRecordingDropdown(
        context: tileContext,
        item: item,
        recordings: list,
        lastPlayedRecordingId: lastPlayed,
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
      final downloaded = await SongDownloadService.isSongDownloaded(
        songFolderId,
      );
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
        _openReaderWithRecording(item, songFolderId, prayerFile, songFolderId);
      }
    } else {
      _openReaderWithRecording(item, songFolderId, prayerFile, null);
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
      _openReaderWithRecording(item, songFolderId, prayerFile, songFolderId);
      return true;
    }
    return false;
  }

  Future<String?> _showRecordingDropdown({
    required BuildContext context,
    required PrayerListItem item,
    required List<RecordingOption> recordings,
    String? lastPlayedRecordingId,
  }) async {
    final metadataMap = <String, String?>{};
    final cachedMap = <String, bool>{};
    await Future.wait(
      recordings.map((v) async {
        final meta = await PrayerService.loadRecordingMetadata(
          v.id,
          id: item.id,
          title: item.title,
          titleHebrew: item.titleHebrew,
        );
        metadataMap[v.id] = meta;
        cachedMap[v.id] = await SongDownloadService.isSongDownloaded(v.id);
      }),
    );
    if (!context.mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Choose recording',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...recordings.map((v) {
                final isLastPlayed = v.id == lastPlayedRecordingId;
                final meta = metadataMap[v.id];
                final cached = cachedMap[v.id] ?? false;
                return ListTile(
                  leading: cached
                      ? Icon(
                          Icons.offline_pin_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        )
                      : null,
                  title: Row(
                    children: [
                      Expanded(child: Text(v.displayLabel)),
                      if (isLastPlayed)
                        Text(
                          'Last played',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  subtitle: meta != null && meta.isNotEmpty
                      ? Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: cached
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove from device',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: const Text('Remove from device?'),
                                content: Text(
                                  'Remove "${v.displayLabel}" from this device? You can download it again later.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && ctx.mounted) {
                              await SongDownloadService.deleteRecording(v.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) setState(() {});
                            }
                          },
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, v.id),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openReaderWithRecording(
    PrayerListItem item,
    String? selectedRecordingId,
    String prayerFile, [
    String? localSongFolderId,
  ]) {
    if (selectedRecordingId != null) {
      LastPlayedService.setLastPlayedRecording(item.id, selectedRecordingId);
    }
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    ProgressService.recordOpenDate(dateStr);
    ProgressService.markPrayerCompleted(item.id);
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => PrayerReaderScreen(
              prayerId: item.id,
              prayerFile: prayerFile,
              title: item.title,
              titleHebrew: item.titleHebrew,
              selectedRecordingId: selectedRecordingId,
              difficulty: item.difficulty,
              localSongFolderId: localSongFolderId,
            ),
          ),
        )
        .then((_) {
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
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
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
