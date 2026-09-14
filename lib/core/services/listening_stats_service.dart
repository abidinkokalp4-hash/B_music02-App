import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ListeningStatsService {
  ListeningStatsService._();

  static final ListeningStatsService instance = ListeningStatsService._();
  static const _key = 'b_music02_listening_stats_v1';

  final Map<int, int> _counts = <int, int>{};
  bool _loaded = false;

  Future<void> initialize() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final id = int.tryParse(entry.key.toString());
            final value = int.tryParse(entry.value.toString());
            if (id != null && value != null) _counts[id] = value;
          }
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  int countFor(int songId) => _counts[songId] ?? 0;

  Future<void> record(int songId) async {
    await initialize();
    _counts[songId] = (_counts[songId] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_counts.map((key, value) => MapEntry(key.toString(), value))),
    );
  }
}
