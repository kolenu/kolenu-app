import 'package:flutter/material.dart';

import '../models/prayer.dart';
import '../services/default_playlist_service.dart';
import '../services/last_played_service.dart';
import '../services/prayer_catalog_loader.dart';
import '../services/prayer_service.dart' show PrayerService;
import '../services/progress_service.dart';
import '../services/song_download_service.dart';
import 'prayer_catalog_welcome.dart';
import 'prayer_reader_screen.dart';
import 'settings_screen.dart';

class PrayerListScreen extends StatefulWidget {
  const PrayerListScreen({
    super.key,
    this.categoryBucket,
    this.autoOpenPrayerId,
    this.popRouteAfterReader = false,
  });

  /// When set, only prayers in this bucket (see [prayerCategoryBucketKey]) are listed.
  final String? categoryBucket;

  /// After load, opens this prayer in the reader once.
  final String? autoOpenPrayerId;

  /// When true, pops this route after the reader closes (e.g. home "Continue" shortcut).
  final bool popRouteAfterReader;

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
  bool _hasMarkedChipShown = false;
  bool _autoOpenUiReady = true;

  Future<({String? prayerId, String date, bool hasShownChip})>
  _loadLastPracticedForDisplay() async {
    final practiced = await ProgressService.getLastPracticed();
    final hasShown = await ProgressService.hasShownLastPracticedChip();
    return (
      prayerId: practiced.prayerId,
      date: practiced.date,
      hasShownChip: hasShown,
    );
  }

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
    await _openReader(item, context, playlistIds: ids, currentIndex: 0);
  }

  Future<void> _loadPrayers() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _prayers = [];
      _loadingMessage = 'Connecting to the cloud...';
      _autoOpenUiReady = widget.autoOpenPrayerId == null;
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
        _indexRecordings = loaded.snapshot.recordings;
        _useCloudIndex = loaded.snapshot.useCloudIndex;
        _loading = false;
        if (widget.autoOpenPrayerId != null) {
          _autoOpenUiReady = false;
        }
      });
      if (mounted) await runPrayerCatalogWelcomeFlow(context);
      if (mounted && widget.autoOpenPrayerId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _tryAutoOpenReader();
          }
        });
      }
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString();
        _loading = false;
        _autoOpenUiReady = true;
      });
      debugPrint('PrayerListScreen load error: $e\n$st');
    }
  }

  List<PrayerListItem> get _visiblePrayers {
    final String? b = widget.categoryBucket;
    if (b == null) return _prayers;
    return _prayers
        .where((PrayerListItem p) => prayerCategoryBucketKey(p.category) == b)
        .toList();
  }

  void _tryAutoOpenReader() {
    final String? id = widget.autoOpenPrayerId;
    if (!mounted || id == null) return;
    final PrayerListItem? found =
        _prayers.where((PrayerListItem p) => p.id == id).firstOrNull;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That prayer is not available right now.')),
      );
      setState(() => _autoOpenUiReady = true);
      return;
    }
    _openReader(found, context);
    setState(() => _autoOpenUiReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = ModalRoute.of(context)?.canPop ?? false;
    final String? bucket = widget.categoryBucket;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: canPop,
        centerTitle: true,
        title: bucket != null
            ? Text(prayerCategoryDisplayName(bucket))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kolenu',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Settings',
            onPressed: () async {
              final Object? result = await Navigator.of(context).push<Object?>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const SettingsScreen(),
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
    if (widget.autoOpenPrayerId != null && !_autoOpenUiReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<PrayerListItem> visible = _visiblePrayers;
    if (widget.categoryBucket != null && visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No prayers in this category yet.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final ThemeData theme = Theme.of(context);
    final bool showLastPracticedExtras =
        widget.categoryBucket == null && widget.autoOpenPrayerId == null;
    if (!showLastPracticedExtras) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: _buildGroupedPrayerTiles(theme),
      );
    }
    return FutureBuilder<({String? prayerId, String date, bool hasShownChip})>(
      future: _loadLastPracticedForDisplay(),
      builder: (BuildContext context, AsyncSnapshot<({String? prayerId, String date, bool hasShownChip})> snap) {
        final ({String? prayerId, String date, bool hasShownChip}) data =
            snap.data ?? (prayerId: null, date: '', hasShownChip: true);
        final ({String? prayerId, String date}) lastPracticed =
            (prayerId: data.prayerId, date: data.date);
        final String? title = lastPracticed.prayerId != null
            ? (_prayers
                      .where((PrayerListItem p) => p.id == lastPracticed.prayerId)
                      .map((PrayerListItem p) => p.title ?? p.id.replaceAll('_', ' '))
                      .firstOrNull ??
                  lastPracticed.prayerId!.replaceAll('_', ' '))
            : null;
        final bool showChip =
            title != null &&
            lastPracticed.date.isNotEmpty &&
            !data.hasShownChip;
        if (showChip && !_hasMarkedChipShown) {
          _hasMarkedChipShown = true;
          ProgressService.markLastPracticedChipShown();
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (showChip)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildLastPracticedChip(
                  theme,
                  title,
                  ProgressService.formatRelativeDate(lastPracticed.date),
                ),
              ),
            ..._buildGroupedPrayerTiles(theme),
          ],
        );
      },
    );
  }

  Widget _buildLastPracticedChip(
    ThemeData theme,
    String prayerTitle,
    String relativeDate,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 15,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Last practiced: $prayerTitle · $relativeDate',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Order matches user-facing categories in `doc/prayer_categories.md`.
  static const List<String?> _categoryOrder = [
    'daily',
    'synagogue',
    '__shabbat_holidays',
    'home_life',
    '__jewish_songs',
    'uncategorized',
    null,
  ];

  List<MapEntry<String?, List<PrayerListItem>>> _groupPrayersByCategory(
    List<PrayerListItem> prayers,
  ) {
    final map = <String?, List<PrayerListItem>>{};
    for (final p in prayers) {
      final String? cat = prayerCategoryBucketKey(p.category);
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
    final List<PrayerListItem> source = _visiblePrayers;
    if (widget.categoryBucket != null) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (int idx = 0; idx < source.length; idx++) ...[
                    _buildPrayerRow(
                      theme,
                      source[idx],
                      showDivider: idx < source.length - 1,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ];
    }
    final grouped = _groupPrayersByCategory(source);
    return grouped.map((MapEntry<String?, List<PrayerListItem>> entry) {
      final category = entry.key;
      final prayers = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 0, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 2,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Text(
                    prayerCategoryDisplayName(category).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    for (var idx = 0; idx < prayers.length; idx++) ...[
                      _buildPrayerRow(
                        theme,
                        prayers[idx],
                        showDivider: idx < prayers.length - 1,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPrayerRow(
    ThemeData theme,
    PrayerListItem item, {
    required bool showDivider,
  }) {
    final recordingIds = _useCloudIndex
        ? (item.recordings != null && item.recordings!.isNotEmpty
              ? item.recordings!
              : [item.id])
        : <String>[];
    final hasRecordings = recordingIds.isNotEmpty;
    return Builder(
      builder: (tileContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label:
                  '${item.title ?? item.id.replaceAll('_', ' ')}, ${item.titleHebrew ?? ''}. Double tap to open.',
              button: true,
              child: InkWell(
                onTap: () => _openReader(item, tileContext),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title ?? item.id.replaceAll('_', ' '),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (item.titleHebrew != null &&
                                item.titleHebrew!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item.titleHebrew!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasRecordings)
                        FutureBuilder<int>(
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
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (showDivider)
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                indent: 80,
                endIndent: 16,
              ),
          ],
        );
      },
    );
  }

  Future<void> _openReader(
    PrayerListItem item,
    BuildContext tileContext, {
    List<String>? playlistIds,
    int currentIndex = 0,
  }) async {
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
        final success = await _downloadAndOpenReader(
          item,
          songFolderId,
          prayerFile,
          playlistIds: playlistIds,
          currentIndex: currentIndex,
        );
        if (!success) return;
      } else {
        _openReaderWithRecording(
          item,
          songFolderId,
          prayerFile,
          songFolderId,
          playlistIds,
          currentIndex,
        );
      }
    } else {
      _openReaderWithRecording(
        item,
        songFolderId,
        prayerFile,
        null,
        playlistIds,
        currentIndex,
      );
    }
  }

  Future<bool> _downloadAndOpenReader(
    PrayerListItem item,
    String songFolderId,
    String prayerFile, {
    List<String>? playlistIds,
    int currentIndex = 0,
  }) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadDialog(songFolderId: songFolderId),
    );
    if (!mounted) return false;
    if (success == true) {
      _openReaderWithRecording(
        item,
        songFolderId,
        prayerFile,
        songFolderId,
        playlistIds,
        currentIndex,
      );
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
          title: item.title ?? item.id.replaceAll('_', ' '),
          titleHebrew: item.titleHebrew ?? '',
        );
        metadataMap[v.id] = meta;
        cachedMap[v.id] = await SongDownloadService.isSongDownloaded(v.id);
      }),
    );
    if (!context.mounted) return null;

    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (BuildContext ctx) => _ChooseRecordingScreen(
          prayerTitle: item.title ?? item.id.replaceAll('_', ' '),
          prayerTitleHebrew: item.titleHebrew,
          recordings: recordings,
          lastPlayedRecordingId: lastPlayedRecordingId,
          metadataMap: metadataMap,
          cachedMap: cachedMap,
          onCacheChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _openReaderWithRecording(
    PrayerListItem item,
    String? selectedRecordingId,
    String prayerFile, [
    String? localSongFolderId,
    List<String>? playlistIds,
    int currentPlaylistIndex = 0,
  ]) {
    if (selectedRecordingId != null) {
      LastPlayedService.setLastPlayedRecording(item.id, selectedRecordingId);
    }
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    ProgressService.recordOpenDate(dateStr);
    ProgressService.markPrayerCompleted(item.id);
    ProgressService.setLastPracticed(item.id);
    Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute<Map<String, dynamic>>(
            builder: (context) => PrayerReaderScreen(
              prayerId: item.id,
              prayerFile: prayerFile,
              title: item.title ?? item.id.replaceAll('_', ' '),
              titleHebrew: item.titleHebrew ?? '',
              selectedRecordingId: selectedRecordingId,
              difficulty: item.difficulty,
              localSongFolderId: localSongFolderId,
              playlistIds: playlistIds,
              currentPlaylistIndex: currentPlaylistIndex,
            ),
          ),
        )
        .then((Map<String, dynamic>? result) {
          if (!mounted) return;
          if (widget.popRouteAfterReader) {
            Navigator.of(context).pop();
            return;
          }
          _loadPrayers();
          if (result != null &&
              result['play_next'] != null &&
              result['playlist_ids'] != null) {
            final String nextId = result['play_next'] as String;
            final List<String> ids =
                result['playlist_ids'] as List<String>;
            final int nextIndex = ids.indexOf(nextId);
            if (nextIndex >= 0) {
              final Iterable<PrayerListItem> found =
                  _prayers.where((PrayerListItem p) => p.id == nextId);
              final PrayerListItem? nextItem =
                  found.isEmpty ? null : found.first;
              if (nextItem != null && mounted) {
                _openReader(
                  nextItem,
                  context,
                  playlistIds: ids,
                  currentIndex: nextIndex,
                );
              }
            }
          }
        });
  }
}

