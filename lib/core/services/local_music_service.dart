import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_audio_handler.dart';
import 'wikimedia_music_service.dart';

class LocalMusicService extends ChangeNotifier {
  LocalMusicService._();

  static final LocalMusicService instance = LocalMusicService._();

  static const String _favoritesKey = 'b_music02_local_favorites';
  static const String _playlistsKey = 'b_music02_local_playlists_v1';

  final OnAudioQuery audioQuery = OnAudioQuery();

  late final AudioPlayer player;

  final Set<int> favoriteIds = <int>{};
  final Map<String, List<int>> _playlists = <String, List<int>>{};

  List<SongModel> songs = <SongModel>[];
  List<SongModel> _queueSongs = <SongModel>[];

  bool hasPermission = false;
  bool isLoading = false;

  late final AudioHandler _audioHandler;
  late final LocalAudioHandler _localAudioHandler;

  bool _preferencesLoaded = false;
  bool _playerCreated = false;
  bool _initialized = false;

  Future<bool>? _loadingFuture;
  Future<void> _queueOperation = Future<void>.value();

  String? playbackError;

  List<SongModel> get queueSongs {
    return List<SongModel>.unmodifiable(_queueSongs);
  }

  Map<String, List<int>> get playlists {
    return Map<String, List<int>>.unmodifiable(
      _playlists.map(
        (String key, List<int> value) {
          return MapEntry<String, List<int>>(
            key,
            List<int>.unmodifiable(value),
          );
        },
      ),
    );
  }

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

