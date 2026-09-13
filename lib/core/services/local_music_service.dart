import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalMusicService extends ChangeNotifier {
  LocalMusicService._();

  static final LocalMusicService instance =
      LocalMusicService._();

  static const _favoritesKey =
      'b_music02_local_favorites';

  static const _playlistsKey =
      'b_music02_local_playlists_v1';

  final OnAudioQuery audioQuery =
      OnAudioQuery();

  late final AudioPlayer player;

  final Set<int> favoriteIds = {};

  final Map<String, List<int>>
      _playlists = {};

  List<SongModel> songs = [];

  List<SongModel> _queueSongs = [];

  List<SongModel> get queueSongs =>
      List.unmodifiable(
        _queueSongs,
      );

  Map<String, List<int>>
      get playlists =>
          Map.unmodifiable(
            _playlists.map(
              (
                key,
                value,
              ) =>
                  MapEntry(
                key,
                List<int>.unmodifiable(
                  value,
                ),
              ),
            ),
          );

  bool hasPermission = false;

  bool isLoading = false;

  bool _preferencesLoaded = false;

  bool _playerCreated = false;

  bool _initialized = false;

  Future<bool>? _loadingFuture;

  Future<void> _queueOperation =
      Future.value();

  String? playbackError;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (!_playerCreated) {
      player = AudioPlayer(
        maxSkipsOnError: 3,
      );

      _playerCreated = true;
    }

    final session =
        await AudioSession.instance;

    await session.configure(
      const AudioSessionConfiguration.music(),
    );

    player.errorStream.listen(
      (error) {
        playbackError =
            'Bu dosya oynatılamadı. Dosya silinmiş veya desteklenmiyor olabilir.';

        notifyListeners();
      },
    );

    await _loadPreferences();

    player.loopModeStream.listen(
      (mode) async {
        final prefs =
            await SharedPreferences
                .getInstance();

        await prefs.setInt(
          'b_music02_repeat',
          mode.index,
        );
      },
    );

    player.shuffleModeEnabledStream.listen(
      (enabled) async {
        final prefs =
            await SharedPreferences
                .getInstance();

        await prefs.setBool(
          'b_music02_shuffle',
          enabled,
        );
      },
    );

    _initialized = true;
  }

  Future<void>
      _loadPreferences() async {
    if (_preferencesLoaded) {
      return;
    }

    final prefs =
        await SharedPreferences
            .getInstance();

    favoriteIds.addAll(
      (
        prefs.getStringList(
              _favoritesKey,
            ) ??
            [],
      )
          .map(
            int.tryParse,
          )
          .whereType<int>(),
    );

    try {
      final decoded =
          jsonDecode(
        prefs.getString(
              _playlistsKey,
            ) ??
            '{}',
      );

      if (decoded is Map) {
        for (final entry
            in decoded.entries) {
          if (entry.key is String &&
              entry.value is List) {
            _playlists[
                    entry.key as String] =
                (
              entry.value as List,
            )
                    .whereType<int>()
                    .toSet()
                    .toList();
          }
        }
      }
    } on FormatException {
      // Bozuk kayıt varsa uygulama çalışmaya devam eder.
    }

    final repeat =
        prefs.getInt(
              'b_music02_repeat',
            ) ??
            0;

    await player.setLoopMode(
      LoopMode.values[
          repeat.clamp(
        0,
        2,
      )],
    );

    await player
        .setShuffleModeEnabled(
      prefs.getBool(
            'b_music02_shuffle',
          ) ??
          false,
    );

    _preferencesLoaded = true;
  }

  Future<bool>
      requestPermissionAndLoad({
    bool request = true,
  }) {
    return _loadingFuture ??=
        _load(
          request,
        ).whenComplete(
          () {
            _loadingFuture =
                null;
          },
        );
  }

  Future<bool> _load(
    bool request,
  ) async {
    isLoading = true;

    try {
      await _loadPreferences();

      if (!Platform.isAndroid &&
          !Platform.isIOS) {
        return false;
      }

      hasPermission =
          await audioQuery
              .permissionsStatus();

      if (!hasPermission &&
          request) {
        hasPermission =
            await audioQuery
                .permissionsRequest();
      }

      if (!hasPermission) {
        songs = [];

        await stop();

        return false;
      }

      final result =
          await audioQuery
              .querySongs(
        sortType:
            SongSortType.TITLE,
        orderType:
            OrderType
                .ASC_OR_SMALLER,
        uriType:
            UriType.EXTERNAL,
        ignoreCase: true,
      );

      songs = result
          .where(
            (song) =>
                song.uri
                    ?.isNotEmpty ==
                true &&
                song.isAlarm !=
                    true &&
                song.isNotification !=
                    true &&
                song.isRingtone !=
                    true,
          )
          .toList();

      return true;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await requestPermissionAndLoad(
      request: false,
    );
  }

  Future<Uri?> _artUri(
    SongModel song,
  ) async {
    try {
      final directory =
          Directory(
        '${(await getTemporaryDirectory()).path}/local_covers',
      );

      await directory.create(
        recursive: true,
      );

      final file =
          File(
        '${directory.path}/${song.id}_${song.dateModified ?? 0}.jpg',
      );

      if (!await file.exists()) {
        final bytes =
            await audioQuery
                .queryArtwork(
          song.id,
          ArtworkType.AUDIO,
          size: 512,
        );

        if (bytes == null ||
            bytes.isEmpty) {
          return null;
        }

        await file.writeAsBytes(
          bytes,
          flush: true,
        );
      }

      return file.uri;
    } catch (_) {
      return null;
    }
  }

  Future<void> playSong(
    SongModel song, {
    List<SongModel>? from,
  }) {
    final selection =
        List<SongModel>.of(
      from ?? songs,
    );

    final operation =
        _queueOperation.then(
      (_) => _playSelection(
        song,
        selection,
      ),
    );

    _queueOperation =
        operation.catchError(
      (Object _) {},
    );

    return operation;
  }

  Future<void> _playSelection(
    SongModel song,
    List<SongModel> selection,
  ) async {
    final index =
        selection.indexWhere(
      (item) =>
          item.id == song.id,
    );

    if (index < 0) {
      return;
    }

    playbackError = null;

    final sameQueue =
        listEquals(
      selection
          .map(
            (song) =>
                song.id,
          )
          .toList(),
      _queueSongs
          .map(
            (song) =>
                song.id,
          )
          .toList(),
    );

    if (!sameQueue ||
        player.audioSource ==
            null) {
      final selectedArtwork =
          await _artUri(
        song,
      );

      final sources =
          selection.map(
        (item) {
          return AudioSource.uri(
            Uri.parse(
              item.uri!,
            ),
            tag: MediaItem(
              id: item.id
                  .toString(),
              title:
                  item.title,
              artist:
                  _known(
                item.artist,
                'Bilinmeyen sanatçı',
              ),
              album:
                  _known(
                item.album,
                'B_music02',
              ),
              duration:
                  item.duration ==
                          null
                      ? null
                      : Duration(
                          milliseconds:
                              item.duration!,
                        ),
              artUri:
                  item.id ==
                          song.id
                      ? selectedArtwork
                      : null,
            ),
          );
        },
      ).toList();

      await player.pause();

      _queueSongs =
          selection;

      try {
        await player
            .setAudioSources(
          sources,
          initialIndex:
              index,
          initialPosition:
              Duration.zero,
        );
      } catch (_) {
        _queueSongs = [];

        await player.stop();

        notifyListeners();

        rethrow;
      }
    } else {
      await player.seek(
        Duration.zero,
        index: index,
      );
    }

    notifyListeners();

    _startPlaying();
  }

  void _startPlaying() {
    unawaited(
      player.play().catchError(
        (Object error) {
          playbackError =
              'Müzik açılamadı. Dosyayı ve erişim iznini kontrol edin.';

          notifyListeners();
        },
      ),
    );
  }

  Future<void> playIndex(
    int index,
  ) async {
    if (index >= 0 &&
        index < songs.length) {
      await playSong(
        songs[index],
      );
    }
  }

  Future<void>
      togglePlayPause() async {
    if (player.playing) {
      await player.pause();

      return;
    }

    if (player.audioSource ==
        null) {
      await playIndex(
        0,
      );

      return;
    }

    if (player
            .processingState ==
        ProcessingState
            .completed) {
      await player.seek(
        Duration.zero,
        index:
            player
                    .effectiveIndices
                    .isEmpty
                ? 0
                : player
                    .effectiveIndices
                    .first,
      );
    }

    _startPlaying();
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player
          .seekToNext();

      _startPlaying();
    }
  }

  Future<void>
      previous() async {
    if (player.position
                .inSeconds >
            5 ||
        !player.hasPrevious) {
      await player.seek(
        Duration.zero,
      );
    } else {
      await player
          .seekToPrevious();

      _startPlaying();
    }
  }

  Future<void> seek(
    Duration position,
  ) =>
      player.seek(
        position,
      );

  Future<void>
      toggleShuffle() async {
    final enable =
        !player
            .shuffleModeEnabled;

    if (enable) {
      await player.shuffle();
    }

    await player
        .setShuffleModeEnabled(
      enable,
    );
  }

  Future<void>
      cycleRepeatMode() {
    return player
        .setLoopMode(
      switch (
          player.loopMode) {
        LoopMode.off =>
          LoopMode.all,
        LoopMode.all =>
          LoopMode.one,
        LoopMode.one =>
          LoopMode.off,
      },
    );
  }

  bool isFavorite(
    SongModel song,
  ) =>
      favoriteIds.contains(
        song.id,
      );

  Future<bool>
      toggleFavorite(
    SongModel song,
  ) async {
    await _loadPreferences();

    if (!favoriteIds.remove(
      song.id,
    )) {
      favoriteIds.add(
        song.id,
      );
    }

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setStringList(
      _favoritesKey,
      favoriteIds
          .map(
            (id) =>
                '$id',
          )
          .toList(),
    );

    notifyListeners();

    return isFavorite(
      song,
    );
  }

  List<SongModel>
      get favoriteSongs =>
          songs
              .where(
                isFavorite,
              )
              .toList();

  List<SongModel>
      playlistSongs(
    String name,
  ) {
    final byId = {
      for (final song in songs)
        song.id: song,
    };

    return (
      _playlists[name] ??
          [],
    )
        .map(
          (id) =>
              byId[id],
        )
        .whereType<
            SongModel>()
        .toList();
  }

  Future<void>
      createPlaylist(
    String name,
  ) async {
    name = name.trim();

    if (name.isEmpty ||
        _playlists
            .containsKey(
          name,
        )) {
      throw ArgumentError(
        'Farklı ve boş olmayan bir liste adı girin.',
      );
    }

    _playlists[name] = [];

    await _savePlaylists();
  }

  Future<void>
      renamePlaylist(
    String oldName,
    String newName,
  ) async {
    newName =
        newName.trim();

    if (oldName ==
        newName) {
      return;
    }

    if (newName.isEmpty ||
        _playlists
            .containsKey(
          newName,
        )) {
      throw ArgumentError(
        'Farklı ve boş olmayan bir liste adı girin.',
      );
    }

    final ids =
        _playlists.remove(
      oldName,
    );

    if (ids != null) {
      _playlists[newName] =
          ids;
    }

    await _savePlaylists();
  }

  Future<void>
      deletePlaylist(
    String name,
  ) async {
    _playlists.remove(
      name,
    );

    await _savePlaylists();
  }

  Future<void>
      addToPlaylist(
    String name,
    SongModel song,
  ) async {
    final ids =
        _playlists[name];

    if (ids != null &&
        !ids.contains(
          song.id,
        )) {
      ids.add(
        song.id,
      );
    }

    await _savePlaylists();
  }

  Future<void>
      removeFromPlaylist(
    String name,
    SongModel song,
  ) async {
    _playlists[name]
        ?.remove(
      song.id,
    );

    await _savePlaylists();
  }

  Future<void>
      _savePlaylists() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      _playlistsKey,
      jsonEncode(
        _playlists,
      ),
    );

    notifyListeners();
  }

  Future<void> stop() async {
    if (!_playerCreated) {
      return;
    }

    await player.stop();
  }

  String _known(
    String? value,
    String fallback,
  ) {
    return value == null ||
            value.trim().isEmpty ||
            value ==
                '<unknown>'
        ? fallback
        : value;
  }
}
