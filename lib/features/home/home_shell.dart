import 'dart:ui';

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

  static const _items = <_DockItem>[
    _DockItem(Icons.home_rounded, 'Ana Sayfa'),
    _DockItem(Icons.library_music_rounded, 'Müziklerim'),
    _DockItem(Icons.explore_rounded, 'Keşfet'),
    _DockItem(Icons.tune_rounded, 'Ayarlar'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlobalMiniPlayer(onOpenMusic: () => _select(1)),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  height: 70,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xE60E0E13)
                        : const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: dark ? AppColors.border : const Color(0xFFE1DDE9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? 0.32 : 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: List.generate(
                      _items.length,
                      (i) => Expanded(
                        child: _DockButton(
                          item: _items[i],
                          selected: i == _index,
                          onTap: () => _select(i),
                        ),
                      ),
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.textSecondary : const Color(0xFF746F7C);

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  item.icon,
                  size: 23,
                  color: selected ? AppColors.accentSoft : muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? Theme.of(context).colorScheme.onSurface : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem {
  const _DockItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
