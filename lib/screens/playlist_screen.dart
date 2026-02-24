import 'package:flutter/material.dart';

import '../config/cdn_config.dart';
import '../models/prayer.dart';
import '../services/cloud_index_service.dart';
import '../services/default_playlist_service.dart';
import '../services/prayer_service.dart';

/// Screen to edit the default playlist (ordered list of prayers for "Play playlist").
class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<String> _playlist = [];
  List<PrayerListItem> _allPrayers = [];
  bool _shuffle = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    PrayerIndex? index;
    if (CdnConfig.isCloudEnabled) {
      index = await CloudIndexService.fetchOrLoadCached();
    }
    index ??= const PrayerIndex(prayers: [], recordings: null);
    final playlist = await DefaultPlaylistService.getPlaylist();
    final shuffle = await DefaultPlaylistService.getShuffle();
    if (!mounted) return;
    setState(() {
      _allPrayers =
          (index ?? const PrayerIndex(prayers: [], recordings: null)).prayers;
      _playlist = playlist;
      _shuffle = shuffle;
      _loading = false;
    });
  }

  Future<void> _savePlaylist() async {
    await DefaultPlaylistService.setPlaylist(_playlist);
  }

  Future<void> _saveShuffle(bool v) async {
    setState(() => _shuffle = v);
    await DefaultPlaylistService.setShuffle(v);
  }

  void _removeFromPlaylist(String prayerId) {
    setState(() {
      _playlist = _playlist.where((id) => id != prayerId).toList();
    });
    _savePlaylist();
  }

  void _addToPlaylist(String prayerId) {
    if (_playlist.contains(prayerId)) return;
    setState(() {
      _playlist = [..._playlist, prayerId];
    });
    _savePlaylist();
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final id = _playlist.removeAt(oldIndex);
      _playlist.insert(newIndex, id);
    });
    _savePlaylist();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final inPlaylist = _playlist.toSet();
    final notInPlaylist = _allPrayers
        .where((p) => !inPlaylist.contains(p.id))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Default playlist')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Shuffle when playing'),
            subtitle: Text(_shuffle ? 'On' : 'Off'),
            value: _shuffle,
            onChanged: _saveShuffle,
          ),
          const Divider(height: 1),
          Expanded(
            child: _playlist.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_add,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Playlist is empty',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add prayers below',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _playlist.length,
                    onReorder: _reorder,
                    itemBuilder: (context, index) {
                      final id = _playlist[index];
                      final found = _allPrayers.where((p) => p.id == id);
                      final item = found.isEmpty ? null : found.first;
                      final title = item?.title ?? id;
                      return Card(
                        key: ValueKey(id),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                          title: Text(title),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _removeFromPlaylist(id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Add to playlist',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: notInPlaylist.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(p.title),
                    onPressed: () => _addToPlaylist(p.id),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
