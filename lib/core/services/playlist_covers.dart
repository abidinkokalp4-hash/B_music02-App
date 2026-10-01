import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlaylistCovers {
  PlaylistCovers({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;
  static const key = 'b_music02_playlist_covers_v1';
  final Future<Directory> Function() _directory;
  final _paths = <String, String>{};
  String? pathFor(String name) => _paths[name];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final data = jsonDecode(prefs.getString(key) ?? '{}');
      if (data is Map) {
        _paths.clear();
        for (final entry in data.entries) {
          if (entry.key is String && entry.value is String &&
              await File(entry.value as String).exists()) {
            _paths[entry.key as String] = entry.value as String;
          }
        }
      }
    } catch (_) {
      _paths.clear();
    }
  }

  Future<void> set(String name, String sourcePath) async {
    final directory = Directory('${(await _directory()).path}/playlist_covers');
    await directory.create(recursive: true);
    final file = File('${directory.path}/${DateTime.now().microsecondsSinceEpoch}.jpg');
    await File(sourcePath).copy(file.path);
    final old = _paths[name];
    _paths[name] = file.path;
    try {
      await _save();
    } catch (_) {
      if (old == null) {
        _paths.remove(name);
      } else {
        _paths[name] = old;
      }
      await file.delete();
      rethrow;
    }
    await _delete(old);
  }

  Future<void> rename(String from, String to) async {
    final path = _paths.remove(from);
    if (path == null) return;
    _paths[to] = path;
    await _save();
  }

  Future<void> remove(String name) async {
    final path = _paths.remove(name);
    await _save();
    await _delete(path);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, jsonEncode(_paths))) {
      throw const FileSystemException('Liste kapağı kaydedilemedi.');
    }
  }

  Future<void> _delete(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A stale thumbnail can be cleaned later; the saved choice is valid.
    }
  }
}
