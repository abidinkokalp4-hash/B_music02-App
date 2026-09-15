import '../../core/l10n/app_text.dart';

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
import 'playlists_hub.dart';

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
    const PlaylistsHub(),
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
            decoration: BoxDecoration(
              color: Theme.of(c).scaffoldBackgroundColor,
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
    final col = selected
        ? Theme.of(c).colorScheme.primary
        : Theme.of(c).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: col, size: 28),
          const SizedBox(height: 5),
          AppText(
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
