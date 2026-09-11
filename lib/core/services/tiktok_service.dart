import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../models/video_item.dart';

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
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      try {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }

  Future<List<VideoItem>> fetchVideos() async {
    final List<VideoItem> allVideos = [];

    int? cursor;
    bool hasMore = true;
    int page = 0;

    while (hasMore && page < 20) {
      final uri = cursor == null
          ? Uri.parse(_apiUrl)
          : Uri.parse('$_apiUrl?cursor=$cursor');

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('TikTok videoları alınamadı.');
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (json['ok'] != true) {
        throw Exception(
          json['message']?.toString() ?? 'TikTok API hatası',
        );
      }

      final videos = (json['videos'] as List<dynamic>? ?? []);

      for (final item in videos) {
        final video = item as Map<String, dynamic>;

        final title =
            (video['title'] ?? video['video_description'] ?? 'B_music02')
                .toString()
                .trim();

        allVideos.add(
          VideoItem(
            id: video['id']?.toString() ?? '',
            title: title.isEmpty ? 'B_music02' : title,
            artist: '@b_music02',
            tiktokUrl: video['share_url']?.toString() ?? '',
            category: 'TikTok',
            thumbnailUrl: video['cover_image_url']?.toString(),
          ),
        );
      }

      hasMore = json['has_more'] == true;

      final nextCursor = json['cursor'];
      if (nextCursor is int) {
        cursor = nextCursor;
      } else if (nextCursor != null) {
        cursor = int.tryParse(nextCursor.toString());
      } else {
        cursor = null;
      }

      if (cursor == null) {
        hasMore = false;
      }

      page++;
    }

    return allVideos;
  }
}
