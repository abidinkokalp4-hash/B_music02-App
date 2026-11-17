import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/l10n/app_text.dart';
import '../../core/platform/feature_bridge.dart';
import '../../core/services/local_music_service.dart';
import '../home/video_player_controls.dart' show videoTime;

const clipLength = Duration(seconds: 15);

/// Waveform strip with a fixed 15-second window the user slides (mockups 01 / 08).
class ClipWindowPicker extends StatefulWidget {
  const ClipWindowPicker(
      {super.key,
      required this.total,
      required this.start,
      required this.onChanged,
      this.seed = 7,
      this.previewPath,
      this.enabled = true});
  final Duration total, start;
  final ValueChanged<Duration> onChanged;
  final int seed;
  final String? previewPath;
  final bool enabled;

  @override
  State<ClipWindowPicker> createState() => _ClipWindowPickerState();
}

class _ClipWindowPickerState extends State<ClipWindowPicker> {
  AudioPlayer? preview;
  bool playing = false;
  late final bars = pseudoWaveform(widget.seed, 46);

  Duration get end {
    final e = widget.start + clipLength;
    return e > widget.total ? widget.total : e;
  }

  @override
  void dispose() {
    preview?.dispose();
    super.dispose();
  }

  Future<void> togglePreview() async {
    final path = widget.previewPath;
    if (path == null) return;
    if (playing) {
      await preview?.stop();
      if (mounted) setState(() => playing = false);
      return;
    }
    try {
      if (LocalMusicService.instance.hasPlayer &&
          LocalMusicService.instance.player.playing) {
        await LocalMusicService.instance.pause();
      }
      final p = preview ??= AudioPlayer(handleInterruptions: false);
      await p.setAudioSource(ClippingAudioSource(
          child: AudioSource.uri(path.startsWith('content:') || path.startsWith('file:')
              ? Uri.parse(path)
              : Uri.file(path)),
          start: widget.start,
          end: end));
      setState(() => playing = true);
      unawaited(p.play().whenComplete(() {
        if (mounted) setState(() => playing = false);
      }));
    } catch (_) {
      if (mounted) setState(() => playing = false);
    }
  }

  void _drag(double dx, double width) {
    final totalMs = widget.total.inMilliseconds;
    final maxStart = (totalMs - clipLength.inMilliseconds).clamp(0, totalMs);
    if (maxStart == 0 || width <= 0) return;
    final next = (widget.start.inMilliseconds + dx / width * totalMs)
        .round()
        .clamp(0, maxStart);
    if (playing) unawaited(preview?.stop());
    playing = false;
    widget.onChanged(Duration(milliseconds: next));
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFFB65CFF);
    final totalMs = widget.total.inMilliseconds.clamp(1, 1 << 40);
    final winFraction =
        (clipLength.inMilliseconds / totalMs).clamp(.08, 1.0).toDouble();
    final startFraction = widget.start.inMilliseconds / totalMs;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
              '${tr('Başlangıç')} ${videoTime(widget.start)} → ${videoTime(end)}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        if (widget.previewPath != null)
          IconButton(
              tooltip: tr('Önizle'),
              visualDensity: VisualDensity.compact,
              onPressed: widget.enabled ? togglePreview : null,
              icon: Icon(
                  playing ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
                  color: purple)),
      ]),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (c, box) {
        final w = box.maxWidth - 16;
        final left = 8 + startFraction * w;
        final width = winFraction * w;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate:
              widget.enabled ? (d) => _drag(d.delta.dx, w) : null,
          onTapUp: widget.enabled
              ? (d) => _drag(d.localPosition.dx - (left + width / 2), w)
              : null,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
                color: const Color(0xFF1B1C25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30253F))),
            child: Stack(children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < bars.length; i++)
                          Expanded(
                              child: Center(
                                  child: Container(
                            width: 3,
                            height: 38 * bars[i],
                            decoration: BoxDecoration(
                                color: (i + .5) / bars.length >= startFraction &&
                                        (i + .5) / bars.length <=
                                            startFraction + winFraction
                                    ? Colors.white
                                    : Colors.white30,
                                borderRadius: BorderRadius.circular(2)),
                          ))),
                      ]),
                ),
              ),
              Positioned(
                left: left.clamp(0, box.maxWidth - width),
                top: 3,
                bottom: 3,
                width: width,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                        color: purple.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < 2; i++)
                            Container(
                                width: 4,
                                height: 22,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2))),
                        ]),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    ]);
  }
}
