import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'global_mini_player.dart';
import 'library_screen.dart';
import 'local_video_screen.dart';
import 'music_home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onRequestLogin, required this.onSignOut});
  final Future<void> Function() onRequestLogin;
  final Future<void> Function() onSignOut;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _homeRevision = 0;

  void _select(int index) {
    if (!mounted || index == _index) return;
    setState(() {
      _index = index;
      if (index == 0) _homeRevision++;
    });
  }

  List<Widget> _screens() => [
        MusicHomeScreen(
          key: ValueKey(_homeRevision),
          onOpenMusic: () => _select(1),
          onOpenDiscover: () => _select(1),
          onRequestLogin: widget.onRequestLogin,
        ),
        const LibraryScreen(),
        const LocalVideoScreen(),
        const _PlaylistsHub(),
        _LocalSettings(onSignOut: widget.onSignOut),
      ];

  static const _items = <_DockItem>[
    _DockItem(Icons.home_rounded, 'Ana Sayfa'),
    _DockItem(Icons.library_music_rounded, 'Müzik'),
    _DockItem(Icons.video_library_rounded, 'Video'),
    _DockItem(Icons.queue_music_rounded, 'Listeler'),
    _DockItem(Icons.settings_rounded, 'Ayarlar'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: IndexedStack(index: _index, children: _screens()),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GlobalMiniPlayer(onOpenMusic: () => _select(1)),
            ),
            Container(
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF080914),
                border: Border(top: BorderSide(color: Color(0xFF202236), width: .8)),
              ),
              child: Row(
                children: List.generate(
                  _items.length,
                  (i) => Expanded(child: _DockButton(item: _items[i], selected: i == _index, onTap: () => _select(i))),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _PlaylistsHub extends StatelessWidget {
  const _PlaylistsHub();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, elevation: 0, title: const Text('Listeler', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: const [
            _HubTile(Icons.favorite_rounded, 'Favoriler', 'Beğendiğin şarkılar'),
            _HubTile(Icons.history_rounded, 'Son Dinlenenler', 'En son çaldığın müzikler'),
            _HubTile(Icons.trending_up_rounded, 'En Çok Dinlenenler', 'Dinleme alışkanlıklarına göre'),
            _HubTile(Icons.playlist_add_rounded, 'Çalma Listelerim', 'Kendi listelerini oluştur ve düzenle'),
          ],
        ),
      );
}

class _HubTile extends StatelessWidget {
  const _HubTile(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFF111322), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF25283A))),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.neonPurple.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppColors.neonPurple)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class _LocalSettings extends StatelessWidget {
  const _LocalSettings({required this.onSignOut});
  final Future<void> Function() onSignOut;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, elevation: 0, title: const Text('Ayarlar', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [AppColors.neonPurple.withValues(alpha: .25), AppColors.neonPink.withValues(alpha: .12)])),
            child: Row(children: [
              ClipOval(child: Image.asset('assets/images/b_music02_logo.png', width: 58, height: 58, fit: BoxFit.cover)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('B_music02', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('Yerel müzik ve video oynatıcı', style: TextStyle(color: Colors.white60))])),
            ]),
          ),
          const SizedBox(height: 18),
          const _HubTile(Icons.notifications_active_rounded, 'Medya bildirimi', 'Kilit ekranı ve bildirim kontrolleri'),
          const _HubTile(Icons.storage_rounded, 'Cihaz medyası', 'Müzik ve videolar telefonda kalır'),
          const _HubTile(Icons.timer_rounded, 'Uyku zamanlayıcısı', 'Müziği belirlediğin sürede durdur'),
        ]),
      );
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.item, required this.selected, required this.onTap});
  final _DockItem item;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.neonPurple : const Color(0xFF9395A7);
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(duration: const Duration(milliseconds: 180), width: selected ? 36 : 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? AppColors.neonPurple.withValues(alpha: .14) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Icon(item.icon, size: 22, color: color)),
        const SizedBox(height: 3),
        Text(item.label, maxLines: 1, style: TextStyle(color: color, fontSize: 8.8, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
      ]),
    );
  }
}

class _DockItem {
  const _DockItem(this.icon, this.label);
  final IconData icon;
  final String label;
}
