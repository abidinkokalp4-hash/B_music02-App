import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'core/services/local_music_service.dart';
import 'core/services/music_insights_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/music_permissions_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalMusicService.instance.initialize();

  final AudioHandler audioHandler = await AudioService.init(
    builder: () => LocalMusicService.instance.createHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.example.b_music02.media.playback.v5',
      androidNotificationChannelName: 'B_music02 Müzik',
      androidNotificationChannelDescription:
          'Çalan müzik ve kilit ekranı medya kontrolleri',
      androidNotificationIcon: 'drawable/ic_stat_music',
      androidNotificationOngoing: true,
      androidNotificationClickStartsActivity: true,
      androidStopForegroundOnPause: true,
      androidResumeOnClick: true,
    ),
  );
  LocalMusicService.instance.attachAudioHandler(audioHandler);

  await MusicInsightsService.instance.initialize();

  final themeController = ThemeController();
  await themeController.load();

  runApp(
    BMusicApp(
      themeController: themeController,
    ),
  );
}

class BMusicApp extends StatelessWidget {
  const BMusicApp({
    super.key,
    required this.themeController,
  });

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      controller: themeController,
      child: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'B_music02',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeController.themeMode,
            home: const BMusicSplashScreen(),
          );
        },
      ),
    );
  }
}

class BMusicSplashScreen extends StatefulWidget {
  const BMusicSplashScreen({super.key});

  @override
  State<BMusicSplashScreen> createState() => _BMusicSplashScreenState();
}

class _BMusicSplashScreenState extends State<BMusicSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 1200), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const MusicPermissionGate(
          child: HomeShell(),
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/b_music02_logo.png',
                    width: 132,
                    height: 132,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'B_music02',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Müzik her yerde',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
