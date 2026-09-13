from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding='utf-8')
    if new in text:
        print(f'{label}: already applied')
        return
    if old not in text:
        raise SystemExit(f'{label}: target not found')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'{label}: applied')


# main.dart: centralized first-run permissions, session preference and music analytics.
main = ROOT / 'lib/main.dart'
replace_once(
    main,
    "import 'dart:async';\nimport 'dart:io';\n\nimport 'package:audio_service/audio_service.dart';\nimport 'package:flutter/material.dart';\nimport 'package:permission_handler/permission_handler.dart';\nimport 'package:supabase_flutter/supabase_flutter.dart';\n\nimport 'core/services/local_music_service.dart';\n",
    "import 'dart:async';\n\nimport 'package:audio_service/audio_service.dart';\nimport 'package:flutter/material.dart';\nimport 'package:supabase_flutter/supabase_flutter.dart';\n\nimport 'core/services/local_music_service.dart';\nimport 'core/services/music_insights_service.dart';\nimport 'core/services/session_preferences.dart';\n",
    'main imports',
)
replace_once(
    main,
    "import 'features/auth/auth_screen.dart';\nimport 'features/home/home_shell.dart';\n",
    "import 'features/auth/auth_screen.dart';\nimport 'features/home/home_shell.dart';\nimport 'features/onboarding/permissions_screen.dart';\n",
    'main permissions import',
)
replace_once(
    main,
    "  await Supabase.initialize(\n    url: 'https://zgymutovzgtfexbcmzgj.supabase.co',\n    publishableKey: 'sb_publishable_BtphNNOgn_r46u_JVs1i7A_OOZXYckw',\n  );\n\n  final themeController = ThemeController();\n",
    "  await Supabase.initialize(\n    url: 'https://zgymutovzgtfexbcmzgj.supabase.co',\n    publishableKey: 'sb_publishable_BtphNNOgn_r46u_JVs1i7A_OOZXYckw',\n  );\n\n  await SessionPreferences.enforceAtStartup();\n  await MusicInsightsService.instance.initialize();\n\n  final themeController = ThemeController();\n",
    'main service initialization',
)
replace_once(
    main,
    "    WidgetsBinding.instance.addPostFrameCallback((_) {\n      _requestNotificationPermission();\n    });\n\n    _timer = Timer(\n",
    "    _timer = Timer(\n",
    'remove automatic notification prompt',
)
text = main.read_text(encoding='utf-8')
method = """  Future<void> _requestNotificationPermission() async {
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

"""
if method in text:
    main.write_text(text.replace(method, '', 1), encoding='utf-8')
    print('remove splash notification method: applied')
replace_once(
    main,
    "          return const AuthGate();\n",
    "          return const PermissionGate(child: AuthGate());\n",
    'permission gate route',
)

# AuthScreen: remember-session preference and password reset.
auth = ROOT / 'lib/features/auth/auth_screen.dart'
replace_once(
    auth,
    "import 'package:supabase_flutter/supabase_flutter.dart';\n",
    "import 'package:supabase_flutter/supabase_flutter.dart';\n\nimport '../../core/services/session_preferences.dart';\n",
    'auth session import',
)
replace_once(
    auth,
    "  bool _obscurePassword = true;\n  bool _obscurePasswordAgain = true;\n",
    "  bool _obscurePassword = true;\n  bool _obscurePasswordAgain = true;\n  bool _keepSignedIn = true;\n",
    'auth remember state',
)
replace_once(
    auth,
    "  SupabaseClient get _supabase => Supabase.instance.client;\n\n  @override\n  void dispose() {\n",
    "  SupabaseClient get _supabase => Supabase.instance.client;\n\n  @override\n  void initState() {\n    super.initState();\n    _loadSessionPreference();\n  }\n\n  Future<void> _loadSessionPreference() async {\n    final value = await SessionPreferences.keepSignedIn();\n    if (!mounted) return;\n    setState(() => _keepSignedIn = value);\n  }\n\n  @override\n  void dispose() {\n",
    'auth preference loader',
)
replace_once(
    auth,
    "      await _supabase.auth.signInWithPassword(\n        email: email,\n        password: password,\n      );\n",
    "      await _supabase.auth.signInWithPassword(\n        email: email,\n        password: password,\n      );\n      await SessionPreferences.setKeepSignedIn(_keepSignedIn);\n",
    'auth remember login',
)
reset_method = """  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Önce e-posta adresini yaz.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      _showMessage('Şifre yenileme bağlantısı e-posta adresine gönderildi.');
    } on AuthException catch (e) {
      _showMessage(e.message, error: true);
    } catch (_) {
      _showMessage('Şifre yenileme bağlantısı gönderilemedi.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

"""
text = auth.read_text(encoding='utf-8')
marker = "  Future<void> _register() async {\n"
if reset_method not in text:
    if marker not in text:
        raise SystemExit('auth reset marker not found')
    auth.write_text(text.replace(marker, reset_method + marker, 1), encoding='utf-8')
    print('auth password reset: applied')

