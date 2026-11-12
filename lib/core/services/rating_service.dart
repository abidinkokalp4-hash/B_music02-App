import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Uygulamayı puanla": Google Play in-app review with store fallbacks,
/// plus a gentle one-time prompt after natural usage.
class RatingService {
  RatingService._();

  static const packageId = 'com.bmusic.app';
  static const _sessionsKey = 'rating_sessions';
  static const _lastPromptKey = 'rating_last_prompt_ms';
  static const _minSessions = 5;
  static const _interval = Duration(days: 120);

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

  /// Called once per app start; after ~5 sessions asks Play's in-app review
  /// sheet at most once per [_interval]. Never throws.
  static Future<void> onSessionStart() async {
    try {
      final p = await SharedPreferences.getInstance();
      final sessions = (p.getInt(_sessionsKey) ?? 0) + 1;
      await p.setInt(_sessionsKey, sessions);
      if (sessions < _minSessions) return;
      final last = p.getInt(_lastPromptKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < _interval.inMilliseconds) return;
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await p.setInt(_lastPromptKey, now);
      await Future<void>.delayed(const Duration(seconds: 20));
      await review.requestReview();
    } catch (_) {}
  }
}
