import 'package:flutter/material.dart';

import '../home/home_shell.dart';
import '../onboarding/music_permissions_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<void> _noop() async {}

  @override
  Widget build(BuildContext context) {
    return MusicPermissionGate(
      child: HomeShell(
        onRequestLogin: _noop,
        onSignOut: _noop,
      ),
    );
  }
}
