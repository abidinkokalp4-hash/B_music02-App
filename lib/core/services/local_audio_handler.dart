import 'dart:async';

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
