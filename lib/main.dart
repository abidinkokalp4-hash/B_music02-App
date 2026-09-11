import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/auth_screen.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgymutovzgtfexbcmzgj.supabase.co',
    publishableKey: 'sb_publishable_BtphNNOgn_r46u_JVs1i7A_OOZXYckw',
  );

  runApp(const BMusicApp());
}

class BMusicApp extends StatelessWidget {
  const BMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'B_music02',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
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
        final session =
            Supabase.instance.client.auth.currentSession;

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
