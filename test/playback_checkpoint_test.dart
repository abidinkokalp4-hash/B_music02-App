import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:b_music02/core/services/playback_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final checkpoint = PlaybackCheckpoint(entries: [
    SavedQueueEntry(
        uri: Uri.parse('content://media/audio/1'),
        item: const MediaItem(
            id: '1',
            title: 'Şarkı',
            artist: 'Sanatçı',
            duration: Duration(minutes: 2))),
    SavedQueueEntry(
        uri: Uri.file('/downloads/music.mp3'),
        item: const MediaItem(
            id: 'file:///downloads/music.mp3',
            title: 'İndirilen',
            extras: {'localPath': '/downloads/music.mp3'})),
  ], index: 1, position: const Duration(seconds: 42));
  test('queue, download paths and paused resume position survive serialization',
      () {
    final restored = PlaybackCheckpoint.decode(checkpoint.encode())!;
    expect(restored.entries.length, 2);
    expect(restored.index, 1);
    expect(restored.position, const Duration(seconds: 42));
    expect(
        restored.entries[1].item.extras?['localPath'], '/downloads/music.mp3');
  });
  test('corrupt data and unsupported sources cannot shift the selected index',
      () {
    expect(PlaybackCheckpoint.decode('broken'), isNull);
    final data = jsonDecode(checkpoint.encode()) as Map<String, dynamic>;
    data['entries'][0]['uri'] = 'https://example.com/track';
    expect(PlaybackCheckpoint.decode(jsonEncode(data)), isNull);
    data['entries'] = [];
    expect(PlaybackCheckpoint.decode(jsonEncode(data)), isNull);
  });
  test('out-of-range positions clamp to the track duration', () {
    final data = jsonDecode(checkpoint.encode()) as Map<String, dynamic>;
    data['index'] = 0;
    data['position'] = 999999;
    expect(PlaybackCheckpoint.decode(jsonEncode(data))!.position,
        const Duration(minutes: 2));
    data['position'] = -1;
    expect(
        PlaybackCheckpoint.decode(jsonEncode(data))!.position, Duration.zero);
    data['index'] = -1;
    expect(PlaybackCheckpoint.decode(jsonEncode(data)), isNull);
  });
}
