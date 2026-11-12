import 'package:flutter/material.dart';

import '../../features/home/widgets/reference_design.dart';
import '../l10n/app_text.dart';

/// Visual tokens for the midnight-navy → violet aurora redesign.
/// Frosted look is painted with translucent fills (no BackdropFilter on
/// lists) so scrolling stays light.
class Aurora {
  Aurora._();

  static const midnight = Color(0xFF07051A);
  static const navy = Color(0xFF120B2E);
  static const violet = Color(0xFF3A1768);
  static const electric = Color(0xFFB65CFF);
  static const electricDeep = Color(0xFF7A28E8);
  static const coral = Color(0xFFFF6B7A);
  static const coralSoft = Color(0xFFFF8A6B);
  static const glassFill = Color(0x221C1238);
  static const glassFillStrong = Color(0xCC160E30);
  static const glassBorder = Color(0x33E0C8FF);
  static const textMuted = Color(0xFFB8B0D0);

  static const darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A061C), Color(0xFF161038), Color(0xFF2A1058), Color(0xFF0C0818)],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF4F0FF), Color(0xFFE8D8FF), Color(0xFFF7F4FC)],
  );

  static BoxDecoration glass({
    double radius = 22,
    Color? fill,
    Color? border,
    bool glow = false,
  }) =>
      BoxDecoration(
        color: fill ?? glassFillStrong,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? glassBorder),
        boxShadow: glow
            ? const [BoxShadow(color: Color(0x554C00D4), blurRadius: 22, offset: Offset(0, 8))]
            : const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
      );

  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 6 && hour < 12) return 'Günaydın';
    if (hour >= 12 && hour < 18) return 'İyi günler';
    if (hour >= 18 && hour < 22) return 'İyi akşamlar';
    return 'İyi geceler';
  }

  static String greetingSubtitle([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 6 && hour < 18) return 'Müzikle güzel bir gün başlasın.';
    return 'Müzikle güzel bir akşam geçir.';
  }

  static String listeningLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return tf('{0}s {1}dk', [h, m]);
    return tf('{0}dk', [m]);
  }
}

/// Shared aurora backdrop: a cheap static gradient plus two soft blobs.
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: dark ? Aurora.darkGradient : Aurora.lightGradient),
      child: CustomPaint(
        painter: _AuroraBlobs(dark),
        child: child,
      ),
    );
  }
}

class _AuroraBlobs extends CustomPainter {
  _AuroraBlobs(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (!dark) {
      canvas.drawCircle(
        Offset(size.width * .85, size.height * .12),
        size.width * .45,
        Paint()..color = const Color(0x33B65CFF),
      );
      return;
    }
    canvas.drawCircle(
      Offset(size.width * .85, size.height * .08),
      size.width * .7,
      Paint()..color = const Color(0x407A28E8),
    );
    canvas.drawCircle(
      Offset(size.width * -.05, size.height * .45),
      size.width * .55,
      Paint()..color = const Color(0x3324C9DF),
    );
    canvas.drawCircle(
      Offset(size.width * .6, size.height * .85),
      size.width * .5,
      Paint()..color = const Color(0x33FF4BB8),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraBlobs old) => old.dark != dark;
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.color,
    this.glow = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final deco = Aurora.glass(
      radius: radius,
      fill: color ??
          (light ? Colors.white.withValues(alpha: .86) : Aurora.glassFillStrong),
      border: light ? const Color(0x337A28E8) : Aurora.glassBorder,
      glow: glow,
    );
    final body = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: deco,
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: body,
              ),
            ),
    );
  }
}

class AuroraSectionHeader extends StatelessWidget {
  const AuroraSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.actionLabel = 'Tümünü gör',
  });
  final String title;
  final VoidCallback? action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Row(children: [
          Expanded(
              child: AppText(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (action != null)
            InkWell(
              onTap: action,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(children: [
                  AppText(actionLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC9A6FF))),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFC9A6FF)),
                ]),
              ),
            ),
        ]),
      );
}

/// Brand row used at the top of tab pages: BM logo + title.
class AuroraBrandBar extends StatelessWidget {
  const AuroraBrandBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(children: [
        const BrandLogo(size: 34),
        const SizedBox(width: 8),
        const AppText('B Music',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -.2)),
        const Spacer(),
        ...actions,
      ]);
}

class CoralButton extends StatelessWidget {
  const CoralButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
        color: Aurora.coral,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 18, vertical: compact ? 8 : 11),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: compact ? 16 : 18),
                const SizedBox(width: 6),
              ],
              AppText(label,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 13 : 14)),
            ]),
          ),
        ),
      );
}

/// Transparent scaffold so the shell aurora shows through every tab.
ThemeData auroraPageTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(scaffoldBackgroundColor: Colors.transparent);
}

Color auroraSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
        ? Colors.white.withValues(alpha: .9)
        : Aurora.glassFillStrong;
