import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:b_music02/core/services/local_audio_handler.dart';

// No native audio device is needed: exercise the handler's system-facing state.
class FakePlayer extends Fake implements AudioPlayer {
  final events = StreamController<PlayerEvent>.broadcast(sync: true);
  final playingChanges = StreamController<bool>.broadcast(sync: true);
  final processingChanges =
      StreamController<ProcessingState>.broadcast(sync: true);
  final sequences = StreamController<SequenceState>.broadcast(sync: true);
  final errors = StreamController<PlayerException>.broadcast(sync: true);
  final loops = StreamController<LoopMode>.broadcast(sync: true);
  final shuffles = StreamController<bool>.broadcast(sync: true);
  final speeds = StreamController<double>.broadcast(sync: true);
  final durations = StreamController<Duration?>.broadcast(sync: true);

  bool isPlaying = false;
  PlaybackEvent event = PlaybackEvent(processingState: ProcessingState.ready);
  LoopMode loop = LoopMode.off;
  bool shuffled = false;
  SequenceState currentSequence = SequenceState(
    sequence: [],
    currentIndex: null,
    shuffleIndices: [],
    shuffleModeEnabled: false,
    loopMode: LoopMode.off,
  );

  @override
  Stream<PlayerEvent> get playerEventStream => events.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream =>
      events.stream.map((e) => e.playbackEvent).distinct();

  @override
  Stream<bool> get playingStream => playingChanges.stream;

  @override
  Stream<ProcessingState> get processingStateStream => processingChanges.stream;

  @override
  Stream<SequenceState> get sequenceStateStream => sequences.stream;

  @override
  Stream<int?> get currentIndexStream => const Stream.empty();

  @override
  Stream<PlayerException> get errorStream => errors.stream;

  @override
  Stream<LoopMode> get loopModeStream => loops.stream;

  @override
  Stream<bool> get shuffleModeEnabledStream => shuffles.stream;

  @override
  Stream<double> get speedStream => speeds.stream;

  @override
  Stream<Duration?> get durationStream => durations.stream;

  @override
  bool get playing => isPlaying;

  @override
  PlaybackEvent get playbackEvent => event;

  @override
  ProcessingState get processingState => event.processingState;

  @override
  Duration get position => event.updatePosition;

  @override
  Duration get bufferedPosition => event.bufferedPosition;

  @override
  double get speed => 1;

  @override
  LoopMode get loopMode => loop;

  @override
  bool get shuffleModeEnabled => shuffled;

  @override
  SequenceState get sequenceState => currentSequence;

  @override
  List<int> get effectiveIndices => const <int>[];

  void emitPlaying(bool value, {bool emitPlayerEvent = true}) {
    isPlaying = value;
    playingChanges.add(value);
    if (emitPlayerEvent) {
      events.add(PlayerEvent(playing: value, playbackEvent: event));
    }
  }

  void emitProcessing(ProcessingState state) {
    event = PlaybackEvent(processingState: state);
    processingChanges.add(state);
    events.add(PlayerEvent(playing: isPlaying, playbackEvent: event));
  }

  @override
  Future<void> play() async {
    emitPlaying(true, emitPlayerEvent: false);
  }

  @override
  Future<void> pause() async => emitPlaying(false, emitPlayerEvent: false);

  @override
  Future<void> stop() async {
    event = PlaybackEvent(processingState: ProcessingState.idle);
    processingChanges.add(ProcessingState.idle);
    emitPlaying(false, emitPlayerEvent: false);
  }

  Future<void> close() async {
    await Future.wait([
      events.close(),
      playingChanges.close(),
      processingChanges.close(),
      sequences.close(),
      errors.close(),
      loops.close(),
      shuffles.close(),
      speeds.close(),
      durations.close(),
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePlayer player;
  late LocalAudioHandler handler;

  setUp(() {
    player = FakePlayer();
    handler = LocalAudioHandler(player, loadArtwork: (_) async => null);
  });

  tearDown(() async => player.close());

  test('handler seeds a complete initial system state', () {
    expect(handler.playbackState.value.playing, isFalse);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
    expect(handler.playbackState.value.controls[1], MediaControl.play);
  });

  test('playing-only stream transitions reach MediaSession', () {
    player.emitPlaying(false, emitPlayerEvent: false);
    player.emitPlaying(true, emitPlayerEvent: false);
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.playbackState.value.controls[1], MediaControl.pause);

    player.emitPlaying(false, emitPlayerEvent: false);
    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.playbackState.value.controls[1], MediaControl.play);
  });

  test('play explicitly publishes foreground-playing state', () async {
    expect(handler.playbackState.value.playing, isFalse);
    await handler.play();
    expect(handler.playbackState.value.playing, isTrue);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
  });

  test('processing-only changes reach MediaSession', () {
    player.emitProcessing(ProcessingState.buffering);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.buffering,
    );

    player.emitProcessing(ProcessingState.ready);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
  });

  test('stop publishes idle so Android can remove the foreground notification',
      () async {
    player.emitPlaying(true);
    await handler.stop();
    expect(handler.playbackState.value.playing, isFalse);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
  });

  test('repeat and shuffle reach system controls while paused', () {
    player.loop = LoopMode.one;
    player.loops.add(LoopMode.one);
    player.shuffled = true;
    player.shuffles.add(true);
    expect(
      handler.playbackState.value.repeatMode,
      AudioServiceRepeatMode.one,
    );
    expect(
      handler.playbackState.value.shuffleMode,
      AudioServiceShuffleMode.all,
    );
  });

  test('an error can publish directly and the next track can recover', () {
    player.emitPlaying(true);
    player.errors.add(PlayerException(100, 'Missing file', 0));
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.error,
    );
    expect(handler.playbackState.value.playing, isFalse);

    player.emitPlaying(true);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
    expect(handler.playbackState.value.errorMessage, isNull);
  });

  test('download metadata and discovered duration reach lock-screen seek controls',
      () {
    const item = MediaItem(
      id: 'file:///music.wav',
      title: 'Download',
      artist: 'Artist',
    );
    player.currentSequence = SequenceState(
      sequence: [AudioSource.uri(Uri.parse(item.id), tag: item)],
      currentIndex: 0,
      shuffleIndices: [0],
      shuffleModeEnabled: false,
      loopMode: LoopMode.off,
    );
    player.sequences.add(player.currentSequence);
    player.durations.add(const Duration(seconds: 90));
    expect(handler.queue.value.single.id, item.id);
    expect(handler.mediaItem.value?.title, 'Download');
    expect(handler.mediaItem.value?.duration, const Duration(seconds: 90));
  });
}
