import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  SearchHistoryService._();

  static final SearchHistoryService instance = SearchHistoryService._();

  static const _key = 'b_music02_search_history_v1';

  Future<List<String>> recent({int limit = 12}) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key) ?? const <String>[];
    return values.take(limit).toList(growable: false);
  }

  Future<String?> latest() async {
    final values = await recent(limit: 1);
    return values.isEmpty ? null : values.first;
  }

  Future<void> record(String query) async {
    final clean = query.trim();
    if (clean.length < 2 || clean.toLowerCase() == 'popular music') return;

    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key) ?? <String>[];
    values.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    values.insert(0, clean);
    if (values.length > 12) values.removeRange(12, values.length);
    await prefs.setStringList(_key, values);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
