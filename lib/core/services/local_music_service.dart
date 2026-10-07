import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_audio_handler.dart';
import 'player_preferences.dart';
import 'playback_checkpoint.dart';
import 'playlist_covers.dart';
import 'playlist_pins.dart';
import 'wikimedia_music_service.dart';

class LocalMusicService extends ChangeNotifier {
  LocalMusicService._();

  @visibleForTesting
  LocalMusicService.forTesting(AudioPlayer testPlayer) {
    player = testPlayer;
    _playerCreated = _initialized = _preferencesLoaded = true;
    createHandler();
    _audioHandler = _localAudioHandler;
  }

  static final LocalMusicService instance = LocalMusicService._();

  static const String _favoritesKey = 'b_music02_local_favorites';
  static const String _playlistsKey = 'b_music02_local_playlists_v1';

  final OnAudioQuery audioQuery = OnAudioQuery();

  late final AudioPlayer player;

  /// False until the audio player exists (e.g. settings opened in tests).
  bool get hasPlayer => _playerCreated;
  final AndroidEqualizer equalizer = AndroidEqualizer();

  final Set<int> favoriteIds = <int>{};
  final Map<String, List<int>> _playlists = <String, List<int>>{};
  final PlaylistCovers playlistCovers = PlaylistCovers();
  final PlaylistPins playlistPins = PlaylistPins();

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
  String? libraryError;
  bool _checkpointRestored = false;
  Timer? _checkpointTimer;
  Future<void> _checkpointWrite = Future<void>.value();

  MediaItem? get currentMediaItem => _localAudioHandler.mediaItem.value;
  Stream<MediaItem?> get mediaItemStream => _localAudioHandler.mediaItem;
  List<MediaItem> get queueItems => player.sequence
      .map((source) => source.tag)
      .whereType<MediaItem>()
      .toList();
  SongModel? get currentSong {
    final id = currentMediaItem?.id;
    for (final song in [...songs, ..._queueSongs]) {
      if (song.id.toString() == id) return song;
    }
    return null;
  }

  void clearPlaybackError() {
    playbackError = null;
    notifyListeners();
  }

  List<SongModel> get queueSongs {
    return List<SongModel>.unmodifiable(_queueSongs);
  }

  Map<String, List<int>> get playlists {
    return Map<String, List<int>>.unmodifiable(
      _playlists.map((String key, List<int> value) {
        return MapEntry<String, List<int>>(key, List<int>.unmodifiable(value));
      }),
    );
  }

  List<String> get pinnedPlaylistNames =>
      playlistPins.names.where(_playlists.containsKey).toList(growable: false);

  List<String> get orderedPlaylistNames => [
        ...pinnedPlaylistNames,
        ..._playlists.keys.where((name) => !playlistPins.contains(name)),
      ];

  bool isPlaylistPinned(String name) => playlistPins.contains(name);

  Future<void> togglePlaylistPin(String name) async {
    if (!_playlists.containsKey(name)) return;
    await playlistPins.toggle(name);
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (!_playerCreated) {
      player = AudioPlayer(
        maxSkipsOnError: 3,
        audioPipeline: AudioPipeline(androidAudioEffects: [equalizer]),
      );
      _playerCreated = true;
    }

    final AudioSession session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    session.becomingNoisyEventStream.listen((_) {
      if (player.playing) {
        unawaited(player.pause());
      }
    });

    // just_audio owns interruption handling so calls and audio focus stay coherent.
    session.devicesChangedEventStream.listen((event) {
      if (PlayerPreferences.instance.flag('headphones', fallback: false) &&
          event.devicesAdded.any(
            (d) =>
                d.type == AudioDeviceType.wiredHeadphones ||
                d.type == AudioDeviceType.wiredHeadset ||
                d.type == AudioDeviceType.bluetoothA2dp,
          ) &&
          player.audioSource != null &&
          !player.playing) {
        _startPlaying();
      }
    });

    player.errorStream.listen((PlayerException error) {
      playbackError =
          'Bu dosya oynatılamadı. Dosya silinmiş veya desteklenmiyor olabilir.';
      notifyListeners();
    });

    await _loadPreferences();
    await PlayerPreferences.instance.load();
    await configureDucking(PlayerPreferences.instance.flag("duck"));
    await player.setVolume(
      PlayerPreferences.instance.number("volume", 1).clamp(0, 1),
    );

    player.processingStateStream.listen((state) {
      if (state == ProcessingState.ready && Platform.isAndroid) {
        unawaited(restoreEqualizer());
      }
    });

    player.loopModeStream.listen((LoopMode mode) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('b_music02_repeat', mode.index);
    });

