import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionPreferences {
  SessionPreferences._();

  static const String _keepSignedInKey = 'b_music02_keep_signed_in_v1';

  static Future<bool> keepSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepSignedInKey) ?? true;
  }

  static Future<void> setKeepSignedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepSignedInKey, value);
  }

  static Future<void> enforceAtStartup() async {
    final keep = await keepSignedIn();
    if (keep) return;

    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) {
      try {
        await auth.signOut();
      } catch (_) {
        // Ağ yoksa oturum akışının açılışı engellenmemeli.
      }
    }
  }
}
