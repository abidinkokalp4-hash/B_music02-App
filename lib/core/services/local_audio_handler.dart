import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Only owns local music. Other screens may keep their existing audio players.
class LocalAudioHandler extends BaseAudioHandler with SeekHandler {
  LocalAudioHandler(this.player) {
    player.playbackEventStream.listen((_) => _broadcast());
    player.playerStateStream.listen((state) {
      _broadcast();
      if (state.processingState == ProcessingState.completed) {
        unawaited(player.pause());
      }
    });
    player.sequenceStateStream.listen((state) {
      queue.add(state.sequence.map((s) => s.tag).whereType<MediaItem>().toList());
      final tag = state.currentSource?.tag;
      mediaItem.add(tag is MediaItem ? tag : null);
      _broadcast();
    });
    player.loopModeStream.listen((_) => _broadcast());
    player.shuffleModeEnabledStream.listen((_) => _broadcast());
    player.errorStream.listen((error) {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorCode: error.code,
        errorMessage: error.message,
      ));
    });
  }

  final AudioPlayer player;

  void _broadcast() {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: player.currentIndex,
      repeatMode: {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[player.loopMode]!,
      shuffleMode: player.shuffleModeEnabled
          ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }

  @override
  Future<void> play() async {
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero, index: player.effectiveIndices?.first ?? 0);
    }
    unawaited(player.play().catchError((Object _) {}));
  }

  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }
  @override
  Future<void> seek(Duration position) => player.seek(position);
  @override
  Future<void> skipToNext() async {
    if (player.hasNext) {
      await player.seekToNext();
      await play();
    }
  }
  @override
  Future<void> skipToPrevious() async {
    if (player.position.inSeconds > 5 || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await player.seek(Duration.zero, index: index);
    await play();
  }
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) => player.setLoopMode(
    mode == AudioServiceRepeatMode.one ? LoopMode.one
      : mode == AudioServiceRepeatMode.none ? LoopMode.off : LoopMode.all,
  );
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    final enabled = mode != AudioServiceShuffleMode.none;
    if (enabled) await player.shuffle();
    await player.setShuffleModeEnabled(enabled);
  }
}