    final AudioSession session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration.music(),
    );

    player.errorStream.listen((PlayerException error) {
      playbackError =
          'Bu dosya oynatılamadı. Dosya silinmiş veya desteklenmiyor olabilir.';
      notifyListeners();
    });

    await _loadPreferences();

    player.loopModeStream.listen((LoopMode mode) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('b_music02_repeat', mode.index);
    });

    player.shuffleModeEnabledStream.listen((bool enabled) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('b_music02_shuffle', enabled);
    });

    _initialized = true;
  }

  LocalAudioHandler createHandler() {
    final LocalAudioHandler handler = LocalAudioHandler(
      player,
      loadArtwork: (MediaItem item) async {
        final int? id = int.tryParse(item.id);
        if (id == null) {
          return null;
        }

        SongModel? song;
        for (final SongModel itemSong in songs) {
          if (itemSong.id == id) {
            song = itemSong;
            break;
          }
        }

        if (song == null) {
          for (final SongModel itemSong in _queueSongs) {
            if (itemSong.id == id) {
              song = itemSong;
              break;
            }
          }
        }

        if (song == null) {
          return null;
        }

        return _artUri(song);
      },
    );
    _localAudioHandler = handler;
    return handler;
  }

  void attachAudioHandler(AudioHandler handler) {
    _audioHandler = handler;
  }

  Future<void> _loadPreferences() async {
    if (_preferencesLoaded) {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<String> storedFavorites =
        prefs.getStringList(_favoritesKey) ?? <String>[];

    favoriteIds.addAll(
      storedFavorites.map<int?>(int.tryParse).whereType<int>(),
    );

    try {
      final dynamic decoded = jsonDecode(
        prefs.getString(_playlistsKey) ?? '{}',
      );

      if (decoded is Map) {
        for (final MapEntry<dynamic, dynamic> entry in decoded.entries) {
          final dynamic key = entry.key;
          final dynamic value = entry.value;

          if (key is String && value is List) {
            _playlists[key] = value.whereType<int>().toSet().toList();
          }
        }
      }
    } on FormatException {
      // Bozuk kayıt varsa uygulama çalışmaya devam eder.
    }

    int repeat = prefs.getInt('b_music02_repeat') ?? 0;
    if (repeat < 0 || repeat >= LoopMode.values.length) {
      repeat = 0;
    }

    await player.setLoopMode(LoopMode.values[repeat]);
    await player.setShuffleModeEnabled(
      prefs.getBool('b_music02_shuffle') ?? false,
    );

    _preferencesLoaded = true;
  }

  Future<bool> requestPermissionAndLoad({bool request = true}) {
    final Future<bool>? current = _loadingFuture;
    if (current != null) {
      return current;
    }

    final Future<bool> future = _load(request);
    _loadingFuture = future;
    future.whenComplete(() {
      _loadingFuture = null;
    });
    return future;
  }

  Future<bool> _load(bool request) async {
    isLoading = true;

    try {
      await _loadPreferences();

      if (!Platform.isAndroid && !Platform.isIOS) {
        return false;
      }

      hasPermission = await audioQuery.permissionsStatus();

      if (!hasPermission && request) {
        hasPermission = await audioQuery.permissionsRequest();
      }

      if (!hasPermission) {
        songs = <SongModel>[];
        await stop();
        return false;
      }

      final List<SongModel> result = await audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      songs = result.where((SongModel song) {
        return song.uri?.isNotEmpty == true &&
            song.isAlarm != true &&
            song.isNotification != true &&
            song.isRingtone != true;
      }).toList();

      return true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await requestPermissionAndLoad(request: false);
  }

  Future<Uri?> _artUri(SongModel song) async {
    try {
      final Directory temp = await getTemporaryDirectory();
      final Directory directory = Directory(temp.path + '/local_covers');
      await directory.create(recursive: true);

      final File file = File(
        directory.path +
            '/' +
            song.id.toString() +
            '_' +
            (song.dateModified ?? 0).toString() +
            '.jpg',
      );

      if (!await file.exists()) {
        final Uint8List? bytes = await audioQuery.queryArtwork(
          song.id,
          ArtworkType.AUDIO,
          size: 512,
        );

        if (bytes == null || bytes.isEmpty) {
          return null;
        }

        await file.writeAsBytes(bytes, flush: true);
      }

      return file.uri;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      PermissionStatus status = await Permission.notification.status;
      if (status.isDenied) {
        status = await Permission.notification.request();
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        playbackError =
            'Bildirim izni kapalı. B_music02 medya kontrolünü gösterebilmek için uygulama bildirimlerini Ayarlar’dan açın.';
        notifyListeners();
      }
    } catch (_) {
      // İzin sorgusu başarısız olsa da oynatmayı engelleme.
    }
  }

  Future<void> playSong(
    SongModel song, {
    List<SongModel>? from,
  }) {
    final List<SongModel> selection = List<SongModel>.of(from ?? songs);

    final Future<void> operation = _queueOperation.then((_) {
      return _playSelection(song, selection);
    });

    _queueOperation = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _playSelection(
    SongModel song,
    List<SongModel> selection,
  ) async {
    final int index = selection.indexWhere(
      (SongModel item) => item.id == song.id,
    );

    if (index < 0) {
      return;
    }

    playbackError = null;

    final bool sameQueue = listEquals<int>(
      selection.map<int>((SongModel item) => item.id).toList(),
      _queueSongs.map<int>((SongModel item) => item.id).toList(),
    );

    if (!sameQueue || player.audioSource == null) {
      final Uri? selectedArtwork = await _artUri(song);

      final List<AudioSource> sources = selection.map<AudioSource>(
        (SongModel item) {
          return AudioSource.uri(
            Uri.parse(item.uri!),
            tag: MediaItem(
              id: item.id.toString(),
              title: item.title,
              artist: _known(item.artist, 'Bilinmeyen sanatçı'),
              album: _known(item.album, 'B_music02'),
              duration: item.duration == null
                  ? null
                  : Duration(milliseconds: item.duration!),
              artUri: item.id == song.id ? selectedArtwork : null,
            ),
          );
        },
      ).toList();

      await player.pause();
      _queueSongs = List<SongModel>.of(selection);

      try {
        await player.setAudioSources(
          sources,
          initialIndex: index,
          initialPosition: Duration.zero,
        );
      } catch (_) {
        _queueSongs = <SongModel>[];
        await player.stop();
        notifyListeners();
        rethrow;
      }
    } else {
      await player.seek(Duration.zero, index: index);
    }

    _localAudioHandler.publishCurrentMediaItem();
    await _ensureNotificationPermission();

    notifyListeners();
    _startPlaying();
  }

  void _startPlaying() {
    unawaited(
      _audioHandler.play().catchError((Object error) {
        playbackError =
            'Müzik açılamadı. Dosyayı ve erişim iznini kontrol edin.';
        notifyListeners();
      }),
    );
  }

  String? get currentDownloadPath {
    final Object? tag = player.sequenceState.currentSource?.tag;
    return tag is MediaItem ? tag.extras?['localPath'] as String? : null;
  }

  Future<void> pause() => _audioHandler.pause();

  // Downloads and MediaStore songs must use the same player and MediaSession.
  Future<void> playDownload(
    DownloadedCommonsTrack track, {
    required List<DownloadedCommonsTrack> from,
  }) {
    final selection = List<DownloadedCommonsTrack>.of(from);
    final operation = _queueOperation.then((_) async {
      if (currentDownloadPath == track.localPath) {
        await togglePlayPause();
        return;
      }
      final index = selection.indexWhere((item) => item.localPath == track.localPath);
      if (index < 0) return;
      playbackError = null;
      await player.pause();
      _queueSongs = <SongModel>[];
      try {
        await player.setAudioSources(
          selection.map((item) => AudioSource.uri(
            Uri.file(item.localPath),
            tag: MediaItem(
              id: Uri.file(item.localPath).toString(),
              title: item.title,
              artist: _known(item.artist, 'Bilinmeyen sanatçı'),
              album: 'İndirilen müzikler',
              extras: <String, dynamic>{'localPath': item.localPath},
            ),
          )).toList(),
          initialIndex: index,
          initialPosition: Duration.zero,
        );
        _localAudioHandler.publishCurrentMediaItem();
        await _ensureNotificationPermission();
        _startPlaying();
      } catch (_) {
        await _audioHandler.stop();
        rethrow;
      } finally {
        notifyListeners();
      }
    });
    _queueOperation = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= songs.length) {
      return;
    }
    await playSong(songs[index]);
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      await _audioHandler.pause();
      return;
    }

    if (player.audioSource == null) {
      if (songs.isNotEmpty) {
        await playIndex(0);
      }
      return;
    }

    if (player.processingState == ProcessingState.completed) {
      final int index = player.effectiveIndices.isEmpty
          ? 0
          : player.effectiveIndices.first;
      await player.seek(Duration.zero, index: index);
    }

    _startPlaying();
  }

  Future<void> next() async {
    if (!player.hasNext) {
      return;
    }
    await player.seekToNext();
    _startPlaying();
  }

  Future<void> previous() async {
    if (player.position.inSeconds > 5 || !player.hasPrevious) {
      await player.seek(Duration.zero);
      return;
    }
    await player.seekToPrevious();
    _startPlaying();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> toggleShuffle() async {
    final bool enable = !player.shuffleModeEnabled;
    if (enable) {
      await player.shuffle();
    }
    await player.setShuffleModeEnabled(enable);
  }

  Future<void> cycleRepeatMode() async {
    switch (player.loopMode) {
      case LoopMode.off:
        await player.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await player.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await player.setLoopMode(LoopMode.off);
        break;
    }
  }

  bool isFavorite(SongModel song) {
    return favoriteIds.contains(song.id);
  }

  Future<bool> toggleFavorite(SongModel song) async {
    await _loadPreferences();

    if (favoriteIds.contains(song.id)) {
      favoriteIds.remove(song.id);
    } else {
      favoriteIds.add(song.id);
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesKey,
      favoriteIds.map<String>((int id) => id.toString()).toList(),
    );

    notifyListeners();
    return isFavorite(song);
  }

  List<SongModel> get favoriteSongs {
    return songs.where(isFavorite).toList();
  }

  List<SongModel> playlistSongs(String name) {
    final Map<int, SongModel> byId = <int, SongModel>{
      for (final SongModel song in songs) song.id: song,
    };

    final List<int> ids = _playlists[name] ?? <int>[];
    return ids
        .map<SongModel?>((int id) => byId[id])
        .whereType<SongModel>()
        .toList();
  }

  Future<void> createPlaylist(String name) async {
    final String cleanName = name.trim();
    if (cleanName.isEmpty || _playlists.containsKey(cleanName)) {
      throw ArgumentError('Farklı ve boş olmayan bir liste adı girin.');
    }
    _playlists[cleanName] = <int>[];
    await _savePlaylists();
  }

  Future<void> renamePlaylist(String oldName, String newName) async {
    final String cleanName = newName.trim();
    if (oldName == cleanName) {
      return;
    }
    if (cleanName.isEmpty || _playlists.containsKey(cleanName)) {
      throw ArgumentError('Farklı ve boş olmayan bir liste adı girin.');
    }

    final List<int>? ids = _playlists.remove(oldName);
    if (ids != null) {
      _playlists[cleanName] = ids;
    }
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String name) async {
    _playlists.remove(name);
    await _savePlaylists();
  }

  Future<void> addToPlaylist(String name, SongModel song) async {
    final List<int>? ids = _playlists[name];
    if (ids == null) {
      return;
    }
    if (!ids.contains(song.id)) {
      ids.add(song.id);
    }
    await _savePlaylists();
  }

  Future<void> removeFromPlaylist(String name, SongModel song) async {
    _playlists[name]?.remove(song.id);
    await _savePlaylists();
  }

  Future<void> _savePlaylists() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistsKey, jsonEncode(_playlists));
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_playerCreated) {
      return;
    }
    await _audioHandler.stop();
  }

  String _known(String? value, String fallback) {
    if (value == null || value.trim().isEmpty || value == '<unknown>') {
      return fallback;
    }
    return value;
  }
}
