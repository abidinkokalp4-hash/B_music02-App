import 'package:shared_preferences/shared_preferences.dart';

/// Recent search queries, newest first, persisted locally.
class SearchHistory {
  SearchHistory({this.prefsLoader});

  static final SearchHistory instance = SearchHistory();

  static const _key = 'b_music02_search_history_v1';
  static const maxItems = 20;

  final Future<SharedPreferences> Function()? prefsLoader;
  List<String> _items = [];
  bool _loaded = false;

  List<String> get items => List.unmodifiable(_items);

  Future<SharedPreferences> _prefs() =>
      (prefsLoader ?? SharedPreferences.getInstance)();

  Future<List<String>> load() async {
    if (_loaded) return items;
    final p = await _prefs();
    _items = p.getStringList(_key) ?? <String>[];
    _loaded = true;
    return items;
  }

  Future<void> add(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;
    await load();
    _items.removeWhere((e) => e.toLowerCase() == query.toLowerCase());
    _items.insert(0, query);
    if (_items.length > maxItems) _items = _items.sublist(0, maxItems);
    await _save();
  }

  Future<void> remove(String query) async {
    await load();
    _items.removeWhere((e) => e == query);
    await _save();
  }

  Future<void> clear() async {
    await load();
    _items = [];
    await _save();
  }

  Future<void> _save() async {
    final p = await _prefs();
    await p.setStringList(_key, _items);
  }
}
