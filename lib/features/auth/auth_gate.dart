import 'package:flutter/material.dart';

import '../home/home_shell.dart';
import '../onboarding/music_permissions_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return MusicPermissionGate(
      child: const HomeShell(),
    );
  }
}
