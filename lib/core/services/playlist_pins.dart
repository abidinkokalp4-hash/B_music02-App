import 'package:shared_preferences/shared_preferences.dart';

/// Stores playlist shortcuts independently of their songs and cover images.
class PlaylistPins {
  static const key = 'b_music02_playlist_pins_v1';
  final _names = <String>{};
  Future<void> _operation = Future<void>.value();

  List<String> get names => List.unmodifiable(_names);
  bool contains(String name) => _names.contains(name);

  Future<void> load(Iterable<String> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.get(key);
    final valid = playlists.toSet();
    _names
      ..clear()
      ..addAll(stored is List
          ? stored.whereType<String>().where(valid.contains)
          : const <String>[]);
  }

  Future<void> toggle(String name) => _update(() {
        if (!_names.remove(name)) _names.add(name);
      });

  Future<void> rename(String from, String to) => _update(() {
        final renamed = _names.map((name) => name == from ? to : name).toList();
        _names
          ..clear()
          ..addAll(renamed);
      });

  Future<void> remove(String name) => _update(() => _names.remove(name));

  Future<void> replace(Iterable<String> names) {
    final values = names.toSet();
    return _update(() => _names
      ..clear()
      ..addAll(values));
  }

  Future<void> _update(void Function() change) {
    final next = _operation.then((_) async {
      final previous = _names.toList();
      final prefs = await SharedPreferences.getInstance();
      change();
      try {
        if (!await prefs.setStringList(key, names)) {
          throw StateError('Liste sabitleme kaydedilemedi.');
        }
      } catch (_) {
        _names
          ..clear()
          ..addAll(previous);
        rethrow;
      }
    });
    _operation = next.catchError((Object _) {});
    return next;
  }
}
