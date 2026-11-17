import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../firebase_options.dart';

/// Şarkı mektubu: stored in the Firestore `letters` collection through the
/// public REST API (same pattern as the Öneri Kutusu). firestore.rules allow
/// creating a well-formed letter and reading one letter by its random id
/// (no listing). The recipient opens https://bmusic02-app.web.app/m/ID.
class SongLetters {
  SongLetters({http.Client? client, Random? random})
      : _client = client ?? http.Client(),
        _random = random ?? Random.secure();
  static final instance = SongLetters();
  final http.Client _client;
  final Random _random;

  static const maxSender = 40, maxMessage = 200, maxClipBytes = 450000, maxCoverBytes = 60000;
  static const webHost = 'https://bmusic02-app.web.app';
  static String get _project => DefaultFirebaseOptions.android.projectId;
  static String get _key => DefaultFirebaseOptions.android.apiKey;
  static Uri get commitEndpoint => Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_project/databases/(default)/documents:commit?key=$_key');
  static Uri documentEndpoint(String id) => Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$_project/databases/(default)/documents/letters/$id?key=$_key');
  static String webLink(String id) => '$webHost/m/$id';

  static String? idFromLink(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // bmusic://mektup/<id>  or  https://bmusic02-app.web.app/m/<id>
    if (uri.scheme == 'bmusic' && uri.host == 'mektup' && segments.isNotEmpty) {
      return _valid(segments.first);
    }
    if (segments.length >= 2 && segments[0] == 'm') return _valid(segments[1]);
    return null;
  }

  static String? _valid(String id) =>
      RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(id) ? id : null;

  String newId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(20, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  static String _cut(String value, int max) {
    final text = value.trim();
    return text.length > max ? text.substring(0, max) : text;
  }

  Map<String, Object> body(
      {required String id,
      required String sender,
      required String message,
      required String title,
      String artist = '',
      String? clipBase64,
      String? coverBase64,
      int clipStart = 0}) {
    final fields = <String, Object>{
      'sender': {'stringValue': _cut(sender, maxSender)},
      'message': {'stringValue': _cut(message, maxMessage)},
      'title': {'stringValue': _cut(title, 120)},
      if (artist.trim().isNotEmpty) 'artist': {'stringValue': _cut(artist, 120)},
      if (clipBase64 != null) 'clip': {'stringValue': clipBase64},
      if (clipBase64 != null) 'clipStart': {'integerValue': '$clipStart'},
      if (coverBase64 != null) 'cover': {'stringValue': coverBase64},
    };
    return {
      'writes': [
        {
          'update': {
            'name': 'projects/$_project/databases/(default)/documents/letters/$id',
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

  /// Returns the letter id. [clip] is an AAC/M4A file of at most 15 s.
  Future<String> send(
      {required String sender,
      required String message,
      required String title,
      String artist = '',
      File? clip,
      List<int>? cover,
      int clipStart = 0}) async {
    if (sender.trim().isEmpty) throw const LetterException('Adını yaz');
    if (message.trim().isEmpty) throw const LetterException('Bir mesaj yaz');
    String? encoded;
    if (clip != null) {
      final bytes = await clip.readAsBytes();
      if (bytes.length <= maxClipBytes) encoded = base64Encode(bytes);
    }
    final id = newId();
    try {
      final response = await _client
          .post(commitEndpoint,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body(
                  id: id,
                  sender: sender,
                  message: message,
                  title: title,
                  artist: artist,
                  clipBase64: encoded,
                  coverBase64: cover != null && cover.length <= maxCoverBytes
                      ? base64Encode(cover)
                      : null,
                  clipStart: clipStart)))
          .timeout(const Duration(seconds: 40));
      if (response.statusCode != 200) {
        throw LetterException('Gönderilemedi (${response.statusCode})');
      }
    } on LetterException {
      rethrow;
    } catch (_) {
      throw const LetterException('İnternet bağlantısı yok gibi görünüyor');
    }
    return id;
  }

  Future<SongLetter> fetch(String id) async {
    final response =
        await _client.get(documentEndpoint(id)).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw LetterException('Mektup bulunamadı (${response.statusCode})');
    }
    final fields = (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['fields'] as Map? ?? {};
    String text(String key) => (fields[key] as Map?)?['stringValue'] as String? ?? '';
    final clip = text('clip');
    final cover = text('cover');
    return SongLetter(
      id: id,
      sender: text('sender'),
      message: text('message'),
      title: text('title'),
      artist: text('artist'),
      clip: clip.isEmpty ? null : base64Decode(clip),
      cover: cover.isEmpty ? null : base64Decode(cover),
    );
  }
}

class SongLetter {
  const SongLetter(
      {required this.id,
      required this.sender,
      required this.message,
      required this.title,
      this.artist = '',
      this.clip,
      this.cover});
  final String id, sender, message, title, artist;
  final List<int>? clip, cover;
}

class LetterException implements Exception {
  const LetterException(this.message);
  final String message;
  @override
  String toString() => message;
}
