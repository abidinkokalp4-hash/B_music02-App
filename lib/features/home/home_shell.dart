import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_text.dart';
import '../../core/theme/aurora.dart';
import '../../core/platform/device_controls.dart';
import '../../core/services/announcements.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/video_library.dart';
import '../../core/services/player_preferences.dart';
import '../../core/services/push_notifications.dart';
import '../profile/announcements_screen.dart';
import '../profile/extras_screens.dart';

import 'global_mini_player.dart';
import 'full_player_screen.dart';
import 'library_screen.dart';
import 'local_video_screen.dart';
import 'music_home_screen.dart';
import 'more_hub.dart';
import 'playlists_hub.dart';
import 'update_prompt.dart';

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
    (Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'Daha Fazla'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocalMusicService.instance.addListener(reportPlaybackError);
    final savedTab = PlayerPreferences.instance.number('startTab', 0).toInt().clamp(0, 4);
    index = savedTab;
    pages[index] = page(index);
    DeviceControls.channel.setMethodCallHandler((call) async {
      if (call.method == 'mediaAvailable') await openIncoming();
      if (call.method == 'announcementTapped') await openAnnouncement();
      if (call.method == 'announcementsChanged') {
        await AnnouncementService.instance.loadCached();
      }
    });
    pushTaps = AnnouncementService.instance.taps.listen((_) => openAnnouncement());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      openIncoming();
      await PushNotifications.instance.init();
      unawaited(openAnnouncement());
      unawaited(AnnouncementService.instance.check(force: true));
      unawaited(PushNotifications.instance.requestPermissionOnce());
      // GitHub updater (APK installs only); a few seconds after start-up.
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) unawaited(showFeatureTipsOnce(context));
      });
      Timer(const Duration(seconds: 4), () {
        if (mounted) unawaited(UpdatePrompt.checkOnStart(context));
      });
    });
    unawaited(
        LocalMusicService.instance.requestPermissionAndLoad(request: false));
  }

  StreamSubscription<String>? pushTaps;

  /// A tapped announcement notification opens the in-app list at that entry,
  /// and its https link (if any) in the browser on top of it.
  Future<void> openAnnouncement() async {
    final service = AnnouncementService.instance;
    final id = await service.takeTap();
    if (id == null || !mounted) return;
    await service.loadCached();
    unawaited(service.check(force: true));
    if (!mounted) return;
    final route = Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => AnnouncementsScreen(highlight: id)));
    final url = service.byId(id)?.url;
    if (url != null) {
      unawaited(launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
          .catchError((Object _) => false));
    }
    await route;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocalMusicService.instance.removeListener(reportPlaybackError);
    DeviceControls.channel.setMethodCallHandler(null);
    pushTaps?.cancel();
    super.dispose();
  }

  bool openingIncoming = false;
  Future<void> openIncoming() async {
    if (openingIncoming || !mounted) return;
    openingIncoming = true;
    try {
      final data = await DeviceControls.channel.invokeMapMethod<String, dynamic>('takeMedia');
      if (data == null || !mounted) return;
      final uri = data['uri'] as String;
      final title = data['title'] as String? ?? 'Medya';
      final mime = data['mime'] as String? ?? '';
      final video = mime.startsWith('video/') || RegExp(r'\.(mpg|mpeg|mp4|mkv|avi|mov|webm|vob|ts|3gp)$', caseSensitive: false).hasMatch(title);
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (video) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LocalVideoPlayerScreen(uri: uri, title: title)));
      } else {
        await LocalMusicService.instance.playExternal(uri, title);
        if (mounted) openFullPlayer(context);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AppText('Dosya açılamadı. Dosya erişimini kontrol edin.')));
    } finally { openingIncoming = false; }
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
            .showSnackBar(SnackBar(content: AppText(message)));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(DeviceControls.immersive());
      unawaited(AnnouncementService.instance.check());
      unawaited(LocalMusicService.instance.refresh());
      unawaited(VideoLibrary.instance.recheckAccess());
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
        _ => const MoreHub(),
      };

  void select(int i) {
    if (i == index) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      index = i;
      pages.putIfAbsent(i, () => page(i));
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    return AuroraBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(
            index: index,
            children:
                List.generate(5, (i) => pages[i] ?? const SizedBox.shrink())),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          // Semi-transparent mini player above the tab bar (auto-hides to a handle).
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: GlobalMiniPlayer(onOpenMusic: () => select(1))),
          SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: light
                              ? Colors.white.withValues(alpha: .92)
                              : const Color(0xE6150B2E),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                              color: light
                                  ? const Color(0x337A28E8)
                                  : Aurora.glassBorder),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 18,
                                offset: Offset(0, 6))
                          ]),
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                          child: Row(
                              children: List.generate(5, (i) {
                            final selected = i == index;
                            return Expanded(
                                child: Semantics(
                                    selected: selected,
                                    button: true,
                                    label: items[i].$3,
                                    child: InkWell(
                                        onTap: () => select(i),
                                        borderRadius: BorderRadius.circular(24),
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 7),
                                            child: Column(children: [
                                              Icon(
                                                  selected
                                                      ? items[i].$2
                                                      : items[i].$1,
                                                  size: 23,
                                                  color: selected
                                                      ? Aurora.electric
                                                      : scheme.onSurfaceVariant),
                                              const SizedBox(height: 3),
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
                          })))))),
        ]),
      ),
    );
  }
}
