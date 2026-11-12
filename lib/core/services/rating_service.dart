import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Uygulamayı puanla": Google Play in-app review with store fallbacks,
/// plus a gentle one-time prompt after natural usage.
class RatingService {
  RatingService._();

  static const packageId = 'com.bmusic.app';
  static const sessionsKey = 'rating_sessions';
  static const lastPromptKey = 'rating_last_prompt_ms';
  static const firstUseKey = 'rating_first_use_ms';
  static const promptedKey = 'rating_prompted_once';
  static const minSessions = 4;
  static const minAge = Duration(days: 3);

  /// Explicit tap in Settings: open the Play listing (review section).
  static Future<void> rateNow() async {
    final review = InAppReview.instance;
    try {
      await review.openStoreListing();
      return;
    } catch (_) {}
    final market = Uri.parse('market://details?id=$packageId');
    try {
      if (await launchUrl(market, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    await launchUrl(
      Uri.parse('https://play.google.com/store/apps/details?id=$packageId'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Called once per app start. After a few days and sessions, asks Play's
  /// in-app review sheet once. Never throws, never spams.
  static Future<void> onSessionStart() async {
    try {
      final p = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      if ((p.getInt(firstUseKey) ?? 0) == 0) {
        await p.setInt(firstUseKey, now);
      }
      final sessions = (p.getInt(sessionsKey) ?? 0) + 1;
      await p.setInt(sessionsKey, sessions);
      if (p.getBool(promptedKey) ?? false) return;
      if (sessions < minSessions) return;
      final first = p.getInt(firstUseKey) ?? now;
      if (now - first < minAge.inMilliseconds) return;
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await p.setBool(promptedKey, true);
      await p.setInt(lastPromptKey, now);
      await Future<void>.delayed(const Duration(seconds: 20));
      await review.requestReview();
    } catch (_) {}
  }

  /// Whether the gentle prompt is allowed for the current counters. Pure
  /// helper used by tests — no Play API calls.
  static bool shouldPrompt({
    required int sessions,
    required DateTime firstUse,
    required bool alreadyPrompted,
    DateTime? now,
  }) {
    if (alreadyPrompted) return false;
    if (sessions < minSessions) return false;
    final age = (now ?? DateTime.now()).difference(firstUse);
    return age >= minAge;
  }
}
