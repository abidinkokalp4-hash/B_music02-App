import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class JamendoTrack {
  const JamendoTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.audioUrl,
    required this.downloadUrl,
    required this.downloadAllowed,
    required this.duration,
    required this.licenseUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String imageUrl;
  final String audioUrl;
  final String downloadUrl;
  final bool downloadAllowed;
  final int duration;
  final String licenseUrl;

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory JamendoTrack.fromJson(
    Map<String, dynamic> json,
  ) {
    final durationValue = json['duration'];

    int duration = 0;

    if (durationValue is int) {
      duration = durationValue;
    } else if (durationValue is num) {
      duration = durationValue.toInt();
    } else {
      duration =
          double.tryParse(
            durationValue?.toString() ?? '',
          )?.toInt() ??
          0;
    }

    final allowedValue =
        json['audiodownload_allowed'];

    final downloadAllowed =
        allowedValue == true ||
        allowedValue?.toString().toLowerCase() ==
            'true' ||
        allowedValue?.toString() == '1';

    return JamendoTrack(
      id: json['id']?.toString() ?? '',
      title:
          json['name']?.toString().trim().isNotEmpty ==
                  true
              ? json['name'].toString()
              : 'Bilinmeyen Şarkı',
      artist:
          json['artist_name']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? json['artist_name'].toString()
              : 'Bilinmeyen Sanatçı',
      album:
          json['album_name']?.toString() ?? '',
      imageUrl:
          json['image']?.toString() ??
          json['album_image']?.toString() ??
          '',
      audioUrl:
          json['audio']?.toString() ?? '',
      downloadUrl:
          json['audiodownload']?.toString() ?? '',
      downloadAllowed: downloadAllowed,
      duration: duration,
      licenseUrl:
          json['license_ccurl']?.toString() ?? '',
    );
  }
}

class JamendoService {
  const JamendoService();

  static const String _clientId =
      '709fa152';

  static const String _host =
      'api.jamendo.com';

  static const String _path =
      '/v3.0/tracks/';

  Future<List<JamendoTrack>> popularTracks({
    int limit = 40,
  }) async {
    final primary = <String, String>{
      'client_id': _clientId,
      'format': 'json',
      'limit': '$limit',
      'order': 'popularity_month',
      'imagesize': '300',
    };

    try {
      return await _request(primary);
    } catch (_) {
      // İlk istek reddedilirse en sade Jamendo isteğini dene.
      return _request({
        'client_id': _clientId,
        'format': 'json',
        'limit': '$limit',
      });
    }
  }

  Future<List<JamendoTrack>> searchTracks(
    String query, {
    int limit = 40,
  }) async {
    final cleaned = query.trim();

    if (cleaned.isEmpty) {
      return popularTracks(
        limit: limit,
      );
    }

    final primary = <String, String>{
      'client_id': _clientId,
      'format': 'json',
      'limit': '$limit',
      'search': cleaned,
      'imagesize': '300',
    };

    try {
      return await _request(primary);
    } catch (_) {
      return _request({
        'client_id': _clientId,
        'format': 'json',
        'limit': '$limit',
        'search': cleaned,
      });
    }
  }

  Future<List<JamendoTrack>> downloadableTracks({
    String? search,
    int limit = 50,
  }) async {
    final tracks =
        search == null || search.trim().isEmpty
            ? await popularTracks(
                limit: limit,
              )
            : await searchTracks(
                search,
                limit: limit,
              );

    return tracks
        .where(
          (track) =>
              track.downloadAllowed &&
              track.downloadUrl.isNotEmpty,
        )
        .toList();
  }

  Future<List<JamendoTrack>> _request(
    Map<String, String> parameters,
  ) async {
    final uri = Uri.https(
      _host,
      _path,
      parameters,
    );

    http.Response response;

    try {
      response = await http
          .get(
            uri,
            headers: const {
              'Accept':
                  'application/json',
              'User-Agent':
                  'B_music02/1.0 Android',
            },
          )
          .timeout(
            const Duration(
              seconds: 20,
            ),
          );
    } on TimeoutException {
      throw Exception(
        'Jamendo bağlantısı zaman aşımına uğradı.',
      );
    } catch (e) {
      throw Exception(
        'Jamendo bağlantısı kurulamadı: $e',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Jamendo HTTP hatası: ${response.statusCode}',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(
        utf8.decode(
          response.bodyBytes,
        ),
      );
    } catch (_) {
      throw Exception(
        'Jamendo geçersiz veri gönderdi.',
      );
    }

    if (decoded is! Map) {
      throw Exception(
        'Jamendo yanıtı okunamadı.',
      );
    }

    final root =
        Map<String, dynamic>.from(
      decoded,
    );

    final headersValue =
        root['headers'];

    if (headersValue is Map) {
      final headers =
          Map<String, dynamic>.from(
        headersValue,
      );

      final status =
          headers['status']
              ?.toString()
              .toLowerCase();

      final code =
          headers['code']
              ?.toString();

      if (status != null &&
          status != 'success') {
        final message =
            headers['error_message']
                ?.toString();

        throw Exception(
          message != null &&
                  message.isNotEmpty
              ? 'Jamendo: $message'
              : 'Jamendo API hatası ($code)',
        );
      }
    }

    final results =
        root['results'];

    if (results is! List) {
      return [];
    }

    final tracks =
        <JamendoTrack>[];

    for (final item in results) {
      if (item is Map) {
        try {
          tracks.add(
            JamendoTrack.fromJson(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          );
        } catch (_) {
          // Hatalı tek bir kayıt bütün listeyi bozmasın.
        }
      }
    }

    return tracks;
  }
}
