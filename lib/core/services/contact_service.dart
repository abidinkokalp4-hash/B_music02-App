import 'package:url_launcher/url_launcher.dart';

class ContactService {
  const ContactService();

  static const String advertisingEmail =
      'Abdinkokalp0102@gmail.com';

  Future<bool> openAdvertisingEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: advertisingEmail,
      queryParameters: {
        'subject': 'B_music02 Reklam Talebi',
        'body':
            'Merhaba,\n\nB_music02 uygulamasında reklam vermek istiyorum.\n\nİletişim bilgilerim:\n',
      },
    );

    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }
}
