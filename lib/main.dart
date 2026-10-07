import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/platform/device_controls.dart';
import 'features/home/widgets/reference_design.dart';
import 'core/platform/media_widget_bridge.dart';

import 'core/services/local_music_service.dart';
import 'core/services/music_insights_service.dart';
import 'core/services/push_notifications.dart';
import 'core/services/telemetry.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemBars);
  await DeviceControls.immersive();
  // Crash reports (Crashlytics) and usage (Analytics); never blocks start-up.
  unawaited(Telemetry.instance.init());
  await LocalMusicService.instance.initialize();
  final AudioHandler h = await AudioService.init(
    builder: () => LocalMusicService.instance.createHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.bmusic.app.media.playback',
      androidNotificationChannelName: 'B Music',
      androidNotificationChannelDescription:
          'Çalan müzik ve kilit ekranı medya kontrolleri',
      androidNotificationIcon: 'drawable/ic_stat_bm',
      androidNotificationOngoing: true,
      androidNotificationClickStartsActivity: true,
      androidStopForegroundOnPause: false,
      androidResumeOnClick: true,
    ),
  );
  AudioService.asyncError.listen((Object error) {
    debugPrint('[B_music02 media error] $error');
  });
  LocalMusicService.instance.attachAudioHandler(h);
  MediaWidgetBridge(h).start();
  await MusicInsightsService.instance.initialize();
  final t = ThemeController();
  await t.load();
  // Instant announcements (FCM); never blocks or breaks start-up.
  unawaited(PushNotifications.instance.init());
  runApp(BMusicApp(themeController: t));
}

class BMusicApp extends StatelessWidget {
  const BMusicApp({super.key, required this.themeController});
  final ThemeController themeController;
  @override
  Widget build(BuildContext c) => ThemeControllerScope(
        controller: themeController,
        child: AnimatedBuilder(
          animation: themeController,
          builder: (c, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'B Music',
            theme: themeController.apply(AppTheme.light()),
            darkTheme: themeController.apply(AppTheme.dark()),
            themeMode: themeController.themeMode,
            // Dark navigation bar with light buttons on every screen.
            builder: (c, child) => AnnotatedRegion<SystemUiOverlayStyle>(
                value: AppTheme.systemBars, child: child ?? const SizedBox()),
            home: const BMusicSplashScreen(),
          ),
        ),
      );
}

class BMusicSplashScreen extends StatefulWidget {
  const BMusicSplashScreen({super.key});
  @override
  State<BMusicSplashScreen> createState() => _Splash();
}

class _Splash extends State<BMusicSplashScreen> with TickerProviderStateMixin {
  late final AnimationController intro, pulse;
  late final Animation<double> fade, scale, glow;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    fade = CurvedAnimation(parent: intro, curve: Curves.easeOut);
    scale = Tween<double>(
      begin: .58,
      end: 1,
    ).animate(CurvedAnimation(parent: intro, curve: Curves.elasticOut));
    glow = Tween<double>(begin: 18, end: 38).animate(pulse);
    intro.forward();
    timer = Timer(const Duration(milliseconds: 900), go);
  }

  void go() {
    if (mounted)
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
  }

  @override
  void dispose() {
    timer?.cancel();
    intro.dispose();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const NightLandscape(child: SizedBox.expand()),
            AnimatedBuilder(
              animation: glow,
              builder: (c, _) => Center(
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPurple.withValues(alpha: .2),
                        blurRadius: glow.value * 2.2,
                        spreadRadius: glow.value * .38,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandLogo(size: 150),
                      const SizedBox(height: 22),
                      const Text(
                        'B Music',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Müzik & Video • Senin Medya Dünyan',
                        style: TextStyle(
                          color: AppColors.neonPurple,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
