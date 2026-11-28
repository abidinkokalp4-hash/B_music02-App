import 'package:flutter/services.dart';
import '../profile/extras_screens.dart';
import '../extras/song_letter_screen.dart' show openFeatureLink;
import '../../core/platform/feature_bridge.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_text.dart';
import '../../core/platform/device_controls.dart';
import '../../core/services/announcements.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/player_preferences.dart';
import '../../core/services/push_notifications.dart';
import '../alarm/alarm_screen.dart';
import '../profile/announcements_screen.dart';
import '../profile/player_settings_screen.dart';

import 'global_mini_player.dart';
import 'full_player_screen.dart';
import 'library_screen.dart';
import 'local_video_screen.dart';
import 'music_home_screen.dart';
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
    final savedTab =
        PlayerPreferences.instance.number('startTab', 0).toInt().clamp(0, 4);
    index = savedTab == 4 ? 5 : savedTab;
    pages[index] = page(index);
    DeviceControls.channel.setMethodCallHandler((call) async {
      if (call.method == 'mediaAvailable') await openIncoming();
      if (call.method == 'linkAvailable') await openLink();
      if (call.method == 'announcementTapped') await openAnnouncement();
      if (call.method == 'announcementsChanged') {
        await AnnouncementService.instance.loadCached();
      }
    });
    pushTaps =
        AnnouncementService.instance.taps.listen((_) => openAnnouncement());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      openIncoming();
      unawaited(openLink());
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

  /// bmusic://mektup/<id> (şarkı mektubu) and bmusic://liste?d=... (QR liste).
  Future<void> openLink() async {
    final link = await FeatureBridge.takeLink();
    if (link == null || !mounted) return;
    await openFeatureLink(context, link);
  }

  /// A tapped announcement notification opens the in-app list at that entry,
  /// and its https link (if any) in the browser on top of it.
  Future<void> openAnnouncement() async {
    final service = AnnouncementService.instance;
    final id = await service.takeTap();
    if (id == null || !mounted) return;
    await service.loadCached();
    unawaited(service.check(force: true));
    if (!mounted) return;
    final route = Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => AnnouncementsScreen(highlight: id)));
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
      final data = await DeviceControls.channel
          .invokeMapMethod<String, dynamic>('takeMedia');
      if (data == null || !mounted) return;
      final uri = data['uri'] as String;
      final title = data['title'] as String? ?? 'Medya';
      final mime = data['mime'] as String? ?? '';
      final video = mime.startsWith('video/') ||
          RegExp(r'\.(mpg|mpeg|mp4|mkv|avi|mov|webm|vob|ts|3gp)$',
                  caseSensitive: false)
              .hasMatch(title);
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (video) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    LocalVideoPlayerScreen(uri: uri, title: title)));
      } else {
        await LocalMusicService.instance.playExternal(uri, title);
        if (mounted) openFullPlayer(context);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                AppText('Dosya açılamadı. Dosya erişimini kontrol edin.')));
    } finally {
      openingIncoming = false;
    }
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
        4 => const AlarmScreen(),
        _ => const PlayerSettingsScreen(),
      };

  Future<void> more() async {
    final scheme = Theme.of(context).colorScheme;
    Widget option(BuildContext c, int target, IconData icon, String title,
            String subtitle) =>
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: scheme.primary)),
          title: AppText(title,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: AppText(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.pop(c, target),
        );
    final target = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (c) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              option(
                  c, 4, Icons.alarm_rounded, 'Alarm', 'Sevdiğin şarkıyla uyan'),
              option(c, 5, Icons.settings_outlined, 'Ayarlar',
                  'Genel, oynatma, bildirimler ve daha fazlası'),
              const SizedBox(height: 12),
            ])));
    if (target != null && mounted) select(target);
  }

  DateTime? exitRequested;
  void backFromTab() {
    final now = DateTime.now();
    if (index == 0 &&
        exitRequested != null &&
        now.difference(exitRequested!) < const Duration(seconds: 2)) {
      exitRequested = null;
      SystemNavigator.pop();
      return;
    }
    select(0);
    exitRequested = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          duration: Duration(seconds: 2),
          content: AppText('Çıkmak için tekrar dokunun')));
  }

  void select(int i) {
    if (i == index) return;
    exitRequested = null;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      index = i;
      pages.putIfAbsent(i, () => page(i));
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) backFromTab();
        },
        child: Scaffold(
          extendBody: true,
          body: IndexedStack(
              index: index,
              children:
                  List.generate(6, (i) => pages[i] ?? const SizedBox.shrink())),
          bottomNavigationBar:
              Column(mainAxisSize: MainAxisSize.min, children: [
            // Semi-transparent mini player above the tab bar (auto-hides to a handle).
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: GlobalMiniPlayer(onOpenMusic: () => select(1))),
            SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Material(
                    color: scheme.surface,
                    shape:
                        StadiumBorder(side: BorderSide(color: scheme.outline)),
                    child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                            children: List.generate(items.length, (i) {
                          final selected = i == index || (i == 4 && index >= 4);
                          final ink = selected
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant;
                          return Expanded(
                              flex: selected ? 23 : 10,
                              child: Semantics(
                                  button: true,
                                  selected: selected,
                                  label: tr(items[i].$3),
                                  child: ExcludeSemantics(
                                      child: Material(
                                          color: selected
                                              ? scheme.primary
                                              : Colors.transparent,
                                          shape: const StadiumBorder(),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                              onTap: () =>
                                                  i == 4 ? more() : select(i),
                                              child: SizedBox(
                                                  height: 48,
                                                  child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                            selected
                                                                ? items[i].$2
                                                                : items[i].$1,
                                                            color: ink,
                                                            size: 22),
                                                        if (selected) ...[
                                                          const SizedBox(
                                                              width: 5),
                                                          Flexible(
                                                              child: AppText(
                                                                  items[i].$3,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: TextStyle(
                                                                      color:
                                                                          ink,
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700))),
                                                        ],
                                                      ])))))));
                        }))))),
          ]),
        ));
  }
}
