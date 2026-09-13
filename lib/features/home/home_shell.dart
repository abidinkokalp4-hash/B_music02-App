import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../profile/music_settings_screen.dart';
import 'discover_screen.dart';
import 'global_mini_player.dart';
import 'local_music_screen.dart';
import 'music_home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) {
    if (!mounted || index == _index) return;
    setState(() => _index = index);
  }

  late final List<Widget> _screens = [
    MusicHomeScreen(
      onOpenMusic: () => _select(1),
      onOpenDiscover: () => _select(2),
    ),
    const LocalMusicScreen(),
    const DiscoverScreen(),
    const MusicSettingsScreen(),
  ];

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Ana Sayfa',
    ),
    NavigationDestination(
      icon: Icon(Icons.library_music_outlined),
      selectedIcon: Icon(Icons.library_music_rounded),
      label: 'Müziklerim',
    ),
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore_rounded),
      label: 'Keşfet',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: 'Ayarlar',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlobalMiniPlayer(onOpenMusic: () => _select(1)),
            NavigationBar(
              selectedIndex: _index,
              destinations: _destinations,
              onDestinationSelected: _select,
              indicatorColor: AppColors.gold.withValues(alpha: 0.18),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            ),
          ],
        ),
      ),
    );
  }
}
