import 'package:audio_service/audio_service.dart';
import 'package:b_music02/core/services/sleep_timer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'support/fake_audio_player.dart';

void main() {
  testWidgets('replacing a timer cancels the previous deadline',
      (tester) async {
    final player = TestAudioPlayer();
    var pauses = 0;
    final timer = SleepTimer(
        player: player,
        pause: () async {
          pauses++;
        },
        onChange: () {});
    timer.start(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    timer.start(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 4));
    expect(pauses, 0);
    await tester.pump(const Duration(seconds: 6));
    expect(pauses, 1);
    expect(timer.isActive, false);
    timer.cancel();
    await player.close();
  });
  testWidgets(
      'cancel removes end-of-track listeners and cannot pause a later song',
      (tester) async {
    final player = TestAudioPlayer();
    await player.setAudioSources([
      AudioSource.uri(Uri.file('/a.mp3'),
          tag: const MediaItem(id: 'a', title: 'A'))
    ]);
    var pauses = 0;
    final timer = SleepTimer(
        player: player,
        pause: () async {
          pauses++;
        },
        onChange: () {});
    timer.stopAfterTrack();
    timer.cancel();
    player.index = 1;
    player.emitSequence();
    player.processing = ProcessingState.completed;
    player.emitState();
    await tester.pump();
    expect(pauses, 0);
    timer.cancel();
    await player.close();
  });
  testWidgets(
      'end-of-track mode pauses at a multi-track transition, then disarms',
      (tester) async {
    final player = TestAudioPlayer();
    await player.setAudioSources([
      AudioSource.uri(Uri.file('/a.mp3')),
      AudioSource.uri(Uri.file('/b.mp3'))
    ]);
    var pauses = 0;
    final timer = SleepTimer(
        player: player,
        pause: () async {
          pauses++;
        },
        onChange: () {});
    timer.stopAfterTrack();
    player.index = 1;
    player.emitSequence();
    await tester.pump();
    expect(pauses, 1);
    expect(timer.afterTrack, false);
    player.emitSequence();
    await tester.pump();
    expect(pauses, 1);
    timer.cancel();
    await player.close();
  });
  testWidgets('repeat-one pauses before the native loop restarts',
      (tester) async {
    final player = TestAudioPlayer();
    await player.setAudioSources([AudioSource.uri(Uri.file('/a.mp3'))]);
    player.length = const Duration(seconds: 10);
    player.loop = LoopMode.one;
    player.at = const Duration(seconds: 9);
    player.isPlaying = true;
    var pauses = 0;
    final timer = SleepTimer(
        player: player,
        pause: () async {
          pauses++;
        },
        onChange: () {});
    timer.stopAfterTrack();
    player.at = const Duration(milliseconds: 9960);
    await tester.pump(const Duration(milliseconds: 960));
    expect(pauses, 1);
    expect(timer.isActive, false);
    timer.cancel();
    await player.close();
  });
}
