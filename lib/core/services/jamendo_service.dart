
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
    return JamendoTrack(
      id: json['id']?.toString() ?? '',
      title:
          json['name']?.toString() ??
          'Bilinmeyen Şarkı',
      artist:
          json['artist_name']?.toString() ??
          'Bilinmeyen Sanatçı',
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
      downloadAllowed:
          json['audiodownload_allowed'] == true,
      duration:
          int.tryParse(
            json['duration']?.toString() ?? '',
          ) ??
          0,
      licenseUrl:
          json['license_ccurl']?.toString() ?? '',
    );
  }
}

class JamendoService {
  const JamendoService();

  static const String _baseUrl =
      'https://api.jamendo.com/v3.0';

  // Jamendo'nun resmî test Client ID'si.
  // Play Store'a çıkmadan önce kendi Client ID'n ile değiştireceğiz.
  static const String _clientId =
      '709fa152';

  Future<List<JamendoTrack>> searchTracks(
    String query, {
    int limit = 30,
  }) async {
    final cleaned = query.trim();

    if (cleaned.isEmpty) {
      return popularTracks(
        limit: limit,
      );
    }

    final uri = Uri.parse(
      '$_baseUrl/tracks/',
    ).replace(
      queryParameters: {
        'client_id': _clientId,
        'format': 'json',
        'limit': '$limit',
        'search': cleaned,
        'type': 'single albumtrack',
        'imagesize': '300',
        'audioformat': 'mp32',
        'audiodlformat': 'mp32',
        'include': 'licenses',
      },
    );

    return _fetchTracks(uri);
  }

  Future<List<JamendoTrack>> popularTracks({
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/tracks/',
    ).replace(
      queryParameters: {
        'client_id': _clientId,
        'format': 'json',
        'limit': '$limit',
        'order': 'popularity_month',
        'type': 'single albumtrack',
        'imagesize': '300',
        'audioformat': 'mp32',
        'audiodlformat': 'mp32',
        'include': 'licenses',
      },
    );

    return _fetchTracks(uri);
  }

  Future<List<JamendoTrack>> downloadableTracks({
    String? search,
    int limit = 50,
  }) async {
    final tracks =
        search == null ||
            search.trim().isEmpty
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

  Future<List<JamendoTrack>> _fetchTracks(
    Uri uri,
  ) async {
    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Jamendo bağlantı hatası: ${response.statusCode}',
      );
    }

    final decoded =
        jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Geçersiz Jamendo yanıtı.',
      );
    }

    final headers =
        decoded['headers'];

    if (headers is Map) {
      final status =
          headers['status']?.toString();

      if (status != 'success') {
        throw Exception(
          headers['error_message']
                  ?.toString() ??
              'Jamendo API hatası.',
        );
      }
    }

    final results =
        decoded['results'];

    if (results is! List) {
      return [];
    }

    return results
        .whereType<Map<String, dynamic>>()
        .map(
          JamendoTrack.fromJson,
        )
        .toList();
  }
}
