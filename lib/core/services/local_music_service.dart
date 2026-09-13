import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalMusicService {
  LocalMusicService._();

  static final LocalMusicService instance =
      LocalMusicService._();

  static const String _favoritesKey =
      'b_music02_local_favorites';

  final OnAudioQuery audioQuery =
      OnAudioQuery();

  final AudioPlayer player = AudioPlayer(
    maxSkipsOnError: 3,
  );

  List<SongModel> songs = [];

  final Set<int> favoriteIds = {};

  bool hasPermission = false;
  bool isLoading = false;
  bool _playlistReady = false;
  bool _preferencesLoaded = false;

  Future<void> _loadPreferences() async {
    if (_preferencesLoaded) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    final saved =
        prefs.getStringList(
              _favoritesKey,
            ) ??
            [];

    favoriteIds
      ..clear()
      ..addAll(
        saved
            .map(
              int.tryParse,
            )
            .whereType<int>(),
      );

    _preferencesLoaded = true;
  }

  Future<bool>
      requestPermissionAndLoad() async {
    if (isLoading) {
      return hasPermission;
    }

    isLoading = true;

    try {
      await _loadPreferences();

      hasPermission =
          await audioQuery.checkAndRequest(
        retryRequest: true,
      );

      if (!hasPermission) {
        songs = [];
        _playlistReady = false;
        return false;
      }

      await _querySongs();

      return true;
    } finally {
      isLoading = false;
    }
  }

  Future<void> _querySongs() async {
    final result =
        await audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    songs = result.where(
      (song) {
        final uri = song.uri;

        if (uri == null ||
            uri.trim().isEmpty) {
          return false;
        }

        if (song.isAlarm == true) {
          return false;
        }

        if (song.isNotification == true) {
          return false;
        }

        if (song.isRingtone == true) {
          return false;
        }

        return true;
      },
    ).toList();

    _playlistReady = false;
  }

  Future<void> refresh() async {
    if (!hasPermission) {
      await requestPermissionAndLoad();
      return;
    }

    await _querySongs();
  }

  Uri? _artUri(
    SongModel song,
  ) {
    final albumId =
        song.albumId;

    if (albumId == null ||
        albumId <= 0) {
      return null;
    }

    return Uri.parse(
      'content://media/external/audio/albumart/$albumId',
    );
  }

  List<AudioSource> _buildSources() {
    return songs.map(
      (song) {
        final audioUri =
            Uri.parse(
          song.uri!,
        );

        return AudioSource.uri(
          audioUri,
          tag: MediaItem(
            id:
                song.id.toString(),
            title:
                song.title,
            artist:
                _artistName(
              song,
            ),
            album:
                _albumName(
              song,
            ),
            duration:
                song.duration == null
                    ? null
                    : Duration(
                        milliseconds:
                            song.duration!,
                      ),
            artUri:
                _artUri(
              song,
            ),
            playable:
                true,
            displayTitle:
                song.title,
            displaySubtitle:
                _artistName(
              song,
            ),
            displayDescription:
                _albumName(
              song,
            ),
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
      preload:
          true,
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

    await playIndex(
      index,
    );
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
        await playIndex(
          0,
        );
      }

      return;
    }

    await player.play();
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
      await player.play();
      return;
    }

    if (player.loopMode ==
            LoopMode.all &&
        songs.isNotEmpty) {
      await player.seek(
        Duration.zero,
        index:
            0,
      );

      await player.play();
    }
  }

  Future<void> previous() async {
    final position =
        player.position;

    if (position >
        const Duration(
          seconds: 5,
        )) {
      await player.seek(
        Duration.zero,
      );

      return;
    }

    if (player.hasPrevious) {
      await player.seekToPrevious();
      await player.play();
      return;
    }

    await player.seek(
      Duration.zero,
    );
  }

  Future<void> seek(
    Duration position,
  ) async {
    await player.seek(
      position,
    );
  }

  Future<void> toggleShuffle() async {
    final enable =
        !player.shuffleModeEnabled;

    if (enable) {
      await player.shuffle();
    }

    await player.setShuffleModeEnabled(
      enable,
    );
  }

  Future<void> cycleRepeatMode() async {
    switch (player.loopMode) {
      case LoopMode.off:
        await player.setLoopMode(
          LoopMode.all,
        );
        break;

      case LoopMode.all:
        await player.setLoopMode(
          LoopMode.one,
        );
        break;

      case LoopMode.one:
        await player.setLoopMode(
          LoopMode.off,
        );
        break;
    }
  }

  bool isFavorite(
    SongModel song,
  ) {
    return favoriteIds.contains(
      song.id,
    );
  }

  Future<bool> toggleFavorite(
    SongModel song,
  ) async {
    await _loadPreferences();

    if (favoriteIds.contains(
      song.id,
    )) {
      favoriteIds.remove(
        song.id,
      );
    } else {
      favoriteIds.add(
        song.id,
      );
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setStringList(
      _favoritesKey,
      favoriteIds
          .map(
            (id) =>
                id.toString(),
          )
          .toList(),
    );

    return favoriteIds.contains(
      song.id,
    );
  }

  List<SongModel> get favoriteSongs {
    return songs
        .where(
          (song) =>
              favoriteIds.contains(
            song.id,
          ),
        )
        .toList();
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
        artist == '<unknown>') {
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
        album == '<unknown>') {
      return 'B_music02';
    }

    return album;
  }
}
