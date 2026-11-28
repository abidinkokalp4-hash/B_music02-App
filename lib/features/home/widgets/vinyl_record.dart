import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A painted LP with an independently rotating label and a fixed tonearm.
class VinylRecord extends StatefulWidget {
  const VinylRecord({
    super.key,
    required this.size,
    this.playing = false,
    this.tonearm = false,
    this.label = 'B MUSIC',
    this.cream = false,
  });

  final double size;
  final bool playing, tonearm, cream;
  final String label;

  @override
  State<VinylRecord> createState() => _VinylRecordState();
}

class _VinylRecordState extends State<VinylRecord>
    with SingleTickerProviderStateMixin {
  late final spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  void sync() {
    if (widget.playing && !MediaQuery.disableAnimationsOf(context)) {
      if (!spin.isAnimating) spin.repeat();
    } else {
      spin.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(VinylRecord old) {
    super.didUpdateWidget(old);
    sync();
  }

  @override
  void dispose() {
    spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelSize = widget.size * .36;
    final ink = const Color(0xff1a100a);
    final style = TextStyle(
      color: ink,
      fontFamily: 'DM Sans',
      fontSize: labelSize * .085,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    );
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(child: CustomPaint(painter: _Grooves())),
            RotationTransition(
              turns: spin,
              child: Container(
                width: labelSize,
                height: labelSize,
                padding: EdgeInsets.all(labelSize * .1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.cream
                      ? const Color(0xfff2e6d0)
                      : Theme.of(context).colorScheme.primary,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ink.withValues(alpha: .32)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                      ),
                      Icon(Icons.circle, size: labelSize * .11, color: ink),
                      Text('SIDE A', style: style),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.tonearm)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _Tonearm(engaged: widget.playing),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Grooves extends CustomPainter {
  const _Grooves();
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero), r = s.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: r);
    final p = Paint()
      ..shader = const SweepGradient(
        transform: GradientRotation(math.pi / 7),
        colors: [
          Color(0xff100e0d),
          Color(0xff393430),
          Color(0xff110e0d),
          Color(0xff100e0d),
          Color(0xff332e2a),
          Color(0xff100e0d),
        ],
        stops: [0, .12, .23, .49, .64, 1],
      ).createShader(rect);
    c.drawCircle(center, r, p);
    p
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = const Color(0x23f2e6d0);
    for (var groove = r - 2; groove > r * .35; groove -= 3.6) {
      c.drawCircle(center, groove, p);
    }
  }

  @override
  bool shouldRepaint(_Grooves old) => false;
}

class _Tonearm extends CustomPainter {
  const _Tonearm({required this.engaged});
  final bool engaged;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 300);
    c.translate(266, 18);
    final p = Paint()..color = const Color(0xff493c31);
    c.drawCircle(Offset.zero, 15, p);
    c.rotate(engaged ? .25 : .01);
    p
      ..color = const Color(0xffd9cbb3)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset.zero, const Offset(-4, 119), p);
    c.drawLine(const Offset(-4, 119), const Offset(-12, 147), p);
    p.color = const Color(0xffff9a3c);
    c.drawCircle(Offset.zero, 6, p);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-19, 142, 13, 23),
        const Radius.circular(3),
      ),
      p,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_Tonearm old) => old.engaged != engaged;
}
