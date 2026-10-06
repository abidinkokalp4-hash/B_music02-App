import 'package:flutter/material.dart';
import '../home/widgets/reference_design.dart';
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
  Widget build(BuildContext c) => Scaffold(body: NightLandscape(child: SafeArea(child: LayoutBuilder(builder: (c, bounds) => SingleChildScrollView(
    child: ConstrainedBox(constraints: BoxConstraints(minHeight: bounds.maxHeight), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: Column(children: [
      Align(alignment: Alignment.topRight, child: TextButton(onPressed: saving ? null : finish, child: const Text('Atla'))),
      SizedBox(height: bounds.maxHeight * .04),
      const BrandLogo(size: 138), const SizedBox(height: 16),
      const Text('B Music', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 4), const Text('Müzik & Video', style: TextStyle(fontSize: 17, color: Colors.white)),
      const SizedBox(height: 28), const Text('Senin Medya Dünyan', style: TextStyle(fontSize: 17, color: Colors.white70)),
      const SizedBox(height: 34),
      for (final item in const <(IconData, String)>[(Icons.video_library_outlined, 'Tüm müzik ve videoların\ntek uygulamada'), (Icons.bolt, 'Hızlı, güçlü, kullanışlı'), (Icons.auto_awesome, 'Tamamen senin tarzında')])
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xFF271139), borderRadius: BorderRadius.circular(11)), child: Icon(item.$1, color: const Color(0xFFC060FF))),
          const SizedBox(width: 14), Expanded(child: Text(item.$2, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))),
        ])),
      const SizedBox(height: 34), GlowButton(label: 'Başla', onTap: saving ? null : finish), const SizedBox(height: 34),
    ]))),
  )))));
}
