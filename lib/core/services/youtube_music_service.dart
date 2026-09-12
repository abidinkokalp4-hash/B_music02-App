import 'dart:convert';

import 'package:http/http.dart' as http;

class YouTubeMusicItem {
  const YouTubeMusicItem({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.publishedAt,
  });

  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;
  final DateTime? publishedAt;

  String get youtubeUrl =>
      'https://www.youtube.com/watch?v=$videoId';

  String get embedUrl =>
      'https://www.youtube.com/embed/$videoId'
      '?autoplay=1'
      '&playsinline=1'
      '&rel=0';

  factory YouTubeMusicItem.fromJson(
    Map<String, dynamic> json,
  ) {
    final id =
        json['id'];

    final snippet =
        json['snippet'];

    final idMap =
        id is Map
            ? Map<String, dynamic>.from(id)
            : <String, dynamic>{};

    final snippetMap =
        snippet is Map
            ? Map<String, dynamic>.from(snippet)
            : <String, dynamic>{};

    final thumbnails =
        snippetMap['thumbnails'];

    final thumbnailMap =
        thumbnails is Map
            ? Map<String, dynamic>.from(thumbnails)
            : <String, dynamic>{};

    String thumbnailUrl = '';

    for (final key in [
      'maxres',
      'standard',
      'high',
      'medium',
      'default',
    ]) {
      final value =
          thumbnailMap[key];

      if (value is Map) {
        final url =
            value['url']?.toString() ?? '';

        if (url.isNotEmpty) {
          thumbnailUrl = url;
          break;
        }
      }
    }

    return YouTubeMusicItem(
      videoId:
          idMap['videoId']?.toString() ?? '',
      title:
          _decodeHtml(
        snippetMap['title']?.toString() ?? '',
      ),
      channelTitle:
          _decodeHtml(
        snippetMap['channelTitle']
                ?.toString() ??
            '',
      ),
      thumbnailUrl:
          thumbnailUrl,
      publishedAt:
          DateTime.tryParse(
        snippetMap['publishedAt']
                ?.toString() ??
            '',
      ),
    );
  }

  static String _decodeHtml(
    String text,
  ) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#x27;', "'")
        .replaceAll('&#x2F;', '/')
        .trim();
  }
}

class YouTubeMusicSearchResult {
  const YouTubeMusicSearchResult({
    required this.items,
    required this.nextPageToken,
  });

  final List<YouTubeMusicItem> items;
  final String? nextPageToken;
}

class YouTubeMusicService {
  const YouTubeMusicService();

  static const String _apiKey =
      String.fromEnvironment(
    'YOUTUBE_API_KEY',
  );

  static const String _host =
      'www.googleapis.com';

  static const String _searchPath =
      '/youtube/v3/search';

  Future<YouTubeMusicSearchResult> searchMusic(
    String query, {
    String? pageToken,
    int maxResults = 25,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception(
        'YouTube API anahtarı APK derlemesine eklenmemiş.',
      );
    }

    final cleaned =
        query.trim();

    final searchText =
        cleaned.isEmpty
            ? 'popular music'
            : cleaned;

    final parameters =
        <String, String>{
      'key': _apiKey,

      'part': 'snippet',

      'q': searchText,

      'type': 'video',

      // YouTube Music kategorisi.
      'videoCategoryId': '10',

      // Uygulama içinde gömülebilen videolar.
      'videoEmbeddable': 'true',

      // Harici uygulamalarda oynatılabilen videolar.
      'videoSyndicated': 'true',

      'safeSearch': 'moderate',

      'maxResults':
          maxResults
              .clamp(
                1,
                50,
              )
              .toString(),

      'order': 'relevance',
    };

    if (pageToken != null &&
        pageToken.trim().isNotEmpty) {
      parameters['pageToken'] =
          pageToken.trim();
    }

    final uri =
        Uri.https(
      _host,
      _searchPath,
      parameters,
    );

    final response =
        await http
            .get(
              uri,
              headers: const {
                'Accept':
                    'application/json',
              },
            )
            .timeout(
              const Duration(
                seconds: 25,
              ),
            );

    if (response.statusCode != 200) {
      throw Exception(
        _googleError(
          response,
        ),
      );
    }

    final decoded =
        jsonDecode(
      utf8.decode(
        response.bodyBytes,
      ),
    );

    if (decoded is! Map) {
      throw Exception(
        'YouTube yanıtı okunamadı.',
      );
    }

    final root =
        Map<String, dynamic>.from(
      decoded,
    );

    final rawItems =
        root['items'];

    final items =
        <YouTubeMusicItem>[];

    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          continue;
        }

        final item =
            YouTubeMusicItem
                .fromJson(
          Map<String, dynamic>.from(
            rawItem,
          ),
        );

        if (item.videoId.isEmpty) {
          continue;
        }

        items.add(item);
      }
    }

    final nextPageToken =
        root['nextPageToken']
            ?.toString();

    return YouTubeMusicSearchResult(
      items: items,
      nextPageToken:
          nextPageToken != null &&
                  nextPageToken.isNotEmpty
              ? nextPageToken
              : null,
    );
  }

  Future<YouTubeMusicSearchResult>
      searchMore({
    required String query,
    required String nextPageToken,
  }) {
    return searchMusic(
      query,
      pageToken:
          nextPageToken,
    );
  }

  String _googleError(
    http.Response response,
  ) {
    try {
      final decoded =
          jsonDecode(
        utf8.decode(
          response.bodyBytes,
        ),
      );

      if (decoded is Map) {
        final error =
            decoded['error'];

        if (error is Map) {
          final errorMap =
              Map<String, dynamic>.from(
            error,
          );

          final message =
              errorMap['message']
                  ?.toString();

          if (message != null &&
              message.isNotEmpty) {
            return 'YouTube API ${response.statusCode}: $message';
          }
        }
      }
    } catch (_) {}

    return 'YouTube API bağlantı hatası: ${response.statusCode}';
  }
}
