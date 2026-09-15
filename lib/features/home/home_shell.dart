import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/device_controls.dart';
import '../../core/services/player_preferences.dart';
import '../profile/player_settings_screen.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';
import 'global_mini_player.dart';
import 'library_screen.dart';
import 'local_video_screen.dart';
import 'music_home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.onRequestLogin,
    required this.onSignOut,
  });
  final Future<void> Function() onRequestLogin;
  final Future<void> Function() onSignOut;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = PlayerPreferences.instance
        .number("startTab", 0)
        .toInt()
        .clamp(0, 4);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(DeviceControls.immersive());
    } else if (state == AppLifecycleState.paused &&
        !PlayerPreferences.instance.flag("background")) {
      unawaited(LocalMusicService.instance.pause());
    }
  }

  int _index = 0;
  int _homeRevision = 0;
  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      if (i == 0) _homeRevision++;
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
    const PlayerSettingsScreen(),
  ];
  static const items = [
    _DockItem(Icons.home_rounded, 'Ana Sayfa'),
    _DockItem(Icons.music_note_rounded, 'Müzik'),
    _DockItem(Icons.smart_display_rounded, 'Video'),
    _DockItem(Icons.playlist_play_rounded, 'Listeler'),
    _DockItem(Icons.settings_rounded, 'Ayarlar'),
  ];
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Theme.of(c).scaffoldBackgroundColor,
    extendBody: true,
    body: IndexedStack(index: _index, children: _screens()),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GlobalMiniPlayer(onOpenMusic: () => _select(1)),
          ),
          Container(
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFF090A12),
              border: Border(top: BorderSide(color: Color(0xFF242637))),
            ),
            child: Row(
              children: List.generate(
                items.length,
                (i) => Expanded(
                  child: _DockButton(
                    item: items[i],
                    selected: i == _index,
                    onTap: () => _select(i),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlaylistsHub extends StatefulWidget {
  const _PlaylistsHub();
  @override
  State<_PlaylistsHub> createState() => _PlaylistsHubState();
}

class _PlaylistsHubState extends State<_PlaylistsHub> {
  final music = LocalMusicService.instance;
  Future<void> add() async {
    final x = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yeni Liste'),
        content: TextField(
          controller: x,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Liste adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, x.text.trim()),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    x.dispose();
    if (name != null && name.isNotEmpty) {
      await music.createPlaylist(name);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Theme.of(c).scaffoldBackgroundColor,
    appBar: AppBar(
      title: const Text('Listelerim'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: add,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Yeni Liste'),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 130),
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                Icons.favorite_rounded,
                'Favoriler',
                '${music.favoriteSongs.length} şarkı',
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _Stat(Icons.history_rounded, 'Son Dinlenenler', 'Geçmiş'),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: _Stat(Icons.bar_chart_rounded, 'En Çok', 'Dinlenenler'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Çalma Listelerim',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (music.playlists.isEmpty)
          const _EmptyList()
        else
          ...music.playlists.entries.map(
            (e) => _PlaylistTile(name: e.key, count: e.value.length),
          ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.title, this.sub);
  final IconData icon;
  final String title, sub;
  @override
  Widget build(BuildContext c) => Container(
    height: 112,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.neonPink, size: 27),
        const Spacer(),
        Text(
          title,
          maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        Text(
          sub,
          maxLines: 1,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    ),
  );
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.name, required this.count});
  final String name;
  final int count;
  @override
  Widget build(BuildContext c) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 4),
    leading: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4BB8), Color(0xFF6C2BFF)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.queue_music_rounded),
    ),
    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text('$count şarkı'),
    trailing: const Icon(Icons.more_vert_rounded),
  );
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Column(
      children: [
        Icon(Icons.playlist_add_rounded, size: 40, color: AppColors.neonPurple),
        SizedBox(height: 8),
        Text(
          'İlk çalma listeni oluştur',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(
          'Şarkılarını kendi listelerinde düzenle',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    ),
  );
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _DockItem item;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) {
    final col = selected ? AppColors.neonPink : const Color(0xFF8C8E9F);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: col, size: 28),
          const SizedBox(height: 5),
          Text(
            item.label,
            maxLines: 1,
            style: TextStyle(
              color: col,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockItem {
  const _DockItem(this.icon, this.label);
  final IconData icon;
  final String label;
}