    player.shuffleModeEnabledStream.listen((bool enabled) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('b_music02_shuffle', enabled);
    });

    player.playerStateStream.listen((state) {
      _checkpointTimer?.cancel();
      if (state.playing && state.processingState != ProcessingState.completed) {
        _checkpointTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          unawaited(savePlaybackCheckpoint());
        });
      } else {
        unawaited(savePlaybackCheckpoint());
      }
    });
    player.sequenceStateStream.listen((_) {
      unawaited(savePlaybackCheckpoint());
      notifyListeners();
    });

    _initialized = true;
  }

  Future<void> configureDucking(bool enabled) async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration.music().copyWith(
        androidWillPauseWhenDucked: !enabled,
      ),
    );
  }

  Future<void> restoreEqualizer() async {
    try {
      final settings = PlayerPreferences.instance;
      if (!settings.flag('eqEnabled', fallback: false)) return;
      final parameters = await equalizer.parameters;
      final gains = settings.gains('eqGains');
      for (var i = 0; i < gains.length && i < parameters.bands.length; i++) {
        await parameters.bands[i].setGain(
          gains[i].clamp(parameters.minDecibels, parameters.maxDecibels),
        );
      }
      await equalizer.setEnabled(true);
    } catch (_) {
      /* Unsupported device effects must never prevent playback. */
    }
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

    await playlistCovers.load();
    await playlistPins.load(_playlists.keys);
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
    libraryError = null;

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
        // App-owned downloads do not require MediaStore permission. Returning
        // to the app must not stop a download because library access is denied.
        if (_queueSongs.isNotEmpty) {
          await stop();
          _queueSongs = <SongModel>[];
        }
        await restorePlaybackCheckpoint();
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
            song.isRingtone != true &&
            (PlayerPreferences.instance.flag('hidden', fallback: false) ||
                !song.data.split('/').any((part) => part.startsWith('.')));
      }).toList();

      await restorePlaybackCheckpoint();

      return true;
    } catch (_) {
      libraryError =
          'Müzik arşivi okunamadı. İzinleri kontrol edip yeniden tara.';
      return hasPermission;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await requestPermissionAndLoad(request: false);
  }

  Future<Uri?> _defaultArtwork() async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/b_music_default_cover_v2.png');
      if (!await file.exists()) {
        final data = await rootBundle.load('assets/images/b_music02_logo.png');
        await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
      return file.uri;
    } catch (_) { return null; }
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
          return _defaultArtwork();
        }

        await file.writeAsBytes(bytes, flush: true);
      }

      return file.uri;
    } catch (_) {
      return _defaultArtwork();
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
            'Bildirim izni kapalı. B Music medya kontrolünü gösterebilmek için uygulama bildirimlerini Ayarlar’dan açın.';
        notifyListeners();
      }
    } catch (_) {
      // İzin sorgusu başarısız olsa da oynatmayı engelleme.
    }
  }

  Future<void> playSong(SongModel song, {List<SongModel>? from}) {
    final List<SongModel> selection = List<SongModel>.of(from ?? songs);

    final Future<void> operation = _queueOperation.then((_) {
      return _playSelection(song, selection);
    });

    _queueOperation = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _playSelection(SongModel song, List<SongModel> selection) async {
    final int index = selection.indexWhere(
      (SongModel item) => item.id == song.id,
    );

    if (index < 0) {
      return;
    }

    playbackError = null;

    final bool sameQueue = listEquals<String>(
      selection.map((item) => item.id.toString()).toList(),
      queueItems.map((item) => item.id).toList(),
    );

    if (!sameQueue || player.audioSource == null) {
      final Uri? selectedArtwork = await _artUri(song);

      final List<AudioSource> sources = selection.map<AudioSource>((
        SongModel item,
      ) {
        return AudioSource.uri(
          Uri.parse(item.uri!),
          tag: MediaItem(
            id: item.id.toString(),
            title: item.title,
            artist: _known(item.artist, 'Bilinmeyen sanatçı'),
            album: _known(item.album, 'B Music'),
            duration: item.duration == null
                ? null
                : Duration(milliseconds: item.duration!),
            artUri: item.id == song.id ? selectedArtwork : null,
          ),
        );
      }).toList();

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
    if (tag is! MediaItem) return null;
    return tag.extras?['localPath'] as String?;
  }

  Future<void> pause() => _audioHandler.pause();

  Future<void> playExternal(String source, String title, {Duration position = Duration.zero}) => _serializeQueue(() async {
    final uri = Uri.tryParse(source);
    if (uri == null || (uri.hasScheme && uri.scheme != 'content' && uri.scheme != 'file')) {
      throw ArgumentError('Yalnızca yerel dosyalar açılabilir');
    }
    await player.pause();
    clearABLoop();
    _queueSongs = [];
    await player.setAudioSources([AudioSource.uri(uri.hasScheme ? uri : Uri.file(source),
      tag: MediaItem(id: source, title: title, album: 'Cihazdan açıldı', artUri: await _defaultArtwork()))], initialPosition: position);
    _localAudioHandler.publishCurrentMediaItem();
    await _ensureNotificationPermission();
    _startPlaying();
    notifyListeners();
  });

  Duration? loopA, loopB;
  StreamSubscription<Duration>? _abPosition;
  StreamSubscription<SequenceState>? _abIndex;
  bool _abSeeking = false;
  Future<void> setABLoop(Duration a, Duration b) async {
    final duration = player.duration;
    if (a < Duration.zero || b - a < const Duration(milliseconds: 500) || duration == null || b > duration) {
      throw ArgumentError('En az yarım saniyelik geçerli bir aralık seçin');
    }
    clearABLoop();
    loopA = a; loopB = b;
    final itemId = currentMediaItem?.id;
    _abIndex = player.sequenceStateStream.listen((state) {
      final tag = state.currentSource?.tag;
      if (tag is! MediaItem || tag.id != itemId) clearABLoop();
    });
    _abPosition = player.createPositionStream(minPeriod: const Duration(milliseconds: 50), maxPeriod: const Duration(milliseconds: 100)).listen((position) async {
      if (_abSeeking || !player.playing || loopA == null || loopB == null) return;
      if (position >= loopB! || position < loopA!) {
        _abSeeking = true;
        // Defer seeking until the position event has finished dispatching.
        // This also prevents a synchronous backend from recursively emitting.
        final start = loopA!;
        try {
          await Future<void>.delayed(Duration.zero);
          if (loopA == start && loopB != null) await player.seek(start);
        } finally { _abSeeking = false; }
      }
    });
    await player.seek(a);
    notifyListeners();
  }
  void clearABLoop() {
    _abPosition?.cancel(); _abIndex?.cancel();
    _abPosition = null; _abIndex = null;
    loopA = loopB = null;
    notifyListeners();
  }

  Future<void> saveQueueAsPlaylist(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || _playlists.containsKey(clean)) throw ArgumentError('Yeni bir liste adı girin');
    final ids = queueItems.map((item) => int.tryParse(item.id)).whereType<int>().toList();
    if (ids.isEmpty || ids.length != queueItems.length) throw StateError('Önce dosyaları müzik arşivine ekleyin');
    _playlists[clean] = ids.toSet().toList();
    await _savePlaylists();
  }

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
      final index = selection.indexWhere(
        (item) => item.localPath == track.localPath,
      );
      if (index < 0) return;
      playbackError = null;
      await player.pause();
      _queueSongs = <SongModel>[];
      try {
        await player.setAudioSources(
          selection
              .map(
                (item) => AudioSource.uri(
                  Uri.file(item.localPath),
                  tag: MediaItem(
                    id: Uri.file(item.localPath).toString(),
                    title: item.title,
                    artist: _known(item.artist, 'Bilinmeyen sanatçı'),
                    album: 'İndirilen müzikler',
                    extras: <String, dynamic>{'localPath': item.localPath},
                  ),
                ),
              )
              .toList(),
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
    // just_audio retains playing=true when the queue completes. The visible
    // play button must restart immediately instead of pausing on its first tap.
    if (player.playing && player.processingState != ProcessingState.completed) {
      await _audioHandler.pause();
      return;
    }

    if (player.audioSource == null || player.sequence.isEmpty) {
      if (songs.isNotEmpty) {
        await playIndex(0);
      }
      return;
    }

    if (player.processingState == ProcessingState.completed) {
      final int index =
          player.effectiveIndices.isEmpty ? 0 : player.effectiveIndices.first;
      await player.seek(Duration.zero, index: index);
    }

    await _ensureNotificationPermission();
    _startPlaying();
  }

  Future<void> next() async {
    clearABLoop();
    if (!player.hasNext) {
      return;
    }
    await player.seekToNext();
    _startPlaying();
  }

  Future<void> previous() async {
    clearABLoop();
    if (player.position.inSeconds > 5 || !player.hasPrevious) {
      await player.seek(Duration.zero);
      return;
    }
    await player.seekToPrevious();
    _startPlaying();
  }

  Future<void> seek(Duration position) async {
    final maximum = player.duration ?? const Duration(days: 1);
    await player.seek(Duration(
      milliseconds: position.inMilliseconds.clamp(0, maximum.inMilliseconds),
    ));
    await savePlaybackCheckpoint();
  }

  Future<void> seekRelative(int seconds) =>
      seek(player.position + Duration(seconds: seconds));

  Future<void> playQueueIndex(int index) => _serializeQueue(() async {
        if (index < 0 || index >= player.sequence.length) return;
        await player.seek(Duration.zero, index: index);
        await _ensureNotificationPermission();
        _startPlaying();
      });

  AudioSource _sourceForSong(SongModel song) => AudioSource.uri(
        Uri.parse(song.uri!),
        tag: MediaItem(
          id: song.id.toString(),
          title: song.title,
          artist: _known(song.artist, 'Bilinmeyen sanatçı'),
          album: _known(song.album, 'B Music'),
          duration: song.duration == null
              ? null
              : Duration(milliseconds: song.duration!),
        ),
      );

  Future<void> _serializeQueue(Future<void> Function() action) {
    final operation = _queueOperation.then((_) async {
      await action();
      _syncQueueSongs();
      await savePlaybackCheckpoint();
      notifyListeners();
    });
    _queueOperation = operation.catchError((Object _) {});
    return operation;
  }

  void _syncQueueSongs() {
    final byId = {
      for (final song in [..._queueSongs, ...songs]) song.id.toString(): song
    };
    _queueSongs =
        queueItems.map((item) => byId[item.id]).whereType<SongModel>().toList();
  }

  Future<void> enqueue(SongModel song, {bool next = false}) =>
      _serializeQueue(() async {
        if (song.uri?.isNotEmpty != true) return;
        if (player.sequence.isEmpty) {
          await player.setAudioSources([_sourceForSong(song)]);
          _queueSongs = [song];
          _localAudioHandler.publishCurrentMediaItem();
          return;
        }
        // "Play next" must mean next even when shuffle was previously enabled.
        if (next && player.shuffleModeEnabled)
          await player.setShuffleModeEnabled(false);
        final index =
            next ? (player.currentIndex ?? 0) + 1 : player.sequence.length;
        await player.insertAudioSource(index, _sourceForSong(song));
      });

  Future<void> moveQueueItem(int from, int to) => _serializeQueue(() async {
        final length = player.sequence.length;
        if (from < 0 || to < 0 || from >= length || to >= length || from == to)
          return;
        if (player.shuffleModeEnabled)
          await player.setShuffleModeEnabled(false);
        await player.moveAudioSource(from, to);
      });

  Future<void> removeQueueItem(int index) => _serializeQueue(() async {
        if (index < 0 || index >= player.sequence.length) return;
        if (player.sequence.length == 1) {
          await _audioHandler.stop();
        }
        await player.removeAudioSourceAt(index);
      });

  Future<void> removeDownloadedTrackFromQueue(String path) =>
      _serializeQueue(() async {
        final indices = <int>[];
        for (var i = 0; i < player.sequence.length; i++) {
          final source = player.sequence[i];
          final tag = source.tag;
          if ((tag is MediaItem && tag.extras?['localPath'] == path) ||
              (source is UriAudioSource && source.uri == Uri.file(path))) {
            indices.add(i);
          }
        }
        if (indices.isEmpty) return;
        if (indices.contains(player.currentIndex)) await _audioHandler.pause();
        if (indices.length == player.sequence.length)
          await _audioHandler.stop();
        for (final index in indices.reversed) {
          await player.removeAudioSourceAt(index);
        }
      });

  Future<void> clearUpcoming() => _serializeQueue(() async {
        final current = player.currentIndex;
        if (current == null) return;
        if (player.shuffleModeEnabled)
          await player.setShuffleModeEnabled(false);
        if (current + 1 < player.sequence.length) {
          await player.removeAudioSourceRange(
              current + 1, player.sequence.length);
        }
        if (current > 0) await player.removeAudioSourceRange(0, current);
      });

  Future<void> savePlaybackCheckpoint() {
    // Snapshot before awaiting: concurrent changes must not mix index and queue.
    final index = player.currentIndex;
    final entries = player.sequence
        .whereType<UriAudioSource>()
        .map((source) {
          final tag = source.tag;
          return tag is MediaItem
              ? SavedQueueEntry(uri: source.uri, item: tag)
              : null;
        })
        .whereType<SavedQueueEntry>()
        .toList();
    final checkpoint = index != null && index >= 0 && index < entries.length
        ? PlaybackCheckpoint(
            entries: entries, index: index, position: player.position)
        : null;
    if (checkpoint == null && !_checkpointRestored) return Future<void>.value();
    final operation = _checkpointWrite.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (checkpoint == null) {
        // Do not erase the saved queue while a fresh process is still starting.
        if (_checkpointRestored) await prefs.remove(PlaybackCheckpoint.key);
      } else {
        await prefs.setString(PlaybackCheckpoint.key, checkpoint.encode());
      }
    });
    _checkpointWrite = operation.catchError((Object _) {});
    return _checkpointWrite;
  }

  Future<void> restorePlaybackCheckpoint() async {
    if (_checkpointRestored || player.audioSource != null) return;
    if (!PlayerPreferences.instance.flag('resumePlayback')) {
      _checkpointRestored = true;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final checkpoint =
        PlaybackCheckpoint.decode(prefs.getString(PlaybackCheckpoint.key));
    if (checkpoint == null) {
      _checkpointRestored = true;
      return;
    }
    if (!hasPermission &&
        checkpoint.entries
            .any((entry) => entry.item.extras?['localPath'] == null)) return;
    _checkpointRestored = true;
    await _serializeQueue(() async {
      if (player.audioSource != null) return;
      final byId = {for (final song in songs) song.id.toString(): song};
      final sources = <AudioSource>[];
      var selectedIndex = 0;
      var restoredCurrent = false;
      for (var i = 0; i < checkpoint.entries.length; i++) {
        final entry = checkpoint.entries[i];
        final song = byId[entry.item.id];
        final isDownload = entry.item.extras?['localPath'] is String;
        if (song == null &&
            (!isDownload ||
                entry.uri.scheme != 'file' ||
                !await File.fromUri(entry.uri).exists())) continue;
        if (i == checkpoint.index) {
          selectedIndex = sources.length;
          restoredCurrent = true;
        }
        sources.add(song != null
            ? _sourceForSong(song)
            : AudioSource.uri(entry.uri, tag: entry.item));
      }
      if (sources.isEmpty) return;
      try {
        await player.setAudioSources(sources,
            initialIndex: selectedIndex,
            initialPosition:
                restoredCurrent ? checkpoint.position : Duration.zero);
        _localAudioHandler.publishCurrentMediaItem();
        // Restoring the queue is deliberately paused; playback needs a user tap.
      } catch (_) {
        await player.stop();
      }
    });
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
      await playlistCovers.rename(oldName, cleanName);
      await playlistPins.rename(oldName, cleanName);
    }
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String name) async {
    _playlists.remove(name);
    await playlistCovers.remove(name);
    await playlistPins.remove(name);
    await _savePlaylists();
  }

  Future<void> setPlaylistCover(String name, String sourcePath) async {
    if (!_playlists.containsKey(name)) return;
    await playlistCovers.set(name, sourcePath);
    notifyListeners();
  }

  Future<void> removePlaylistCover(String name) async {
    await playlistCovers.remove(name);
    notifyListeners();
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

  Future<void> addSongsToPlaylist(
      String name, Iterable<SongModel> selection) async {
    final ids = _playlists[name];
    if (ids == null) return;
    for (final song in selection) {
      if (!ids.contains(song.id)) ids.add(song.id);
    }
    await _savePlaylists();
  }

  Future<void> movePlaylistSong(String name, int from, int to) async {
    final ids = _playlists[name];
    final visible = playlistSongs(name);
    if (ids == null ||
        from < 0 ||
        to < 0 ||
        from >= visible.length ||
        to >= visible.length) return;
    final target = ids.indexOf(visible[to].id);
    final moved = visible[from].id;
    ids.remove(moved);
    ids.insert(target.clamp(0, ids.length), moved);
    await _savePlaylists();
  }

  Future<void> _savePlaylists() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playlistsKey, jsonEncode(_playlists));
    notifyListeners();
  }

  Future<void> restoreLibraryPreferences(Map<String, dynamic> payload) async {
    await _loadPreferences();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final dynamic favorites = payload['favorites'];
    if (favorites is List) {
      favoriteIds
        ..clear()
        ..addAll(
          favorites
              .map((value) => int.tryParse(value.toString()))
              .whereType<int>(),
        );
      await prefs.setStringList(
        _favoritesKey,
        favoriteIds.map((id) => id.toString()).toList(),
      );
    }

    final dynamic playlists = payload['playlists'];
    if (playlists is Map) {
      _playlists.clear();
      for (final entry in playlists.entries) {
        final name = entry.key.toString().trim();
        final values = entry.value;
        if (name.isEmpty || values is! List) continue;
        _playlists[name] = values
            .map((value) => int.tryParse(value.toString()))
            .whereType<int>()
            .toSet()
            .toList();
      }
      await prefs.setString(_playlistsKey, jsonEncode(_playlists));
      final pinned = payload['pinnedPlaylists'];
      await playlistPins.replace(
          (pinned is List ? pinned.whereType<String>() : playlistPins.names)
              .where(_playlists.containsKey));
    }

    final repeatMode = int.tryParse(payload['repeatMode']?.toString() ?? '');
    if (repeatMode != null &&
        repeatMode >= 0 &&
        repeatMode < LoopMode.values.length) {
      await player.setLoopMode(LoopMode.values[repeatMode]);
    }

    final shuffle = payload['shuffle'];
    if (shuffle is bool) {
      if (shuffle) {
        await player.shuffle();
      }
      await player.setShuffleModeEnabled(shuffle);
    }

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
  @override
  void dispose() {
    _abPosition?.cancel();
    _abIndex?.cancel();
    _checkpointTimer?.cancel();
    super.dispose();
  }

}
