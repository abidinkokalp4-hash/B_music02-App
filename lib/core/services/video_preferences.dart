import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoPreferences extends ChangeNotifier {
  static final instance = VideoPreferences();
  static const key = 'b_music02_video_library_v1';
  final _favorites = <String>{};
  final _folders = <String>{};
  List<String> get pinnedFolders => List.unmodifiable(_folders);
  bool isFolderPinned(String name) => _folders.contains(name);
  Future<void> toggleFolder(String name) async { await load(); if (!_folders.remove(name)) _folders.add(name); await _save(); notifyListeners(); }
  final _positions = <String, int>{};
  final _recent = <String>[];
  final _known = <String>{};
  final _new = <String>{};
  bool _baseline = false;
  bool isNew(String id) => _new.contains(id);
  bool _loaded = false;
  Future<void>? _loading;
  // Only pending work is retained. A finished future must not outlive the
  // zone that created it (long-lived singletons would otherwise chain new
  // writes onto a completed future whose zone may no longer run callbacks).
  Future<void>? _write;
  bool isFavorite(String id) => _favorites.contains(id);
  Duration position(String id) => Duration(milliseconds: _positions[id] ?? 0);
  List<String> get recent => List.unmodifiable(_recent);

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }
  Future<void> _load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final value = jsonDecode(prefs.getString(key) ?? '{}');
      if (value is Map) {
        _baseline = value['baseline'] == true;
        if (value['folders'] is List) _folders.addAll((value['folders'] as List).whereType<String>());
        if (value['known'] is List) _known.addAll((value['known'] as List).whereType<String>());
        if (value['new'] is List) _new.addAll((value['new'] as List).whereType<String>());
        final favorites = value['favorites'];
        if (favorites is List) _favorites.addAll(favorites.whereType<String>());
        final positions = value['positions'];
        if (positions is Map) {
          for (final entry in positions.entries) {
            if (entry.key is String && entry.value is int && entry.value >= 0) {
              _positions[entry.key] = entry.value;
            }
          }
        }
        final recent = value['recent'];
        if (recent is List)
          _recent.addAll(recent.whereType<String>().toSet().take(100));
      }
    } on FormatException {
      // A damaged history must never prevent local video playback.
    }
    _loaded = true;
  }

  Future<void> observeLibrary(Set<String> ids) async {
    await load();
    if (_baseline) _new.addAll(ids.difference(_known));
    _new.retainAll(ids);
    _known..clear()..addAll(ids);
    _baseline = true;
    await _save();
    notifyListeners();
  }

  Future<void> markSeen(String id) async {
    await load();
    if (_new.remove(id)) { await _save(); notifyListeners(); }
  }

  Future<void> toggleFavorite(String id) async {
    await load();
    if (!_favorites.remove(id)) _favorites.add(id);
    await _save();
    notifyListeners();
  }

  Future<void> record(String id, Duration position, Duration duration) async {
    await load();
    final total = duration.inMilliseconds;
    final at = position.inMilliseconds.clamp(0, total < 0 ? 0 : total);
    _positions[id] = total > 0 && total - at > 3000 ? at : 0;
    _recent.remove(id);
    _recent.insert(0, id);
    if (_recent.length > 100) _recent.removeRange(100, _recent.length);
    await _save();
    notifyListeners();
  }

  Future<void> _save() {
    final snapshot = jsonEncode({
      'baseline': _baseline, 'known': _known.toList(), 'new': _new.toList(),
      'favorites': _favorites.toList(), 'folders': _folders.toList(),
      'positions': _positions,
      'recent': _recent,
    });
    final previous = _write;
    Future<void> write() async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, snapshot))
        throw StateError('Video geçmişi kaydedilemedi.');
    }

    final next = previous == null ? write() : previous.then((_) => write());
    late final Future<void> settled;
    settled = next.catchError((Object _) {}).whenComplete(() {
      if (identical(_write, settled)) _write = null;
    });
    _write = settled;
    return next;
  }
}
