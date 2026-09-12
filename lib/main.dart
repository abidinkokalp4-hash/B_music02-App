import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/auth_screen.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgymutovzgtfexbcmzgj.supabase.co',
    publishableKey:
        'sb_publishable_BtphNNOgn_r46u_JVs1i7A_OOZXYckw',
  );

  runApp(const BMusicApp());
}

class BMusicApp extends StatelessWidget {
  const BMusicApp({super.key});

  static const gold = Color(0xFFD4AF57);
  static const burgundy = Color(0xFF7A1F3D);
  static const background = Color(0xFF080808);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'B_music02',

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        scaffoldBackgroundColor: background,

        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ).copyWith(
          primary: gold,
          secondary: burgundy,
          surface: const Color(0xFF151114),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),

        elevatedButtonTheme:
            ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        inputDecorationTheme:
            InputDecorationTheme(
          filled: true,
          fillColor:
              const Color(0xFF151114),

          hintStyle: const TextStyle(
            color: Colors.white38,
          ),

          labelStyle: const TextStyle(
            color: Colors.white60,
          ),

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(18),
            borderSide: BorderSide(
              color:
                  Colors.white.withOpacity(0.08),
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: gold,
              width: 1.2,
            ),
          ),
        ),
      ),

      home: const BMusicSplashScreen(),
    );
  }
}

// =======================================================
// AÇILIŞ EKRANI
// =======================================================

class BMusicSplashScreen
    extends StatefulWidget {
  const BMusicSplashScreen({
    super.key,
  });

  @override
  State<BMusicSplashScreen> createState() =>
      _BMusicSplashScreenState();
}

class _BMusicSplashScreenState
    extends State<BMusicSplashScreen>
    with TickerProviderStateMixin {
  static const gold =
      Color(0xFFD4AF57);

  static const burgundy =
      Color(0xFF7A1F3D);

  static const background =
      Color(0xFF080808);

  late final AnimationController
      _logoController;

  late final AnimationController
      _glowController;

  late final Animation<double>
      _scaleAnimation;

  late final Animation<double>
      _fadeAnimation;

  late final Animation<double>
      _textAnimation;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _logoController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 1300,
      ),
    );

    _glowController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 1500,
      ),
    );

    _scaleAnimation =
        CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation =
        CurvedAnimation(
      parent: _logoController,
      curve: const Interval(
        0.0,
        0.65,
        curve: Curves.easeOut,
      ),
    );

    _textAnimation =
        CurvedAnimation(
      parent: _logoController,
      curve: const Interval(
        0.45,
        1.0,
        curve: Curves.easeOut,
      ),
    );

    _logoController.forward();

    _glowController.repeat(
      reverse: true,
    );

    _timer = Timer(
      const Duration(
        milliseconds: 2800,
      ),
      _goNext,
    );
  }

  void _goNext() {
    if (!mounted) return;

    Navigator.of(context)
        .pushReplacement(
      PageRouteBuilder(
        transitionDuration:
            const Duration(
          milliseconds: 550,
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
    _timer?.cancel();
    _logoController.dispose();
    _glowController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (
              context,
              child,
            ) {
              final value =
                  _glowController.value;

              return Stack(
                children: [
                  Positioned(
                    left: -100,
                    top: -90,
                    child: Container(
                      width:
                          300 + (value * 30),
                      height:
                          300 + (value * 30),
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: burgundy
                                .withOpacity(
                              0.18,
                            ),
                            blurRadius:
                                110 +
                                    (value *
                                        20),
                            spreadRadius:
                                45,
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    right: -100,
                    bottom: -120,
                    child: Container(
                      width:
                          280 + (value * 30),
                      height:
                          280 + (value * 30),
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: gold
                                .withOpacity(
                              0.08,
                            ),
                            blurRadius:
                                100 +
                                    (value *
                                        20),
                            spreadRadius:
                                40,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 28,
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    ScaleTransition(
                      scale:
                          _scaleAnimation,
                      child:
                          FadeTransition(
                        opacity:
                            _fadeAnimation,
                        child:
                            Container(
                          width: 150,
                          height: 150,
                          padding:
                              const EdgeInsets
                                  .all(8),
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            border:
                                Border.all(
                              color:
                                  gold,
                              width:
                                  2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gold
                                    .withOpacity(
                                  0.20,
                                ),
                                blurRadius:
                                    36,
                                spreadRadius:
                                    4,
                              ),
                              BoxShadow(
                                color: burgundy
                                    .withOpacity(
                                  0.35,
                                ),
                                blurRadius:
                                    60,
                                spreadRadius:
                                    8,
                              ),
                            ],
                          ),
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .all(7),
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape.circle,
                              border:
                                  Border.all(
                                color:
                                    burgundy,
                                width:
                                    5,
                              ),
                            ),
                            child:
                                ClipOval(
                              child:
                                  Image.asset(
                                'assets/images/b_music02_logo.png',
                                fit: BoxFit
                                    .cover,
                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return const ColoredBox(
                                    color:
                                        Color(
                                      0xFF1A0C14,
                                    ),
                                    child:
                                        Icon(
                                      Icons
                                          .music_note_rounded,
                                      size:
                                          72,
                                      color:
                                          gold,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    FadeTransition(
                      opacity:
                          _textAnimation,
                      child: Column(
                        children: [
                          const Text(
                            'B_music02',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  37,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              letterSpacing:
                                  -0.8,
                            ),
                          ),

                          const SizedBox(
                            height: 9,
                          ),

                          const Text(
                            'Müzik burada yaşar',
                            style:
                                TextStyle(
                              color:
                                  gold,
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              letterSpacing:
                                  0.4,
                            ),
                          ),

                          const SizedBox(
                            height: 22,
                          ),

                          Container(
                            width: 55,
                            height: 2,
                            decoration:
                                BoxDecoration(
                              color:
                                  gold,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 22,
                          ),

                          const Text(
                            'Güneydoğu’nun En Büyük\nMüzik Sayfasına Hoş Geldiniz',
                            textAlign:
                                TextAlign
                                    .center,
                            style:
                                TextStyle(
                              color:
                                  Colors.white70,
                              fontSize:
                                  15,
                              height:
                                  1.5,
                              fontWeight:
                                  FontWeight
                                      .w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom:
                MediaQuery.of(context)
                        .padding
                        .bottom +
                    24,
            child:
                FadeTransition(
              opacity:
                  _textAnimation,
              child:
                  const Column(
                children: [
                  SizedBox(
                    width: 21,
                    height: 21,
                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          1.8,
                      color: gold,
                    ),
                  ),

                  SizedBox(
                    height: 10,
                  ),

                  Text(
                    'B_music02 hazırlanıyor',
                    style:
                        TextStyle(
                      color:
                          Colors.white30,
                      fontSize:
                          10,
                      letterSpacing:
                          0.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// GİRİŞ DURUMU
// =======================================================

class AuthGate
    extends StatefulWidget {
  const AuthGate({
    super.key,
  });

  @override
  State<AuthGate> createState() =>
      _AuthGateState();
}

class _AuthGateState
    extends State<AuthGate> {
  late final Stream<AuthState>
      _authStream;

  @override
  void initState() {
    super.initState();

    _authStream =
        Supabase.instance.client.auth
            .onAuthStateChange;
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth
        .signOut();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (
        context,
        snapshot,
      ) {
        final session =
            Supabase.instance.client.auth
                .currentSession;

        if (session != null) {
          return HomeShell(
            onSignedOut:
                _signOut,
          );
        }

        return const AuthScreen();
      },
    );
  }
}
