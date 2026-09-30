import 'dart:convert';

import 'package:audio_service/audio_service.dart';

class SavedQueueEntry {
  const SavedQueueEntry({required this.uri, required this.item});
  final Uri uri;
  final MediaItem item;

  Map<String, dynamic> toJson() => {
        'uri': uri.toString(),
        'id': item.id,
        'title': item.title,
        'artist': item.artist,
        'album': item.album,
        'duration': item.duration?.inMilliseconds,
        'localPath': item.extras?['localPath'],
      };

  static SavedQueueEntry? fromJson(dynamic value) {
    if (value is! Map) return null;
    final uri = Uri.tryParse(value['uri']?.toString() ?? '');
    final id = value['id']?.toString() ?? '';
    if (uri == null ||
        !{'content', 'file'}.contains(uri.scheme) ||
        id.isEmpty) {
      return null;
    }
    final duration = int.tryParse(value['duration']?.toString() ?? '');
    final path = value['localPath'];
    return SavedQueueEntry(
      uri: uri,
      item: MediaItem(
        id: id,
        title: value['title']?.toString() ?? 'Müzik',
        artist: value['artist']?.toString(),
        album: value['album']?.toString(),
        duration: duration == null || duration < 0
            ? null
            : Duration(milliseconds: duration),
        extras: path is String ? {'localPath': path} : null,
      ),
    );
  }
}

class PlaybackCheckpoint {
  const PlaybackCheckpoint({
    required this.entries,
    required this.index,
    required this.position,
  });
  static const key = 'b_music02_playback_checkpoint_v1';
  final List<SavedQueueEntry> entries;
  final int index;
  final Duration position;

  String encode() => jsonEncode({
        'entries': entries.map((entry) => entry.toJson()).toList(),
        'index': index,
        'position': position.inMilliseconds,
      });

  static PlaybackCheckpoint? decode(String? raw) {
    try {
      final value = jsonDecode(raw ?? '');
      if (value is! Map || value['entries'] is! List) return null;
      final rows = value['entries'] as List;
      final entries = rows.map(SavedQueueEntry.fromJson).toList();
      // An invalid row invalidates the checkpoint instead of shifting its index.
      if (entries.isEmpty || entries.any((entry) => entry == null)) return null;
      final index = int.tryParse(value['index']?.toString() ?? '');
      if (index == null || index < 0 || index >= entries.length) return null;
      final position = int.tryParse(value['position']?.toString() ?? '') ?? 0;
      final duration = entries[index]!.item.duration?.inMilliseconds;
      return PlaybackCheckpoint(
        entries: entries.cast<SavedQueueEntry>(),
        index: index,
        position:
            Duration(milliseconds: position.clamp(0, duration ?? 86400000)),
      );
    } catch (_) {
      return null;
    }
  }
}
