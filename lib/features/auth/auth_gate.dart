import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../home/home_shell.dart';
import '../onboarding/music_permissions_screen.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _guestKey = 'b_music02_guest_mode_v1';

  StreamSubscription<AuthState>? _authSub;
  bool _loading = true;
  bool _guest = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
    _authSub = _supabase.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _guest = prefs.getBool(_guestKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _enterGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, true);
    if (!mounted) return;
    setState(() => _guest = true);
  }

  Future<void> _requestLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, false);
    if (_supabase.auth.currentSession != null) {
      await _supabase.auth.signOut();
    }
    if (!mounted) return;
    setState(() => _guest = false);
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, false);
    await _supabase.auth.signOut();
    if (!mounted) return;
    setState(() => _guest = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.neonPurple),
        ),
      );
    }

    final signedIn = _supabase.auth.currentSession != null;
    if (signedIn || _guest) {
      return MusicPermissionGate(
        child: HomeShell(
          onRequestLogin: _requestLogin,
          onSignOut: _signOut,
        ),
      );
    }

    return AuthScreen(onGuest: _enterGuest);
  }
}
