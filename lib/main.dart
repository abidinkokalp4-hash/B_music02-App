import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/local_music_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalMusicService.instance.initialize();

  await AudioService.init(
    builder: () => LocalMusicService.instance.createHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.b_music02.audio.v2',
      androidNotificationChannelName: 'B_music02 Müzik',
      androidNotificationOngoing: true,
      androidNotificationClickStartsActivity: true,
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'drawable/ic_stat_music',
    ),
  );

  await Supabase.initialize(
    url: 'https://zgymutovzgtfexbcmzgj.supabase.co',
    anonKey: 'sb_publishable_BtphNNOgn_r46u_JVs1i7A_OOZXYckw',
  );

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
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _glowController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _textAnimation;
  late final Animation<double> _glowAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
      ),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.18, end: 0.55).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();
    _glowController.repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });

    _timer = Timer(
      const Duration(milliseconds: 2800),
      _goNext,
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  void _goNext() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const AuthGate();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.75,
                      colors: [
                        const Color(0xFFD4AF57).withOpacity(
                          _glowAnimation.value * 0.18,
                        ),
                        Colors.black,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 175,
                          height: 175,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF57).withOpacity(
                                  _glowAnimation.value,
                                ),
                                blurRadius: 45,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/b_music02_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                FadeTransition(
                  opacity: _textAnimation,
                  child: const Text(
                    'B_music02',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                FadeTransition(
                  opacity: _textAnimation,
                  child: const Text(
                    'Müzik her yerde',
                    style: TextStyle(
                      color: Color(0xFFD4AF57),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          return HomeShell(
            onSignedOut: _signOut,
          );
        }

        return const AuthScreen();
      },
    );
  }
}
