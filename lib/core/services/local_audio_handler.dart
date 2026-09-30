import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class LocalAudioHandler extends BaseAudioHandler with SeekHandler {
  LocalAudioHandler(
    this.player, {
    required this.loadArtwork,
  }) {
    // Android AudioService enters foreground when playbackState.playing becomes
    // true. A PlayerEvent is an atomic snapshot: forward the callback payload
    // instead of combining values from separately updated derived getters.
    player.playerEventStream.listen((event) => _broadcastState(
          event: event.playbackEvent,
          playing: event.playing,
        ));
    player.playingStream.listen((playing) => _broadcastState(playing: playing));
    player.processingStateStream.listen((state) => _broadcastState(
          event: (_latestEvent ?? player.playbackEvent)
              .copyWith(processingState: state),
        ));
    player.loopModeStream.distinct().listen((_) => _broadcastState());
    player.shuffleModeEnabledStream.distinct().listen((_) => _broadcastState());
    player.speedStream.distinct().listen((_) => _broadcastState());

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
  MediaItem? _publishedSourceItem;
  PlaybackEvent? _latestEvent;
  bool? _latestPlaying;

  void syncSystemState() {
    publishCurrentMediaItem();
    _broadcastState(force: true);
  }

  void _broadcastState({
    PlaybackEvent? event,
    bool? playing,
    bool force = false,
  }) {
    if (event != null) _latestEvent = event;
    if (playing != null) _latestPlaying = playing;
    final next = _transformEvent(
      _latestEvent ?? player.playbackEvent,
      _latestPlaying ?? player.playing,
    );
    final previous = playbackState.value;
    // Several just_audio streams describe the same event. Avoid queuing the
    // same paused/loading state repeatedly ahead of a real play transition.
    if (!force &&
        previous.playing == next.playing &&
        previous.processingState == next.processingState &&
        previous.updatePosition == next.updatePosition &&
        previous.bufferedPosition == next.bufferedPosition &&
        previous.speed == next.speed &&
        previous.queueIndex == next.queueIndex &&
        previous.repeatMode == next.repeatMode &&
        previous.shuffleMode == next.shuffleMode &&
        previous.errorCode == next.errorCode &&
        previous.errorMessage == next.errorMessage &&
        listEquals(previous.controls, next.controls) &&
        setEquals(previous.systemActions, next.systemActions) &&
        listEquals(previous.androidCompactActionIndices,
            next.androidCompactActionIndices)) {
      return;
    }
    if (previous.playing != next.playing ||
        previous.processingState != next.processingState) {
      debugPrint('[B_music02 media] playing=${next.playing} '
          'processing=${next.processingState.name} index=${next.queueIndex}');
    }
    playbackState.add(next);
  }

  PlaybackState _transformEvent(PlaybackEvent event, bool playing) {
    // Completion is silent even though just_audio keeps its play intent true.
    // Match the in-app play button and let system controls offer replay.
    final active =
        playing && event.processingState != ProcessingState.completed;
    return PlaybackState(
      controls: <MediaControl>[
        MediaControl.skipToPrevious,
        active ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const <MediaAction>{
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const <int>[0, 1, 2],
      processingState: switch (event.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: active,
      updatePosition: event.updatePosition,
      bufferedPosition: event.bufferedPosition,
      updateTime: event.updateTime,
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

    final previousQueue = queue.value;
    if (previousQueue.length != items.length ||
        Iterable<int>.generate(items.length)
            .any((index) => !identical(previousQueue[index], items[index]))) {
      queue.add(items);
    }

    final Object? tag = state.currentSource?.tag;
    final MediaItem? item = tag is MediaItem ? tag : null;
    // SequenceState is emitted for ordinary playback events too. Publishing
    // its unchanged tag would reset resolved artwork/duration and send both
    // metadata and the entire queue to Android on every progress update.
    if (identical(item, _publishedSourceItem)) return;
    _publishedSourceItem = item;
    mediaItem.add(item);
    if (item != null && item.artUri == null) {
      unawaited(_updateArtwork(item));
    }
  }

  void publishCurrentMediaItem() {
    _publishSequence(player.sequenceState);
  }

  Future<void> _updateArtwork(MediaItem item) async {
    final Uri? uri = await loadArtwork(item);
    final current = mediaItem.value;
    if (uri != null &&
        current != null &&
        identical(_publishedSourceItem, item)) {
      mediaItem.add(current.copyWith(artUri: uri));
    }
  }

  @override
  Future<void> play() async {
    if (player.processingState == ProcessingState.completed) {
      await player.seek(
        Duration.zero,
        index:
            player.effectiveIndices.isEmpty ? 0 : player.effectiveIndices.first,
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
