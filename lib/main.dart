import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/local_music_service.dart';
import 'core/services/music_insights_service.dart';
import 'core/services/session_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgymutovzgtfexbcmzgj.supabase.co',
    anonKey: 'sb_publishable_BtphNNOgn_r46u_JVs1i7A_OOZXYckw',
  );
  await SessionPreferences.enforceAtStartup();

  await LocalMusicService.instance.initialize();

  final AudioHandler audioHandler = await AudioService.init(
    builder: () => LocalMusicService.instance.createHandler(),
    config: AudioServiceConfig(
      // Keep a fresh media channel so devices that cached the older channel
      // configuration receive the corrected playback notification settings.
      androidNotificationChannelId: 'com.example.b_music02.media.playback.v6',
      androidNotificationChannelName: 'B_music02 Müzik',
      androidNotificationChannelDescription:
          'Çalan müzik ve kilit ekranı medya kontrolleri',
      androidNotificationIcon: 'drawable/ic_stat_music',
      androidNotificationOngoing: true,
      androidNotificationClickStartsActivity: true,
      // Keeping the foreground service alive while paused prevents Android 14+
      // devices from removing the media notification/session between play and
      // pause transitions.
      androidStopForegroundOnPause: false,
      androidResumeOnClick: true,
    ),
  );
  LocalMusicService.instance.attachAudioHandler(audioHandler);

  await MusicInsightsService.instance.initialize();

  final themeController = ThemeController();
  await themeController.load();

  runApp(BMusicApp(themeController: themeController));
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
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  late final Animation<double> _glow;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.72));
    _scale = Tween<double>(begin: 0.58, end: 1).animate(
      CurvedAnimation(parent: _intro, curve: Curves.elasticOut),
    );
    _rotation = Tween<double>(begin: -0.04, end: 0).animate(
      CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
    );
    _glow = Tween<double>(begin: 18, end: 38).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    _intro.forward();
    _timer = Timer(const Duration(milliseconds: 1800), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.03, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (context, _) {
              return Center(
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPurple.withValues(alpha: 0.20),
                        blurRadius: _glow.value * 2.2,
                        spreadRadius: _glow.value * 0.38,
                      ),
                      BoxShadow(
                        color: AppColors.neonPink.withValues(alpha: 0.13),
                        blurRadius: _glow.value * 2.8,
                        spreadRadius: _glow.value * 0.25,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: RotationTransition(
                  turns: _rotation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.neonPurple, AppColors.neonPink],
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/b_music02_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'B_music02',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'MÜZİK HER YERDE',
                        style: TextStyle(
                          color: AppColors.neonPurple,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
