import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../firebase_options.dart';

/// Öneri Kutusu: stores a suggestion in the Firestore `feedback` collection.
///
/// Uses the public Firestore REST API with the app's (non-secret) API key, so
/// no extra SDK is needed. firestore.rules only allows creating documents with
/// exactly these fields; nobody can read them from the app. The owner reads
/// them with `python3 tool/read_feedback.py` (or the Firebase console).
class FeedbackService {
  FeedbackService({http.Client? client, Random? random})
      : _client = client ?? http.Client(),
        _random = random ?? Random.secure();
  static final instance = FeedbackService();
  final http.Client _client;
  final Random _random;

  static const minLength = 3, maxLength = 2000;
  static String get _project => DefaultFirebaseOptions.android.projectId;
  static Uri get endpoint => Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_project/databases/(default)/documents:commit'
      '?key=${DefaultFirebaseOptions.android.apiKey}');

  static String? validate(String message) {
    final text = message.trim();
    if (text.length < minLength) return 'Lütfen biraz daha ayrıntı yazın';
    if (text.length > maxLength) return 'En fazla $maxLength karakter yazabilirsiniz';
    return null;
  }

  String _id() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(20, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  static String _clip(String value, int max) {
    final text = value.trim();
    return text.length > max ? text.substring(0, max) : text;
  }

  /// The commit request body (create-only, server timestamp).
  Map<String, Object> body({required String message, String contact = '',
      String appVersion = '', int android = 0, String device = '', String? id}) {
    final fields = <String, Object>{
      'message': {'stringValue': _clip(message, maxLength)},
      if (contact.trim().isNotEmpty) 'contact': {'stringValue': _clip(contact, 200)},
      if (appVersion.isNotEmpty) 'appVersion': {'stringValue': _clip(appVersion, 40)},
      if (android > 0 && android <= 100) 'android': {'integerValue': '$android'},
      if (device.trim().isNotEmpty) 'device': {'stringValue': _clip(device, 80)},
    };
    return {
      'writes': [
        {
          'update': {
            'name': 'projects/$_project/databases/(default)/documents/feedback/${id ?? _id()}',
            'fields': fields,
          },
          'currentDocument': {'exists': false},
          'updateTransforms': [
            {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'}
          ],
        }
      ]
    };
  }

  /// Throws [FeedbackException] when the message could not be stored.
  Future<void> send({required String message, String contact = '',
      String appVersion = '', int android = 0, String device = ''}) async {
    final problem = validate(message);
    if (problem != null) throw FeedbackException(problem);
    try {
      final response = await _client
          .post(endpoint,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body(message: message, contact: contact,
                  appVersion: appVersion, android: android, device: device)))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw FeedbackException('Gönderilemedi (${response.statusCode})');
      }
    } on FeedbackException {
      rethrow;
    } catch (_) {
      throw const FeedbackException('İnternet bağlantısı yok gibi görünüyor');
    }
  }
}

class FeedbackException implements Exception {
  const FeedbackException(this.message);
  final String message;
  @override
  String toString() => message;
}
