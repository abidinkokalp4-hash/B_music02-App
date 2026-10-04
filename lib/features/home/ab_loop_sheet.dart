import 'package:flutter/material.dart';
import '../../core/services/local_music_service.dart';
import 'video_player_controls.dart';
import 'widgets/music_widgets.dart';

Future<void> showABLoop(BuildContext context, LocalMusicService music) async {
  final duration = music.player.duration;
  if (duration == null || duration.inMilliseconds < 500) return;
  final max = duration.inMilliseconds.toDouble();
  var range = RangeValues((music.loopA ?? music.player.position).inMilliseconds.toDouble().clamp(0, max - 500),
      (music.loopB ?? duration).inMilliseconds.toDouble().clamp(500, max));
  await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (c) => StatefulBuilder(builder: (c, update) => SafeArea(child: Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('A–B bölüm tekrarı', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12), const Text('Başlangıç ve bitişi seç. Şarkı değişince bölüm tekrarı kapanır.'),
      RangeSlider(values: range, max: max, labels: RangeLabels(videoTime(Duration(milliseconds: range.start.round())), videoTime(Duration(milliseconds: range.end.round()))),
        onChanged: (v) { if (v.end - v.start >= 500) update(() => range = v); }),
      Text('${videoTime(Duration(milliseconds: range.start.round()))} — ${videoTime(Duration(milliseconds: range.end.round()))}'),
      const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        TextButton(onPressed: () { music.clearABLoop(); Navigator.pop(c); }, child: const Text('Kapat')),
        FilledButton(onPressed: () => runMusicAction(c, () async {
          await music.setABLoop(Duration(milliseconds: range.start.round()), Duration(milliseconds: range.end.round()));
          if (c.mounted) Navigator.pop(c);
        }), child: const Text('Tekrarla')),
      ]),
    ])))));
}