/// Full-screen modal for picking a recording (replaces the previous bottom sheet).
class _ChooseRecordingScreen extends StatelessWidget {
  const _ChooseRecordingScreen({
    required this.prayerTitle,
    this.prayerTitleHebrew,
    required this.recordings,
    this.lastPlayedRecordingId,
    required this.metadataMap,
    required this.cachedMap,
    required this.onCacheChanged,
  });

  final String prayerTitle;
  final String? prayerTitleHebrew;
  final List<RecordingOption> recordings;
  final String? lastPlayedRecordingId;
  final Map<String, String?> metadataMap;
  final Map<String, bool> cachedMap;
  final VoidCallback onCacheChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Choose recording'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayerTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (prayerTitleHebrew != null &&
                    prayerTitleHebrew!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    prayerTitleHebrew!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: recordings.length,
              separatorBuilder: (BuildContext context, int index) => Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              itemBuilder: (BuildContext ctx, int index) {
                final RecordingOption v = recordings[index];
                final bool isLastPlayed = v.id == lastPlayedRecordingId;
                final String? meta = metadataMap[v.id];
                final bool cached = cachedMap[v.id] ?? false;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
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
                      ? Text(meta, maxLines: 3, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: cached
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove from device',
                          onPressed: () async {
                            final bool? confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (BuildContext c) => AlertDialog(
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
                              onCacheChanged();
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            }
                          },
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(v.id),
                );
              },
            ),
          ),
        ],
      ),
    );
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
