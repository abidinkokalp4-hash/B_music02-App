import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../models/video_item.dart';

class TikTokPage {
  final List<VideoItem> videos;
  final int? cursor;
  final bool hasMore;

  const TikTokPage({
    required this.videos,
    required this.cursor,
    required this.hasMore,
  });
}

class TikTokService {
  static const String _apiUrl =
      'https://b-music02-backend.vercel.app/api/tiktok/videos';

  const TikTokService();

  Future<bool> open(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);

    if (uri == null) return false;

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  Future<TikTokPage> fetchVideos({
    int? cursor,
  }) async {
    final uri = cursor == null
        ? Uri.parse(_apiUrl)
        : Uri.parse(_apiUrl).replace(
            queryParameters: {
              'cursor': cursor.toString(),
            },
          );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'TikTok videoları alınamadı.',
      );
    }

    final decoded = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Sunucudan geçersiz cevap geldi.',
      );
    }

    if (decoded['ok'] != true) {
      throw Exception(
        decoded['message']?.toString() ??
            'TikTok API hatası.',
      );
    }

    final videos = <VideoItem>[];

    final rawVideos = decoded['videos'];

    if (rawVideos is List) {
      for (final raw in rawVideos) {
        if (raw is! Map) continue;

        final video =
            Map<String, dynamic>.from(raw);

        final id =
            video['id']?.toString().trim() ?? '';

        final shareUrl =
            video['share_url']?.toString().trim() ?? '';

        if (id.isEmpty || shareUrl.isEmpty) {
          continue;
        }

        final apiTitle =
            video['title']?.toString().trim() ?? '';

        final description =
            video['video_description']
                    ?.toString()
                    .trim() ??
                '';

        final title = apiTitle.isNotEmpty
            ? apiTitle
            : description.isNotEmpty
                ? description
                : 'B_music02';

        final thumbnail =
            video['cover_image_url']
                ?.toString()
                .trim();

        videos.add(
          VideoItem(
            id: id,
            title: title,
            artist: '@b_music02',
            tiktokUrl: shareUrl,
            category: 'TikTok',
            thumbnailUrl:
                thumbnail != null &&
                        thumbnail.isNotEmpty
                    ? thumbnail
                    : null,
          ),
        );
      }
    }

    int? nextCursor;

    final rawCursor = decoded['cursor'];

    if (rawCursor is int) {
      nextCursor = rawCursor;
    } else if (rawCursor != null) {
      nextCursor =
          int.tryParse(rawCursor.toString());
    }

    return TikTokPage(
      videos: videos,
      cursor: nextCursor,
      hasMore:
          decoded['has_more'] == true &&
              nextCursor != null,
    );
  }
}