login_tail = """        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
"""
login_new = """        ),

        const SizedBox(height: 8),

        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _keepSignedIn,
                activeColor: _gold,
                checkColor: Colors.black,
                onChanged: (value) {
                  setState(() => _keepSignedIn = value ?? true);
                },
              ),
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Oturumumu açık tut',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _loading ? null : _resetPassword,
              child: const Text(
                'Şifremi unuttum',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
"""
replace_once(auth, login_tail, login_new, 'auth login options')

# Android runtime permissions used by first-run permission center.
android = ROOT / 'tool/configure_android.py'
replace_once(
    android,
    '        "POST_NOTIFICATIONS": None,\n',
    '        "POST_NOTIFICATIONS": None,\n        "CAMERA": None,\n        "RECORD_AUDIO": None,\n',
    'android camera microphone permissions',
)

# Pause playback when headphones/Bluetooth audio route disappears.
music = ROOT / 'lib/core/services/local_music_service.dart'
replace_once(
    music,
    "    await session.configure(\n      const AudioSessionConfiguration.music(),\n    );\n\n    player.errorStream.listen((PlayerException error) {\n",
    "    await session.configure(\n      const AudioSessionConfiguration.music(),\n    );\n\n    session.becomingNoisyEventStream.listen((_) {\n      if (player.playing) {\n        unawaited(player.pause());\n      }\n    });\n\n    session.interruptionEventStream.listen((event) {\n      if (event.begin && player.playing) {\n        unawaited(player.pause());\n      }\n    });\n\n    player.errorStream.listen((PlayerException error) {\n",
    'audio interruptions and becoming noisy',
)

# Music insights uses just_audio ProcessingState for stop-after-current-song.
insights = ROOT / 'lib/core/services/music_insights_service.dart'
replace_once(
    insights,
    "import 'package:audio_service/audio_service.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\n",
    "import 'package:audio_service/audio_service.dart';\nimport 'package:just_audio/just_audio.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\n",
    'music insights just_audio import',
)

# Make privacy/permission settings directly accessible from the home header.
home = ROOT / 'lib/features/home/home_dashboard_screen.dart'
replace_once(
    home,
    "import '../../core/theme/app_theme.dart';\n",
    "import '../../core/theme/app_theme.dart';\nimport '../profile/app_settings_screen.dart';\n",
    'home settings import',
)
replace_once(
    home,
    "        IconButton(\n          tooltip: 'Profil',\n          onPressed: widget.onOpenProfile,\n          icon: const Icon(Icons.account_circle_outlined),\n        ),\n",
    "        IconButton(\n          tooltip: 'Ayarlar',\n          onPressed: () {\n            Navigator.push(\n              context,\n              MaterialPageRoute(builder: (_) => const AppSettingsScreen()),\n            );\n          },\n          icon: const Icon(Icons.settings_outlined),\n        ),\n        IconButton(\n          tooltip: 'Profil',\n          onPressed: widget.onOpenProfile,\n          icon: const Icon(Icons.account_circle_outlined),\n        ),\n",
    'home settings button',
)

print('Feature pack source patch completed.')
