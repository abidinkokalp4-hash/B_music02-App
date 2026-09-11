import 'package:url_launcher/url_launcher.dart';

class TikTokService {
  const TikTokService();

  Future<bool> open(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;

    try {
      final appOpened = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (appOpened) return true;
    } catch (_) {
      // Some platforms can reject non-browser mode. Fall back below.
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
