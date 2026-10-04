import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class TestAudioPlayer extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final playingChanges = StreamController<bool>.broadcast(sync: true);
  final processingChanges =
      StreamController<ProcessingState>.broadcast(sync: true);
  final events = StreamController<PlaybackEvent>.broadcast(sync: true);
  final sequenceChanges = StreamController<SequenceState>.broadcast(sync: true);
  final indices = StreamController<int?>.broadcast(sync: true);
  final errors = StreamController<PlayerException>.broadcast(sync: true);
  final loops = StreamController<LoopMode>.broadcast(sync: true);
  final shuffles = StreamController<bool>.broadcast(sync: true);
  final speeds = StreamController<double>.broadcast(sync: true);
  final volumes = StreamController<double>.broadcast(sync: true);
  final positions = StreamController<Duration>.broadcast(sync: true);
  final durations = StreamController<Duration?>.broadcast(sync: true);
  List<IndexedAudioSource> sources = [];
  int? index;
  bool isPlaying = false;
  bool shuffled = false;
  Duration at = Duration.zero;
  Duration? length = const Duration(minutes: 3);
  ProcessingState processing = ProcessingState.ready;
  LoopMode loop = LoopMode.off;
  double playbackSpeed = 1, playbackVolume = 1;

  @override
  Stream<bool> get playingStream => playingChanges.stream;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<ProcessingState> get processingStateStream => processingChanges.stream;
  @override
  Stream<PlayerEvent> get playerEventStream => events.stream
      .map((event) => PlayerEvent(playing: isPlaying, playbackEvent: event));
  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;
  @override
  Stream<SequenceState> get sequenceStateStream => sequenceChanges.stream;
  @override
  Stream<int?> get currentIndexStream => indices.stream;
  @override
  Stream<PlayerException> get errorStream => errors.stream;
  @override
  Stream<LoopMode> get loopModeStream => loops.stream;
  @override
  Stream<bool> get shuffleModeEnabledStream => shuffles.stream;
  @override
  Stream<double> get speedStream => speeds.stream;
  @override
  Stream<double> get volumeStream => volumes.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration> createPositionStream({int steps = 800, Duration minPeriod = const Duration(milliseconds: 200), Duration maxPeriod = const Duration(milliseconds: 200)}) => positions.stream;
  @override
  Stream<Duration?> get durationStream => durations.stream;
  @override
  bool get playing => isPlaying;
  @override
  int? get currentIndex => index;
  @override
  Duration get position => at;
  @override
  Duration? get duration => length;
  @override
  Duration get bufferedPosition => at;
  @override
  double get speed => playbackSpeed;
  @override
  double get volume => playbackVolume;
  @override
  ProcessingState get processingState => processing;
  @override
  PlayerState get playerState => PlayerState(isPlaying, processing);
  @override
  LoopMode get loopMode => loop;
  @override
  bool get shuffleModeEnabled => shuffled;
  @override
  List<IndexedAudioSource> get sequence => sources;
  @override
  AudioSource? get audioSource => sources.isEmpty ? null : sources.first;
  @override
  List<int> get effectiveIndices => List.generate(sources.length, (i) => i);
  @override
  SequenceState get sequenceState => SequenceState(
      sequence: sources,
      currentIndex: index,
      shuffleIndices: effectiveIndices,
      shuffleModeEnabled: shuffled,
      loopMode: loop);
  @override
  PlaybackEvent get playbackEvent => PlaybackEvent(
      currentIndex: index,
      updatePosition: at,
      duration: length,
      processingState: processing,
      bufferedPosition: at);
  @override
  bool get hasNext => index != null && index! + 1 < sources.length;
  @override
  bool get hasPrevious => index != null && index! > 0;

  void emitSequence() {
    sequenceChanges.add(sequenceState);
    indices.add(index);
    events.add(playbackEvent);
  }

  void emitState() {
    playingChanges.add(isPlaying);
    processingChanges.add(processing);
    states.add(playerState);
    events.add(playbackEvent);
  }

  void setPosition(Duration position) {
    at = position;
    positions.add(position);
    events.add(playbackEvent);
  }

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
    bool useLazyPreparation = true,
  }) async {
    sources = audioSources.cast<IndexedAudioSource>().toList();
    index = sources.isEmpty ? null : initialIndex ?? 0;
    at = initialPosition ?? Duration.zero;
    emitSequence();
    return length;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    emitState();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    emitState();
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    processing = ProcessingState.idle;
    emitState();
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    if (index != null) this.index = index;
    at = position ?? Duration.zero;
    if (processing == ProcessingState.completed) {
      processing = ProcessingState.ready;
      emitState();
    }
    emitSequence();
    positions.add(at);
  }

  @override
  Future<void> seekToNext() => seek(Duration.zero, index: index! + 1);
  @override
  Future<void> seekToPrevious() => seek(Duration.zero, index: index! - 1);
  @override
  Future<void> setLoopMode(LoopMode value) async {
    loop = value;
    loops.add(value);
  }

  @override
  Future<void> shuffle() async {}
  @override
  Future<void> setShuffleModeEnabled(bool value) async {
    shuffled = value;
    shuffles.add(value);
    emitSequence();
  }

  @override
  Future<void> setSpeed(double value) async {
    playbackSpeed = value;
    speeds.add(value);
  }

  @override
  Future<void> setVolume(double value) async {
    playbackVolume = value;
    volumes.add(value);
  }

  @override
  Future<void> insertAudioSource(int atIndex, AudioSource source) async {
    sources.insert(atIndex, source as IndexedAudioSource);
    if (index != null && atIndex <= index!) index = index! + 1;
    emitSequence();
  }

  @override
  Future<void> moveAudioSource(int currentIndex, int newIndex) async {
    final selected = index == null ? null : sources[index!];
    sources.insert(newIndex, sources.removeAt(currentIndex));
    if (selected != null) index = sources.indexOf(selected);
    emitSequence();
  }

  @override
  Future<void> removeAudioSourceAt(int atIndex) async {
    final selected = index == null ? null : sources[index!];
    sources.removeAt(atIndex);
    index = sources.isEmpty
        ? null
        : selected != null && sources.contains(selected)
            ? sources.indexOf(selected)
            : atIndex.clamp(0, sources.length - 1);
    emitSequence();
  }

  @override
  Future<void> removeAudioSourceRange(int start, int end) async {
    final selected = index == null ? null : sources[index!];
    sources.removeRange(start, end);
    index = sources.isEmpty
        ? null
        : selected != null && sources.contains(selected)
            ? sources.indexOf(selected)
            : 0;
    emitSequence();
  }

  Future<void> close() async {
    await Future.wait([
      states.close(),
      playingChanges.close(),
      processingChanges.close(),
      events.close(),
      sequenceChanges.close(),
      indices.close(),
      errors.close(),
      loops.close(),
      shuffles.close(),
      speeds.close(),
      volumes.close(),
      positions.close(),
      durations.close()
    ]);
  }
}
