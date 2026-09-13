"""One-shot repair for Android audio_service media notification runtime flow."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

HANDLER = r'''import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class LocalAudioHandler extends BaseAudioHandler with SeekHandler {
  LocalAudioHandler(
    this.player, {
    required this.loadArtwork,
  }) {
    player.playbackEventStream
        .map<PlaybackState>(_transformEvent)
        .pipe(playbackState);

    player.sequenceStateStream.listen(_publishSequence);

    player.currentIndexStream.listen((_) {
      publishCurrentMediaItem();
    });

    player.errorStream.listen((PlayerException error) {
      playbackState.add(
        playbackState.value.copyWith(
          playing: false,
          processingState: AudioProcessingState.error,
          errorCode: error.code,
          errorMessage: error.message,
        ),
      );
    });
  }

  final AudioPlayer player;
  final Future<Uri?> Function(MediaItem item) loadArtwork;

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: <MediaControl>[
        MediaControl.skipToPrevious,
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const <MediaAction>{
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const <int>[0, 1, 2],
      processingState: switch (player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
      repeatMode: switch (player.loopMode) {
        LoopMode.off => AudioServiceRepeatMode.none,
        LoopMode.one => AudioServiceRepeatMode.one,
        LoopMode.all => AudioServiceRepeatMode.all,
      },
      shuffleMode: player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    );
  }

  void _publishSequence(SequenceState state) {
    final List<MediaItem> items = state.sequence
        .map((AudioSource source) => source.tag)
        .whereType<MediaItem>()
        .toList(growable: false);

    queue.add(items);

    final Object? tag = state.currentSource?.tag;
    final MediaItem? item = tag is MediaItem ? tag : null;
    if (item == null) {
      return;
    }

    mediaItem.add(item);
    if (item.artUri == null) {
      unawaited(_updateArtwork(item));
    }
  }

  void publishCurrentMediaItem() {
    final SequenceState? state = player.sequenceState;
    if (state != null) {
      _publishSequence(state);
    }
  }

  Future<void> _updateArtwork(MediaItem item) async {
    final Uri? uri = await loadArtwork(item);
    if (uri != null && mediaItem.value?.id == item.id) {
      mediaItem.add(item.copyWith(artUri: uri));
    }
  }

  @override
  Future<void> play() async {
    if (player.processingState == ProcessingState.completed) {
      await player.seek(
        Duration.zero,
        index: player.effectiveIndices.isEmpty
            ? 0
            : player.effectiveIndices.first,
      );
    }

    publishCurrentMediaItem();
    unawaited(
      player.play().catchError((Object error) {
        playbackState.add(
          playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.error,
            errorMessage: error.toString(),
          ),
        );
      }),
    );
  }

  @override
  Future<void> pause() async {
    await player.pause();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (!player.hasNext) {
      return;
    }
    await player.seekToNext();
    publishCurrentMediaItem();
  }

  @override
  Future<void> skipToPrevious() async {
    if (player.position.inSeconds > 5 || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
    publishCurrentMediaItem();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) {
      return;
    }
    await player.seek(Duration.zero, index: index);
    publishCurrentMediaItem();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final LoopMode loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one => LoopMode.one,
      _ => LoopMode.all,
    };
    await player.setLoopMode(loopMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final bool enabled = shuffleMode != AudioServiceShuffleMode.none;
    if (enabled) {
      await player.shuffle();
    }
    await player.setShuffleModeEnabled(enabled);
  }
}
'''


def patch_service() -> None:
    path = ROOT / 'lib/core/services/local_music_service.dart'
    text = path.read_text(encoding='utf-8')

    permission_import = "import 'package:permission_handler/permission_handler.dart';\n"
    anchor = "import 'package:path_provider/path_provider.dart';\n"
    if permission_import not in text:
        if anchor not in text:
            raise RuntimeError('path_provider import anchor not found')
        text = text.replace(anchor, anchor + permission_import, 1)

    if 'late final LocalAudioHandler _localAudioHandler;' not in text:
        old = '  late final AudioHandler _audioHandler;\n'
        if old not in text:
            raise RuntimeError('audio handler field anchor not found')
        text = text.replace(
            old,
            old + '  late final LocalAudioHandler _localAudioHandler;\n',
            1,
        )

    if '_localAudioHandler = handler;' not in text:
        old = '    _audioHandler = handler;\n    return handler;'
        new = (
            '    _localAudioHandler = handler;\n'
            '    _audioHandler = handler;\n'
            '    return handler;'
        )
        if old not in text:
            raise RuntimeError('handler assignment anchor not found')
        text = text.replace(old, new, 1)

    permission_method = '''  Future<void> _ensureNotificationPermission() async {
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

'''
    if 'Future<void> _ensureNotificationPermission()' not in text:
        anchor = '  Future<void> playSong(\n'
        if anchor not in text:
            raise RuntimeError('playSong anchor not found')
        text = text.replace(anchor, permission_method + anchor, 1)

    if 'await _ensureNotificationPermission();' not in text:
        old = '    notifyListeners();\n    _startPlaying();\n  }'
        new = (
            '    _localAudioHandler.publishCurrentMediaItem();\n'
            '    await _ensureNotificationPermission();\n\n'
            '    notifyListeners();\n'
            '    _startPlaying();\n'
            '  }'
        )
        if old not in text:
            raise RuntimeError('play selection tail not found')
        text = text.replace(old, new, 1)

    path.write_text(text, encoding='utf-8')


def patch_main() -> None:
    path = ROOT / 'lib/main.dart'
    text = path.read_text(encoding='utf-8')

    old_channel = "androidNotificationChannelId: 'com.example.b_music02.audio.playback',"
    new_channel = "androidNotificationChannelId: 'com.example.b_music02.media.playback.v3',"
    if old_channel in text:
        text = text.replace(old_channel, new_channel, 1)
    elif new_channel not in text:
        raise RuntimeError('notification channel anchor not found')

    name_line = "      androidNotificationChannelName: 'B_music02 Müzik',\n"
    description = (
        "      androidNotificationChannelDescription:\n"
        "          'Çalan müzik ve kilit ekranı medya kontrolleri',\n"
    )
    if 'androidNotificationChannelDescription:' not in text:
        if name_line not in text:
            raise RuntimeError('channel name anchor not found')
        text = text.replace(name_line, name_line + description, 1)

    path.write_text(text, encoding='utf-8')


def main() -> None:
    (ROOT / 'lib/core/services/local_audio_handler.dart').write_text(
        HANDLER,
        encoding='utf-8',
    )
    patch_service()
    patch_main()

    handler = (ROOT / 'lib/core/services/local_audio_handler.dart').read_text(encoding='utf-8')
    service = (ROOT / 'lib/core/services/local_music_service.dart').read_text(encoding='utf-8')
    app = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')

    assert 'playbackEventStream' in handler
    assert 'forcePlaying' not in handler
    assert 'Permission.notification.request' in service
    assert 'publishCurrentMediaItem' in service
    assert 'media.playback.v3' in app

    print('Android media notification runtime patch applied.')


if __name__ == '__main__':
    main()
