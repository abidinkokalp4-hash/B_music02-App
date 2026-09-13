import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class LocalAudioHandler extends BaseAudioHandler with SeekHandler {
  LocalAudioHandler(
    this.player, {
    required this.loadArtwork,
  }) {
    // Android AudioService enters foreground when playbackState.playing becomes
    // true. Listen to the two just_audio state sources independently so a pure
    // play/pause transition can never be missed by the MediaSession.
    player.playingStream.listen((_) => _broadcastState());
    player.playbackEventStream.listen((_) => _broadcastState());
    player.processingStateStream.listen((_) => _broadcastState());
    player.loopModeStream.listen((_) => _broadcastState());
    player.shuffleModeEnabledStream.listen((_) => _broadcastState());
    player.speedStream.listen((_) => _broadcastState());

    player.sequenceStateStream.listen(_publishSequence);
    player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null && item.duration != duration) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });

    player.currentIndexStream.listen((_) {
      publishCurrentMediaItem();
      _broadcastState();
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

    // Seed audio_service with a complete initial state immediately. This avoids
    // leaving the Android service at its implicit idle/default state until the
    // first native playback event happens to arrive.
    _broadcastState();
  }

  final AudioPlayer player;
  final Future<Uri?> Function(MediaItem item) loadArtwork;

  void syncSystemState() {
    publishCurrentMediaItem();
    _broadcastState();
  }

  void _broadcastState() {
    playbackState.add(_transformEvent(player.playbackEvent));
  }

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
        .map((source) => source.tag)
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

    // just_audio's play() future stays pending for the lifetime of playback.
    // Start it without awaiting, then explicitly publish the playing state so
    // audio_service can promote its Android service to foreground immediately.
    final Future<void> playFuture = player.play();
    _broadcastState();

    unawaited(
      playFuture.catchError((Object error) {
        playbackState.add(
          playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.error,
            errorMessage: error.toString(),
          ),
        );
      }),
    );

    // Allow just_audio to flush its synchronous playing transition and publish
    // once more. This is intentionally short and does not wait for playback to
    // finish.
    await Future<void>.delayed(Duration.zero);
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await player.pause();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    _broadcastState();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    if (!player.hasNext) {
      return;
    }
    await player.seekToNext();
    publishCurrentMediaItem();
    _broadcastState();
  }

  @override
  Future<void> skipToPrevious() async {
    if (player.position.inSeconds > 5 || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
    publishCurrentMediaItem();
    _broadcastState();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) {
      return;
    }
    await player.seek(Duration.zero, index: index);
    publishCurrentMediaItem();
    _broadcastState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final LoopMode loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one => LoopMode.one,
      _ => LoopMode.all,
    };
    await player.setLoopMode(loopMode);
    _broadcastState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final bool enabled = shuffleMode != AudioServiceShuffleMode.none;
    if (enabled) {
      await player.shuffle();
    }
    await player.setShuffleModeEnabled(enabled);
    _broadcastState();
  }
}
