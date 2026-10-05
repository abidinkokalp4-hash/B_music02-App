import 'package:audio_service/audio_service.dart';
import 'package:b_music02/core/services/local_music_service.dart';
import 'package:b_music02/core/services/playback_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_catalog_test.dart' show fixtureSong;
import 'support/fake_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestAudioPlayer player;
  late LocalMusicService music;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    player = TestAudioPlayer();
    music = LocalMusicService.forTesting(player);
    music.songs = [
      fixtureSong(1, 'Bir'),
      fixtureSong(2, 'İki'),
      fixtureSong(3, 'Üç'),
      fixtureSong(4, 'Dört')
    ];
    await player.setAudioSources(
        music.songs
            .take(3)
            .map((s) => AudioSource.uri(Uri.parse(s.uri!),
                tag: MediaItem(id: '${s.id}', title: s.title)))
            .toList(),
        initialIndex: 1);
  });
  tearDown(() async {
    await player.close();
    music.dispose();
  });
  test('A-B repeat seeks at boundary and clears when the track changes', () async {
    await music.setABLoop(const Duration(seconds: 10), const Duration(seconds: 15));
    expect(player.position, const Duration(seconds: 10));
    player.isPlaying = true;
    player.positions.add(const Duration(seconds: 15));
    await Future<void>.delayed(Duration.zero);
    expect(player.position, const Duration(seconds: 10));
    await player.seek(Duration.zero, index: 2);
    expect(music.loopA, isNull);
    expect(music.loopB, isNull);
  });
  test('A-B rejects invalid intervals', () async {
    await expectLater(music.setABLoop(const Duration(seconds: 12), const Duration(seconds: 10)), throwsArgumentError);
    await expectLater(music.setABLoop(Duration.zero, const Duration(hours: 3)), throwsArgumentError);
  });
  test('save queue preserves displayed order without changing playback', () async {
    await music.moveQueueItem(0, 2);
    final before = music.queueItems.map((x) => int.parse(x.id)).toList();
    final current = player.currentIndex;
    await music.saveQueueAsPlaylist('Yolculuk');
    expect(music.playlists['Yolculuk'], before);
    expect(player.currentIndex, current);
    await expectLater(music.saveQueueAsPlaylist('Yolculuk'), throwsArgumentError);
  });
  test(
      'resume prunes missing files, keeps the current song and does not autoplay',
      () async {
    await music.savePlaybackCheckpoint();
    final prefs = await SharedPreferences.getInstance();
    final previous =
        PlaybackCheckpoint.decode(prefs.getString(PlaybackCheckpoint.key))!;
    await prefs.setString(
        PlaybackCheckpoint.key,
        PlaybackCheckpoint(
                entries: previous.entries,
                index: 2,
                position: const Duration(seconds: 42))
            .encode());
    await player.setAudioSources([]);
    music.hasPermission = true;
    music.songs.removeAt(1);
    await music.restorePlaybackCheckpoint();
    expect(music.queueItems.map((item) => item.id), ['1', '3']);
    expect(player.currentIndex, 1);
    expect(player.position, const Duration(seconds: 42));
    expect(player.playing, false);
  });
  test('a denied permission never erases the saved local queue', () async {
    await music.savePlaybackCheckpoint();
    final prefs = await SharedPreferences.getInstance();
    final savedQueue =
        PlaybackCheckpoint.decode(prefs.getString(PlaybackCheckpoint.key))!;
    final saved = PlaybackCheckpoint(entries: [
      ...savedQueue.entries,
      SavedQueueEntry(
          uri: Uri.file('/downloads/a.mp3'),
          item: const MediaItem(
              id: 'download-a',
              title: 'İndirilen',
              extras: {'localPath': '/downloads/a.mp3'})),
    ], index: savedQueue.index, position: savedQueue.position)
        .encode();
    await prefs.setString(PlaybackCheckpoint.key, saved);
    await player.setAudioSources([]);
    music.hasPermission = false;
    await music.restorePlaybackCheckpoint();
    await music.savePlaybackCheckpoint();
    expect(prefs.getString(PlaybackCheckpoint.key), saved);
  });
  test(
      'play next inserts after current without changing current song or position',
      () async {
    player.at = const Duration(seconds: 20);
    await player.setShuffleModeEnabled(true);
    await music.enqueue(music.songs[3], next: true);
    expect(music.queueItems.map((item) => item.id), ['1', '2', '4', '3']);
    expect(player.currentIndex, 1);
    expect(player.position, const Duration(seconds: 20));
    expect(player.shuffleModeEnabled, false);
  });
  test(
      'serialized queue changes retain the current item and persist the final order',
      () async {
    await Future.wait([music.moveQueueItem(0, 2), music.removeQueueItem(1)]);
    expect(music.queueItems.map((item) => item.id), ['2', '1']);
    expect(music.currentMediaItem?.id, '2');
    final prefs = await SharedPreferences.getInstance();
    final saved =
        PlaybackCheckpoint.decode(prefs.getString(PlaybackCheckpoint.key))!;
    expect(saved.entries.map((entry) => entry.item.id), ['2', '1']);
    expect(saved.index, 0);
  });
  test('clearing the queue retains just the current song', () async {
    await music.clearUpcoming();
    expect(music.queueItems.single.id, '2');
    expect(player.currentIndex, 0);
    await music.removeQueueItem(0);
    expect(music.queueItems, isEmpty);
    expect(music.currentMediaItem, isNull);
    expect(player.playing, false);
  });

  test(
      'deleting an upcoming download removes every occurrence and keeps playing',
      () async {
    const path = '/downloads/deleted.ogg';
    final local = player.sequence[1];
    AudioSource download() => AudioSource.uri(Uri.file(path),
        tag: const MediaItem(
            id: 'download-1', title: 'İndirilen', extras: {'localPath': path}));
    await player
        .setAudioSources([local, download(), player.sequence[2], download()]);
    await player.play();
    player.at = const Duration(seconds: 20);
    await music.removeDownloadedTrackFromQueue(path);
    expect(music.queueItems.map((item) => item.id), ['2', '3']);
    expect(player.playing, true);
    expect(player.position, const Duration(seconds: 20));
    final prefs = await SharedPreferences.getInstance();
    final checkpoint =
        PlaybackCheckpoint.decode(prefs.getString(PlaybackCheckpoint.key))!;
    expect(checkpoint.entries.map((entry) => entry.item.id), ['2', '3']);
  });

  test('deleting the current download pauses and leaves the next track ready',
      () async {
    const path = '/downloads/current.ogg';
    final next = player.sequence[2];
    await player.setAudioSources([
      AudioSource.uri(Uri.file(path),
          tag: const MediaItem(
              id: 'download-1',
              title: 'İndirilen',
              extras: {'localPath': path})),
      next,
    ]);
    await player.play();
    await music.removeDownloadedTrackFromQueue(path);
    expect(player.playing, false);
    expect(music.currentMediaItem?.id, '3');
    await music.togglePlayPause();
    expect(player.playing, true);
    await music.removeDownloadedTrackFromQueue(path);
    expect(music.queueItems.single.id, '3');
  });

  test('playlist pins follow rename, delete and both old and new backups',
      () async {
    await music.createPlaylist('Yol');
    await music.createPlaylist('Gece');
    await music.togglePlaylistPin('Gece');
    expect(music.orderedPlaylistNames, ['Gece', 'Yol']);
    await music.renamePlaylist('Gece', 'Akşam');
    expect(music.pinnedPlaylistNames, ['Akşam']);
    await music.restoreLibraryPreferences({
      'playlists': {
        'Akşam': [1],
        'Yeni': [3]
      }
    });
    expect(music.pinnedPlaylistNames, ['Akşam']);
    await music.restoreLibraryPreferences({
      'playlists': {
        'Yeni': [3]
      },
      'pinnedPlaylists': ['Yeni', 'Silinmiş'],
    });
    expect(music.pinnedPlaylistNames, ['Yeni']);
    await music.deletePlaylist('Yeni');
    expect(music.pinnedPlaylistNames, isEmpty);
  });
  test(
      'playlist reorder skips missing device files without moving the wrong song',
      () async {
    await music.createPlaylist('Yol');
    await music.addSongsToPlaylist('Yol', music.songs);
    music.songs.removeAt(1);
    await music.movePlaylistSong('Yol', 0, 2);
    expect(music.playlistSongs('Yol').map((s) => s.id), [3, 4, 1]);
    await music.addSongsToPlaylist('Yol', music.songs);
    expect(music.playlists['Yol']!.length, 4);
  });
}
