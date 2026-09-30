import 'package:b_music02/core/services/music_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_audio_query/on_audio_query.dart';

SongModel fixtureSong(int id, String title,
        {String artist = 'İzollu Memet',
        String album = 'Uzun Hava',
        String folder = '/storage/emulated/0/Music',
        int duration = 180000,
        int added = 1}) =>
    SongModel({
      '_id': id,
      '_data': '$folder/$id.mp3',
      '_uri': 'content://media/external/audio/media/$id',
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'date_added': added,
      '_size': 5242880,
      '_display_name': '$id.mp3',
      'file_extension': 'mp3',
    });

void main() {
  test('device search handles Turkish letters and words across metadata', () {
    final songs = [
      fixtureSong(1, 'Eşarbını Yan Bağlama'),
      fixtureSong(2, 'Yol')
    ];
    expect(selectMusic(songs, query: 'ESARBINI izollu').map((s) => s.id), [1]);
    expect(selectMusic(songs, query: 'uzun hava').length, 2);
    expect(selectMusic(songs, query: 'kayıp'), isEmpty);
  });
  test('sorts newest first and uses stable tie breaks', () {
    final songs = [
      fixtureSong(2, 'A', added: 1),
      fixtureSong(1, 'A', added: 1),
      fixtureSong(3, 'B', added: 2)
    ];
    expect(selectMusic(songs).map((s) => s.id), [1, 2, 3]);
    expect(
        selectMusic(songs, sort: MusicSort.newest).map((s) => s.id), [3, 1, 2]);
  });
  test('albums and equally named folders preserve separate identities', () {
    final songs = [
      fixtureSong(1, 'A', artist: 'Bir', album: 'Canlı', folder: '/Music'),
      fixtureSong(2, 'B',
          artist: 'İki', album: 'Canlı', folder: '/Downloads/Music')
    ];
    expect(groupMusic(songs, MusicGroup.album).length, 2);
    expect(groupMusic(songs, MusicGroup.folder).length, 2);
  });
  test('unknown metadata and hour-long tracks remain readable', () {
    expect(knownMetadata('<unknown>', 'Bilinmeyen'), 'Bilinmeyen');
    expect(formatMusicTime(const Duration(seconds: 3662)), '1:01:02');
    expect(formatMusicTime(const Duration(seconds: -1)), '0:00');
  });
}
