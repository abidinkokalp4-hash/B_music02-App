import 'package:flutter/material.dart';

import '../home/home_shell.dart';
import '../onboarding/app_tour.dart';
import '../onboarding/music_permissions_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppTourGate(child: MusicPermissionGate(child: HomeShell()));
  }
}
