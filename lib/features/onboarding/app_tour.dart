import 'package:flutter/material.dart';
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
  final pages = PageController();
  int index = 0;
  bool saving = false;
  static const slides = [
    (Icons.library_music_rounded, 'Arşivin, senin ritmin', 'Telefonundaki müzik ve videolar tek yerde. İnternet veya hesap gerekmez.'),
    (Icons.swipe_rounded, 'Bir hareketle kontrol', 'Albüm kapağını sağa veya sola kaydırarak şarkı değiştir. Üst başlığı aşağı çekerek oynatıcıyı küçült.'),
    (Icons.queue_music_rounded, 'Sırayı sen belirle', 'Parçaları sürükle, sıradaki şarkıyı seç ve çalma sırasını listeye kaydet. A–B ile sevdiğin bölümü tekrarla.'),
    (Icons.video_collection_rounded, 'Videolarına yeni bir bakış', 'Akışta yukarı kaydırarak sonraki videoya geç. Video paylaş, altyazı aç veya bir kareyi fotoğraf olarak kaydet.'),
    (Icons.folder_open_rounded, 'Dosyanı aç, keyfine bak', 'Dosya yöneticisinde “Şununla aç” menüsünden B_music02’yi seç. Medya izinleri, arşivine erişebilmen için sonraki adımda açıklanacak.'),
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
  void dispose() { pages.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => Scaffold(body: SafeArea(child: Column(children: [
    Align(alignment: Alignment.topRight, child: TextButton(onPressed: saving ? null : finish, child: const Text('Atla'))),
    Expanded(child: PageView.builder(controller: pages, itemCount: slides.length,
      onPageChanged: (i) => setState(() => index = i), itemBuilder: (c, i) {
        final slide = slides[i];
        return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: Column(children: [
          Container(padding: const EdgeInsets.all(36), decoration: BoxDecoration(shape: BoxShape.circle,
            color: Theme.of(c).colorScheme.primary.withValues(alpha: .15)),
            child: Icon(slide.$1, size: 84, color: Theme.of(c).colorScheme.primary)),
          const SizedBox(height: 36), Text(slide.$2, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20), Text(slide.$3, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.6)),
        ])));
      })),
    Text('${index + 1} / ${slides.length}'),
    Padding(padding: const EdgeInsets.all(24), child: SizedBox(width: double.infinity,
      child: FilledButton(onPressed: saving ? null : () {
        if (index == slides.length - 1) { finish(); }
        else { pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut); }
      }, child: Text(index == slides.length - 1 ? 'Başla' : 'Devam')))),
  ])));
}
