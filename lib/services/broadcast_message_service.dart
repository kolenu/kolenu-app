import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/cdn_config.dart';
import '../config/env_config.dart';

/// Display rule for a broadcast message.
enum BroadcastDisplay {
  /// Show every time app loads.
  every,

  /// Show once per user.
  once,

  /// Show up to [displayLimit] times.
  limit,
}

/// A single broadcast message from the cloud.
class BroadcastMessage {
  const BroadcastMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.display,
    this.displayLimit,
    this.link,
  });

  final String id;
  final String title;
  final String body;
  final BroadcastDisplay display;
  final int? displayLimit;
  final String? link;

  static BroadcastMessage fromJson(Map<String, dynamic> json) {
    final displayStr = (json['display'] as String? ?? 'once').toLowerCase();
    BroadcastDisplay display;
    switch (displayStr) {
      case 'every':
        display = BroadcastDisplay.every;
        break;
      case 'limit':
        display = BroadcastDisplay.limit;
        break;
      default:
        display = BroadcastDisplay.once;
    }
    return BroadcastMessage(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      display: display,
      displayLimit: json['displayLimit'] as int?,
      link: json['link'] as String?,
    );
  }
}

const String _keyShownIds = 'broadcast_shown_ids';
const String _keyShowCounts = 'broadcast_show_counts';

/// Fetches and filters broadcast messages from the cloud.
class BroadcastMessageService {
  BroadcastMessageService._();

  static Map<String, String> get _authHeaders => {
    'X-App-Service-Key': EnvConfig.downloadKey,
  };

  /// Fetch broadcast.json and return messages that should be shown now.
  static Future<List<BroadcastMessage>> fetchMessagesToShow() async {
    if (!CdnConfig.isCloudEnabled || CdnConfig.broadcastUrl == null) {
      return [];
    }
    try {
      final response = await http
          .get(Uri.parse(CdnConfig.broadcastUrl!), headers: _authHeaders)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Broadcast fetch timeout'),
          );
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return [];
      final list = json['messages'] as List<dynamic>?;
      if (list == null || list.isEmpty) return [];

      final prefs = await SharedPreferences.getInstance();
      final shownIds = _parseShownIds(prefs.getString(_keyShownIds));
      final counts = _parseShowCounts(prefs.getString(_keyShowCounts));

      final toShow = <BroadcastMessage>[];
      for (final m in list) {
        if (m is! Map<String, dynamic>) continue;
        final msg = BroadcastMessage.fromJson(m);
        if (msg.id.isEmpty) continue;

        final shouldShow = _shouldShowMessage(msg, shownIds, counts);
        if (shouldShow) {
          toShow.add(msg);
          await _recordShown(msg, prefs, shownIds, counts);
        }
      }
      return toShow;
    } catch (e, st) {
      debugPrint('BroadcastMessageService fetch error: $e\n$st');
      return [];
    }
  }

  static Set<String> _parseShownIds(String? raw) {
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      return list?.map((e) => e.toString()).toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  static Map<String, int> _parseShowCounts(String? raw) {
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>?;
      if (map == null) return {};
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static bool _shouldShowMessage(
    BroadcastMessage msg,
    Set<String> shownIds,
    Map<String, int> counts,
  ) {
    switch (msg.display) {
      case BroadcastDisplay.every:
        return true;
      case BroadcastDisplay.once:
        return !shownIds.contains(msg.id);
      case BroadcastDisplay.limit:
        final limit = msg.displayLimit ?? 1;
        final count = counts[msg.id] ?? 0;
        return count < limit;
    }
  }

  static Future<void> _recordShown(
    BroadcastMessage msg,
    SharedPreferences prefs,
    Set<String> shownIds,
    Map<String, int> counts,
  ) async {
    switch (msg.display) {
      case BroadcastDisplay.every:
        break;
      case BroadcastDisplay.once:
        shownIds.add(msg.id);
        await prefs.setString(_keyShownIds, jsonEncode(shownIds.toList()));
        break;
      case BroadcastDisplay.limit:
        counts[msg.id] = (counts[msg.id] ?? 0) + 1;
        await prefs.setString(_keyShowCounts, jsonEncode(counts));
        break;
    }
  }
}
