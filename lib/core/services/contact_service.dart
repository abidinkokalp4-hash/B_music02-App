import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Contact address, app sharing and the e-mail fallback of the Öneri Kutusu.
class ContactService {
  const ContactService._();

  static const email = 'bmusiciletisim@gmail.com';

  /// Always the newest signed APK of the latest GitHub release.
  static const apkUrl =
      'https://github.com/abidinkokalp4-hash/B_music02-App/releases/latest/download/B_music02.apk';

  static const shareText =
      'B Music: Müzik ve Video Oynatıcı 🎵\nÜcretsiz indir: $apkUrl';

  static Uri mailUri({String subject = 'B Music', String body = ''}) =>
      Uri(scheme: 'mailto', path: email, query: _encode({'subject': subject, if (body.isNotEmpty) 'body': body}));

  // mailto needs %20 instead of '+', so Uri.queryParameters is not used.
  static String _encode(Map<String, String> values) => values.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');

  /// Opens the mail app; false when no mail app is installed.
  static Future<bool> sendEmail({String subject = 'B Music', String body = ''}) async {
    try {
      return await launchUrl(mailUri(subject: subject, body: body),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<void> shareApp() =>
      SharePlus.instance.share(ShareParams(text: shareText, subject: 'B Music'));
}
