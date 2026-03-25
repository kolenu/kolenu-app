import '../config/cdn_config.dart';
import '../models/prayer.dart';
import 'cache_keys_service.dart';
import 'cloud_index_service.dart';
import 'prayer_service.dart' show PrayerIndex;

/// Snapshot of the cloud (or cached) prayer index used by Home and list screens.
class PrayerCatalogSnapshot {
  const PrayerCatalogSnapshot({
    required this.prayers,
    this.recordings,
    required this.useCloudIndex,
  });

  final List<PrayerListItem> prayers;
  final List<RecordingOption>? recordings;
  final bool useCloudIndex;
}

/// Shared CDN index load path for [PrayerListScreen] and [HomeScreen].
class PrayerCatalogLoader {
  PrayerCatalogLoader._();

  /// Returns catalog data and whether a cache-clear signal was consumed (for UI snackbars).
  static Future<({PrayerCatalogSnapshot snapshot, bool cacheWasCleared})>
  loadCatalog() async {
    final bool cacheWasCleared =
        await CacheKeysService.consumeCacheClearedMessage();

    PrayerIndex? index;
    bool usedCloud = false;

    if (CdnConfig.isCloudEnabled) {
      index = await CloudIndexService.fetchIndex();
      if (index != null) {
        usedCloud = true;
      } else if (!cacheWasCleared) {
        index = await CloudIndexService.loadFromCache();
        if (index != null) usedCloud = true;
      }
    }

    if (index == null) {
      final int? status = CloudIndexService.lastFetchStatus;
      if (status == 401) {
        throw Exception('Authentication failed. Please try again.');
      }
      throw Exception('Check internet connection and try again.');
    }

    final PrayerCatalogSnapshot snapshot = PrayerCatalogSnapshot(
      prayers: index.prayers,
      recordings: index.recordings,
      useCloudIndex: usedCloud,
    );
    return (snapshot: snapshot, cacheWasCleared: cacheWasCleared);
  }
}
