import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_text.dart';
import '../../core/platform/device_controls.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/player_preferences.dart';
import '../profile/player_settings_screen.dart';

import 'global_mini_player.dart';
import 'library_screen.dart';
import 'local_video_screen.dart';
import 'music_home_screen.dart';
import 'playlists_hub.dart';
import 'youtube_link_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;
  String? shownError;
  final pages = <int, Widget>{};
  static const items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Ana Sayfa'),
    (Icons.music_note_outlined, Icons.music_note_rounded, 'Müzik'),
    (Icons.smart_display_outlined, Icons.smart_display_rounded, 'Video'),
    (Icons.queue_music_outlined, Icons.queue_music_rounded, 'Listeler'),
    (Icons.link_outlined, Icons.link, 'Bağlantı'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Ayarlar'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocalMusicService.instance.addListener(reportPlaybackError);
    final savedTab = PlayerPreferences.instance.number('startTab', 0).toInt().clamp(0, 4);
    index = savedTab == 4 ? 5 : savedTab;
    pages[index] = page(index);
    unawaited(
        LocalMusicService.instance.requestPermissionAndLoad(request: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalMusicService.instance.removeListener(reportPlaybackError);
    super.dispose();
  }

  void reportPlaybackError() {
    final message = LocalMusicService.instance.playbackError;
    if (message == null) {
      shownError = null;
      return;
    }
    if (message == shownError) return;
    shownError = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(DeviceControls.immersive());
      unawaited(LocalMusicService.instance.refresh());
    } else if (state == AppLifecycleState.paused) {
      unawaited(LocalMusicService.instance.savePlaybackCheckpoint());
      if (!PlayerPreferences.instance.flag('background'))
        unawaited(LocalMusicService.instance.pause());
    }
  }

  Widget page(int i) => switch (i) {
        0 => MusicHomeScreen(
            onOpenMusic: () => select(1), onOpenVideo: () => select(2)),
        1 => const LibraryScreen(),
        2 => const LocalVideoScreen(),
        3 => const PlaylistsHub(),
        4 => YouTubeLinkScreen(active: index == 4),
        _ => const PlayerSettingsScreen(),
      };

  void select(int i) {
    if (i == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      index = i;
      pages.putIfAbsent(i, () => page(i));
      if (pages.containsKey(4)) pages[4] = YouTubeLinkScreen(active: i == 4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
          index: index,
          children:
              List.generate(6, (i) => pages[i] ?? const SizedBox.shrink())),
      bottomNavigationBar: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: GlobalMiniPlayer(onOpenMusic: () => select(1))),
                Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 3),
                    child: Row(
                        children: List.generate(6, (i) {
                      final selected = i == index;
                      return Expanded(
                          child: Semantics(
                              selected: selected,
                              button: true,
                              label: items[i].$3,
                              child: InkWell(
                                  onTap: () => select(i),
                                  borderRadius: BorderRadius.circular(18),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 7),
                                      child: Column(children: [
                                        AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            width: 48,
                                            height: 32,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                                color: selected
                                                    ? scheme.primary
                                                        .withValues(alpha: .16)
                                                    : Colors.transparent),
                                            child: Icon(
                                                selected
                                                    ? items[i].$2
                                                    : items[i].$1,
                                                size: 23,
                                                color: selected
                                                    ? scheme.primary
                                                    : scheme.onSurfaceVariant)),
                                        const SizedBox(height: 4),
                                        AppText(items[i].$3,
                                            maxLines: 1,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: selected
                                                    ? scheme.onSurface
                                                    : scheme.onSurfaceVariant,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w500)),
                                      ])))));
                    }))),
              ]))),
    );
  }
}
