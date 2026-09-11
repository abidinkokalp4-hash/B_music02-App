import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/home/home_shell.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BMusicApp());
}

class BMusicApp extends StatefulWidget {
  const BMusicApp({super.key});

  @override
  State<BMusicApp> createState() => _BMusicAppState();
}

class _BMusicAppState extends State<BMusicApp> {
  bool _splashDone = false;
  bool? _signedIn;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _signedIn = prefs.getBool('signedIn') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'B_music02',
      theme: AppTheme.dark(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: !_splashDone
            ? SplashScreen(key: const ValueKey('splash'), onFinished: () => setState(() => _splashDone = true))
            : _signedIn == true
                ? HomeShell(key: const ValueKey('home'), onSignedOut: () => setState(() => _signedIn = false))
                : AuthScreen(key: const ValueKey('auth'), onAuthenticated: () => setState(() => _signedIn = true)),
      ),
    );
  }
}
