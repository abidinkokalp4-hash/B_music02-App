import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

class LocalMusicService {
  LocalMusicService._();

  static final LocalMusicService instance =
      LocalMusicService._();

  final OnAudioQuery audioQuery =
      OnAudioQuery();

  final AudioPlayer player =
      AudioPlayer(
    maxSkipsOnError: 3,
  );

  List<SongModel> songs = [];

  bool hasPermission = false;
  bool isLoading = false;
  bool _playlistReady = false;

  Future<bool> requestPermissionAndLoad() async {
    if (isLoading) {
      return hasPermission;
    }

    isLoading = true;

    try {
      hasPermission =
          await audioQuery.checkAndRequest(
        retryRequest: true,
      );

      if (!hasPermission) {
        songs = [];
        _playlistReady = false;
        return false;
      }

      final result =
          await audioQuery.querySongs(
        sortType:
            SongSortType.TITLE,
        orderType:
            OrderType.ASC_OR_SMALLER,
        uriType:
            UriType.EXTERNAL,
        ignoreCase: true,
      );

      songs = result.where(
        (song) {
          final uri =
              song.uri;

          if (uri == null ||
              uri.trim().isEmpty) {
            return false;
          }

          // Bildirim, alarm ve zil seslerini
          // mümkün olduğunca müzik listesinden çıkar.
          if (song.isAlarm == true) {
            return false;
          }

          if (song.isNotification ==
              true) {
            return false;
          }

          if (song.isRingtone == true) {
            return false;
          }

          return true;
        },
      ).toList();

      _playlistReady = false;

      return true;
    } finally {
      isLoading = false;
    }
  }

  Future<void> refresh() async {
    if (!hasPermission) {
      await requestPermissionAndLoad();
      return;
    }

    final result =
        await audioQuery.querySongs(
      sortType:
          SongSortType.TITLE,
      orderType:
          OrderType.ASC_OR_SMALLER,
      uriType:
          UriType.EXTERNAL,
      ignoreCase: true,
    );

    songs = result.where(
      (song) {
        final uri =
            song.uri;

        if (uri == null ||
            uri.trim().isEmpty) {
          return false;
        }

        if (song.isAlarm == true ||
            song.isNotification == true ||
            song.isRingtone == true) {
          return false;
        }

        return true;
      },
    ).toList();

    _playlistReady = false;
  }

  List<AudioSource> _buildSources() {
    return songs.map(
      (song) {
        final uri =
            Uri.parse(
          song.uri!,
        );

        return AudioSource.uri(
          uri,
          tag: MediaItem(
            id:
                song.id.toString(),
            title:
                song.title,
            artist:
                _artistName(song),
            album:
                _albumName(song),
          ),
        );
      },
    ).toList();
  }

  Future<void> _preparePlaylist({
    int initialIndex = 0,
  }) async {
    if (songs.isEmpty) {
      return;
    }

    final safeIndex =
        initialIndex.clamp(
      0,
      songs.length - 1,
    );

    await player.setAudioSources(
      _buildSources(),
      initialIndex:
          safeIndex,
      initialPosition:
          Duration.zero,
      preload: true,
    );

    _playlistReady = true;
  }

  Future<void> playSong(
    SongModel song,
  ) async {
    final index =
        songs.indexWhere(
      (item) =>
          item.id == song.id,
    );

    if (index < 0) {
      return;
    }

    await playIndex(index);
  }

  Future<void> playIndex(
    int index,
  ) async {
    if (songs.isEmpty) {
      return;
    }

    final safeIndex =
        index.clamp(
      0,
      songs.length - 1,
    );

    if (!_playlistReady) {
      await _preparePlaylist(
        initialIndex:
            safeIndex,
      );
    } else {
      await player.seek(
        Duration.zero,
        index:
            safeIndex,
      );
    }

    await player.play();
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      await player.pause();
      return;
    }

    if (player.audioSource == null) {
      if (songs.isNotEmpty) {
        await playIndex(0);
      }

      return;
    }

    await player.play();
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
      await player.play();
    }
  }

  Future<void> previous() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
      await player.play();
    }
  }

  Future<void> stop() async {
    await player.stop();
  }

  String _artistName(
    SongModel song,
  ) {
    final artist =
        song.artist?.trim();

    if (artist == null ||
        artist.isEmpty ||
        artist ==
            '<unknown>') {
      return 'Bilinmeyen sanatçı';
    }

    return artist;
  }

  String _albumName(
    SongModel song,
  ) {
    final album =
        song.album?.trim();

    if (album == null ||
        album.isEmpty ||
        album ==
            '<unknown>') {
      return 'B_music02';
    }

    return album;
  }
}
