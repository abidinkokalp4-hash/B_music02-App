import '../../core/l10n/app_text.dart';
import 'package:flutter/material.dart';
import '../home/widgets/vinyl_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTourGate extends StatefulWidget {
  const AppTourGate({super.key, required this.child});
  final Widget child;
  @override
  State<AppTourGate> createState() => _TourGateState();
}
class _TourGateState extends State<AppTourGate> {
  bool? done;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => done = p.getBool('b_music_tour_v1') ?? false);
    });
  }
  @override
  Widget build(BuildContext c) => done == null
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : done! ? widget.child : AppTour(onDone: () => setState(() => done = true));
}
class AppTour extends StatefulWidget {
  const AppTour({super.key, this.onDone});
  final VoidCallback? onDone;
  @override
  State<AppTour> createState() => _AppTourState();
}
class _AppTourState extends State<AppTour> {
  bool saving = false;
  int page = 0;
  static const slides = [
    ('B Music', 'Tüm müzik ve videoların\ntek uygulamada'),
    ('Müzik & Video', 'Hızlı, güçlü, kullanışlı'),
    ('Senin Medya Dünyan', 'Tamamen senin tarzında'),
  ];
  Future<void> finish() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('b_music_tour_v1', true);
      if (!mounted) return;
      if (widget.onDone != null) { widget.onDone!(); } else { Navigator.pop(context); }
    } finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(children: [
        Align(alignment: Alignment.centerRight, child: TextButton(
          onPressed: saving ? null : finish, child: const AppText('Atla'))),
        Expanded(child: LayoutBuilder(builder: (c, bounds) => SingleChildScrollView(
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: bounds.maxHeight),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              VinylRecord(size: (bounds.maxHeight * .52).clamp(100.0, 230.0).toDouble(),
                cream: true, playing: true),
              const SizedBox(height: 24),
              AppText(slides[page].$1, textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Fraunces', fontStyle: FontStyle.italic,
                  fontSize: 36, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              AppText(slides[page].$2, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
            ]))))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < slides.length; i++)
            IconButton(tooltip: '${i + 1} / ${slides.length}',
              onPressed: () => setState(() => page = i),
              icon: Icon(Icons.circle, size: 10, color: i == page ? scheme.primary : scheme.outline)),
        ]),
        SizedBox(width: double.infinity, child: page == slides.length - 1
          ? FilledButton(onPressed: saving ? null : finish, child: const AppText('Başla'))
          : OutlinedButton(onPressed: () => setState(() => page++), child: const AppText('İleri'))),
      ]))));
  }
}
