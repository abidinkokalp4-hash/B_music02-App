import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class LocalAudioHandler extends BaseAudioHandler with SeekHandler {
  LocalAudioHandler(
    this.player, {
    required this.loadArtwork,
  }) {
    player.playbackEventStream.listen((_) {
      _broadcast();
    });

    player.playerStateStream.listen((state) {
      _broadcast();

      if (state.processingState == ProcessingState.completed) {
        unawaited(player.pause());
      }
    });

    player.sequenceStateStream.listen((state) {
      final items = state.sequence
          .map((source) => source.tag)
          .whereType<MediaItem>()
          .toList();

      queue.add(items);

      final tag = state.currentSource?.tag;
      final item = tag is MediaItem ? tag : null;

      mediaItem.add(item);

      if (item != null && item.artUri == null) {
        unawaited(_updateArtwork(item));
      }

      _broadcast();
    });

    player.loopModeStream.listen((_) {
      _broadcast();
    });

    player.shuffleModeEnabledStream.listen((_) {
      _broadcast();
    });

    player.errorStream.listen((error) {
      playbackState.add(
        playbackState.value.copyWith(
          playing: false,
          processingState: AudioProcessingState.error,
          errorCode: error.code,
          errorMessage: error.message,
        ),
      );
    });

    // İlk medya durumu Android AudioService'e gönderilir.
    _broadcast();
  }

  final AudioPlayer player;

  final Future<Uri?> Function(
    MediaItem item,
  ) loadArtwork;

  Future<void> _updateArtwork(
    MediaItem item,
  ) async {
    final uri =
        await loadArtwork(item);

    if (uri != null &&
        mediaItem.value?.id == item.id) {
      mediaItem.add(
        item.copyWith(
          artUri: uri,
        ),
      );
    }
  }

  AudioProcessingState _processingState() {
    return switch (player.processingState) {
      ProcessingState.idle =>
        AudioProcessingState.idle,
      ProcessingState.loading =>
        AudioProcessingState.loading,
      ProcessingState.buffering =>
        AudioProcessingState.buffering,
      ProcessingState.ready =>
        AudioProcessingState.ready,
      ProcessingState.completed =>
        AudioProcessingState.completed,
    };
  }

  void _broadcast({
    bool? forcePlaying,
  }) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          (forcePlaying ?? player.playing)
              ? MediaControl.pause
              : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices:
            const [0, 1, 2],
        processingState:
            _processingState(),
        playing:
            forcePlaying ??
            player.playing,
        updatePosition:
            player.position,
        bufferedPosition:
            player.bufferedPosition,
        speed: player.speed,
        queueIndex:
            player.currentIndex,
        repeatMode:
            switch (player.loopMode) {
          LoopMode.off =>
            AudioServiceRepeatMode.none,
          LoopMode.one =>
            AudioServiceRepeatMode.one,
          LoopMode.all =>
            AudioServiceRepeatMode.all,
        },
        shuffleMode:
            player.shuffleModeEnabled
                ? AudioServiceShuffleMode.all
                : AudioServiceShuffleMode.none,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (player.processingState ==
        ProcessingState.completed) {
      await player.seek(
        Duration.zero,
        index:
            player.effectiveIndices.isEmpty
                ? 0
                : player
                    .effectiveIndices
                    .first,
      );
    }

    // Kritik:
    // Android'e oynatma başlamadan hemen önce playing=true
    // gönderiyoruz. Bu foreground media servisini ve
    // medya bildirimini tetikler.
    _broadcast(
      forcePlaying: true,
    );

    unawaited(
      player.play().catchError(
        (Object error) {
          _broadcast(
            forcePlaying: false,
          );
        },
      ),
    );
  }

  @override
  Future<void> pause() async {
    await player.pause();

    _broadcast(
      forcePlaying: false,
    );
  }

  @override
  Future<void> stop() async {
    await player.stop();

    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState:
            AudioProcessingState.idle,
        updatePosition:
            player.position,
        bufferedPosition:
            player.bufferedPosition,
      ),
    );

    await super.stop();
  }

  @override
  Future<void> seek(
    Duration position,
  ) async {
    await player.seek(position);

    _broadcast();
  }

  @override
  Future<void>
      skipToNext() async {
    if (!player.hasNext) {
      return;
    }

    await player.seekToNext();

    _broadcast(
      forcePlaying: true,
    );

    unawaited(
      player.play(),
    );
  }

  @override
  Future<void>
      skipToPrevious() async {
    if (player.position.inSeconds > 5 ||
        !player.hasPrevious) {
      await player.seek(
        Duration.zero,
      );
    } else {
      await player.seekToPrevious();
    }

    _broadcast(
      forcePlaying: true,
    );

    unawaited(
      player.play(),
    );
  }

  @override
  Future<void> skipToQueueItem(
    int index,
  ) async {
    if (index < 0 ||
        index >= queue.value.length) {
      return;
    }

    await player.seek(
      Duration.zero,
      index: index,
    );

    _broadcast(
      forcePlaying: true,
    );

    unawaited(
      player.play(),
    );
  }

  @override
  Future<void> setRepeatMode(
    AudioServiceRepeatMode mode,
  ) async {
    final loopMode =
        switch (mode) {
      AudioServiceRepeatMode.none =>
        LoopMode.off,
      AudioServiceRepeatMode.one =>
        LoopMode.one,
      _ => LoopMode.all,
    };

    await player.setLoopMode(
      loopMode,
    );

    _broadcast();
  }

  @override
  Future<void> setShuffleMode(
    AudioServiceShuffleMode mode,
  ) async {
    final enabled =
        mode !=
        AudioServiceShuffleMode.none;

    if (enabled) {
      await player.shuffle();
    }

    await player
        .setShuffleModeEnabled(
      enabled,
    );

    _broadcast();
  }
}
