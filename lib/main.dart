import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgymutovzgtfexbcmzgj.supabase.co',
    publishableKey:
        'sb_publishable_BtphNNOgn_r46u_JVs1i7A_OOZXYckw',
  );

  final themeController =
      ThemeController();

  await themeController.load();

  runApp(
    BMusicApp(
      themeController:
          themeController,
    ),
  );
}

class BMusicApp extends StatelessWidget {
  const BMusicApp({
    super.key,
    required this.themeController,
  });

  final ThemeController
      themeController;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ThemeControllerScope(
      controller:
          themeController,
      child: AnimatedBuilder(
        animation:
            themeController,
        builder: (
          context,
          child,
        ) {
          return MaterialApp(
            debugShowCheckedModeBanner:
                false,

            title:
                'B_music02',

            theme:
                AppTheme.light(),

            darkTheme:
                AppTheme.dark(),

            themeMode:
                themeController
                    .themeMode,

            home:
                const BMusicSplashScreen(),
          );
        },
      ),
    );
  }
}

class ThemeControllerScope
    extends InheritedNotifier<
        ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController
        controller,
    required super.child,
  }) : super(
          notifier: controller,
        );

  static ThemeController of(
    BuildContext context,
  ) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<
            ThemeControllerScope>();

    assert(
      scope != null,
      'ThemeControllerScope bulunamadı.',
    );

    return scope!.notifier!;
  }
}

class BMusicSplashScreen
    extends StatefulWidget {
  const BMusicSplashScreen({
    super.key,
  });

  @override
  State<BMusicSplashScreen>
      createState() =>
          _BMusicSplashScreenState();
}

class _BMusicSplashScreenState
    extends State<
        BMusicSplashScreen>
    with
        SingleTickerProviderStateMixin {
  late final AnimationController
      _controller;

  late final Animation<double>
      _scaleAnimation;

  late final Animation<double>
      _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 1400,
      ),
    );

    _scaleAnimation =
        Tween<double>(
      begin: 0.82,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve:
            Curves.easeOutBack,
      ),
    );

    _fadeAnimation =
        Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve:
            Curves.easeOut,
      ),
    );

    _controller.forward();

    _openApp();
  }

  Future<void> _openApp() async {
    await Future.delayed(
      const Duration(
        milliseconds: 2800,
      ),
    );

    if (!mounted) return;

    Navigator.of(context)
        .pushReplacement(
      PageRouteBuilder(
        transitionDuration:
            const Duration(
          milliseconds: 500,
        ),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return const AuthGate();
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xFF080808,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child:
                _GlowCircle(
              size: 250,
              color:
                  AppColors.burgundy
                      .withOpacity(
                0.22,
              ),
            ),
          ),

          Positioned(
            right: -100,
            bottom: 40,
            child:
                _GlowCircle(
              size: 280,
              color:
                  AppColors.gold
                      .withOpacity(
                0.10,
              ),
            ),
          ),

          Center(
            child:
                FadeTransition(
              opacity:
                  _fadeAnimation,
              child:
                  ScaleTransition(
                scale:
                    _scaleAnimation,
                child: Padding(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 30,
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize
                            .min,
                    children: [
                      Container(
                        width: 132,
                        height: 132,
                        padding:
                            const EdgeInsets
                                .all(
                          5,
                        ),
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape
                                  .circle,
                          border:
                              Border.all(
                            color:
                                AppColors
                                    .gold,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors
                                      .gold
                                      .withOpacity(
                                0.22,
                              ),
                              blurRadius:
                                  35,
                              spreadRadius:
                                  2,
                            ),
                          ],
                        ),
                        child:
                            ClipOval(
                          child:
                              Image.asset(
                            'assets/images/b_music02_logo.png',
                            fit:
                                BoxFit.cover,
                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return Container(
                                color:
                                    AppColors
                                        .burgundy,
                                child:
                                    const Icon(
                                  Icons
                                      .music_note_rounded,
                                  color:
                                      AppColors
                                          .gold,
                                  size:
                                      60,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      const Text(
                        'B_music02',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 34,
                          fontWeight:
                              FontWeight
                                  .w900,
                          letterSpacing:
                              -1,
                        ),
                      ),

                      const SizedBox(
                        height: 7,
                      ),

                      const Text(
                        'Müzik burada yaşar',
                        style:
                            TextStyle(
                          color:
                              AppColors
                                  .gold,
                          fontSize: 15,
                          fontWeight:
                              FontWeight
                                  .w700,
                          letterSpacing:
                              0.4,
                        ),
                      ),

                      const SizedBox(
                        height: 27,
                      ),

                      const Text(
                        'Güneydoğu’nun En Büyük\nMüzik Sayfasına Hoş Geldiniz',
                        textAlign:
                            TextAlign
                                .center,
                        style:
                            TextStyle(
                          color:
                              Colors
                                  .white70,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight:
                              FontWeight
                                  .w500,
                        ),
                      ),

                      const SizedBox(
                        height: 35,
                      ),

                      const SizedBox(
                        width: 27,
                        height: 27,
                        child:
                            CircularProgressIndicator(
                          color:
                              AppColors
                                  .gold,
                          strokeWidth:
                              2.4,
                        ),
                      ),

                      const SizedBox(
                        height: 13,
                      ),

                      const Text(
                        'B_music02 hazırlanıyor',
                        style:
                            TextStyle(
                          color:
                              Colors
                                  .white38,
                          fontSize: 11,
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

class _GlowCircle
    extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 90,
            spreadRadius: 35,
          ),
        ],
      ),
    );
  }
}

class AuthGate
    extends StatelessWidget {
  const AuthGate({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final supabase =
        Supabase.instance.client;

    return StreamBuilder<
        AuthState>(
      stream:
          supabase.auth
              .onAuthStateChange,
      builder: (
        context,
        snapshot,
      ) {
        final session =
            supabase.auth
                .currentSession;

        if (session != null) {
          return HomeShell(
            onSignedOut: () async {
              await supabase.auth
                  .signOut();
            },
          );
        }

        return const AuthScreen();
      },
    );
  }
}
