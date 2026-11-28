import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/l10n/app_text.dart';
import '../../core/platform/feature_bridge.dart';
import '../../core/services/local_music_service.dart';
import '../home/video_player_controls.dart' show videoTime;

const maxClipLength = Duration(seconds: 30);
Duration initialClip(Duration available) =>
    available < const Duration(seconds: 15)
        ? available
        : const Duration(seconds: 15);

class ClipWindowPicker extends StatefulWidget {
  const ClipWindowPicker(
      {super.key,
      required this.total,
      required this.start,
      required this.length,
      required this.onChanged,
      this.seed = 7,
      this.previewPath,
      this.enabled = true});
  final Duration total, start, length;
  final void Function(Duration start, Duration length) onChanged;
  final int seed;
  final String? previewPath;
  final bool enabled;
  @override
  State<ClipWindowPicker> createState() => _ClipPickerState();
}

class _ClipPickerState extends State<ClipWindowPicker> {
  AudioPlayer? preview;
  Timer? debounce;
  int generation = 0;
  bool playing = false;
  late final bars = pseudoWaveform(widget.seed, 50);
  late int anchor, originalStart, originalEnd, handle;
  int get total => widget.total.inMilliseconds;
  int get start => widget.start.inMilliseconds;
  int get end => start + widget.length.inMilliseconds;
  Future<void> serial = Future.value();

  void stop() {
    generation++;
    debounce?.cancel();
    unawaited(preview?.pause());
    playing = false;
  }

  @override
  void didUpdateWidget(ClipWindowPicker old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && old.enabled) stop();
  }

  @override
  void dispose() {
    stop();
    preview?.dispose();
    super.dispose();
  }

  void listen(int a, int b, {bool immediate = false}) {
    final token = ++generation;
    debounce?.cancel();
    debounce = Timer(Duration(milliseconds: immediate ? 0 : 100), () {
      serial = serial.then((_) async {
        if (!mounted ||
            token != generation ||
            widget.previewPath == null ||
            b <= a) return;
        try {
          if (LocalMusicService.instance.hasPlayer &&
              LocalMusicService.instance.player.playing) {
            await LocalMusicService.instance.pause();
          }
          if (!mounted || token != generation) return;
          final p = preview ??= AudioPlayer(handleInterruptions: false);
          await p.pause();
          final path = widget.previewPath!;
          await p.setAudioSource(ClippingAudioSource(
              child: AudioSource.uri(
                  path.startsWith('file:') || path.startsWith('content:')
                      ? Uri.parse(path)
                      : Uri.file(path)),
              start: Duration(milliseconds: a),
              end: Duration(milliseconds: b)));
          if (!mounted || token != generation) return;
          setState(() => playing = true);
          unawaited(p.play().catchError((Object _) {}).whenComplete(() {
            if (mounted && token == generation) setState(() => playing = false);
          }));
        } catch (_) {
          if (mounted && token == generation) setState(() => playing = false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext c) {
    final accent = Theme.of(c).colorScheme.primary;
    return Column(children: [
      Row(children: [
        Expanded(
            child: Text(
                '${tr("Başlangıç")} ${videoTime(widget.start)} → ${videoTime(widget.start + widget.length)}')),
        Text('${(widget.length.inMilliseconds / 1000).toStringAsFixed(1)} sn'),
        IconButton(
            tooltip: tr('Önizle'),
            onPressed: !widget.enabled || total == 0
                ? null
                : () {
                    if (playing) {
                      setState(stop);
                    } else {
                      listen(start, end, immediate: true);
                    }
                  },
            icon: Icon(playing ? Icons.stop_circle : Icons.play_circle,
                color: accent)),
      ]),
      LayoutBuilder(builder: (c, constraints) {
        final w = constraints.maxWidth;
        final scale = math.max(total, 1);
        int at(double x) => (scale * x / w).round().clamp(0, total);
        void update(double x) {
          final t = at(x), max = maxClipLength.inMilliseconds;
          final min = math.min(250, total);
          int a = originalStart, b = originalEnd;
          if (handle < 0) {
            a = t.clamp(math.max(0, b - max), b - min);
          } else if (handle > 0) {
            b = t.clamp(a + min, math.min(total, a + max));
          } else {
            a = (originalStart + t - anchor)
                .clamp(0, total - (originalEnd - originalStart));
            b = a + originalEnd - originalStart;
          }
          widget.onChanged(
              Duration(milliseconds: a), Duration(milliseconds: b - a));
          listen(a, b);
        }

        final left = start * w / scale, right = end * w / scale;
        return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !widget.enabled || total == 0
                ? null
                : (d) {
                    final a = at(d.localPosition.dx)
                        .clamp(0, total - widget.length.inMilliseconds);
                    widget.onChanged(Duration(milliseconds: a), widget.length);
                    listen(a, a + widget.length.inMilliseconds,
                        immediate: true);
                  },
            onHorizontalDragStart: !widget.enabled || total == 0
                ? null
                : (d) {
                    final x = d.localPosition.dx;
                    originalStart = start;
                    originalEnd = end;
                    anchor = at(x);
                    final reach = math.min(15.0, (right - left) / 3);
                    handle = (x - left).abs() <= reach
                        ? -1
                        : (x - right).abs() <= reach
                            ? 1
                            : 0;
                    if (handle == 0 && (x < left || x > right))
                      anchor = (start + end) ~/ 2;
                  },
            onHorizontalDragUpdate: !widget.enabled || total == 0
                ? null
                : (d) => update(d.localPosition.dx),
            child: Container(
                height: 56,
                decoration: BoxDecoration(
                    color: Theme.of(c).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12)),
                child: Stack(children: [
                  Positioned.fill(
                      child: Row(children: [
                    for (final h in bars)
                      Expanded(
                          child: Center(
                              child: Container(
                                  width: 3,
                                  height: h * 40,
                                  color: Colors.white38)))
                  ])),
                  Positioned(
                      left: left,
                      right: math.max(0, w - right),
                      top: 3,
                      bottom: 3,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: accent.withValues(alpha: .24),
                              border: Border.symmetric(
                                  vertical: BorderSide(color: accent, width: 3),
                                  horizontal: BorderSide(color: accent)),
                              borderRadius: BorderRadius.circular(5)))),
                ])));
      }),
      Slider(
          min: 0,
          max: math.max(1, math.min(total, 30000)).toDouble(),
          value: widget.length.inMilliseconds
              .clamp(0, math.max(1, math.min(total, 30000)))
              .toDouble(),
          semanticFormatterCallback: (v) =>
              '${(v / 1000).toStringAsFixed(1)} sn',
          onChanged: !widget.enabled || total == 0
              ? null
              : (v) {
                  final n = v
                      .round()
                      .clamp(math.min(250, total), math.min(total, 30000));
                  final a = math.min(start, total - n);
                  widget.onChanged(
                      Duration(milliseconds: a), Duration(milliseconds: n));
                  listen(a, a + n);
                }),
    ]);
  }
}
