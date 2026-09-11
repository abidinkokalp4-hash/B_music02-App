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
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  Future<List<VideoItem>> fetchVideos() async {
    final response = await http
        .get(Uri.parse(_apiUrl))
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('TikTok videoları alınamadı.');
    }

    final data = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (data is! Map<String, dynamic> || data['ok'] != true) {
      throw Exception('TikTok API hatası.');
    }

    final rawVideos = data['videos'];

    if (rawVideos is! List) {
      throw Exception('Video bulunamadı.');
    }

    final videos = <VideoItem>[];

    for (final raw in rawVideos) {
      if (raw is! Map) continue;

      final video = Map<String, dynamic>.from(raw);

      final id = video['id']?.toString() ?? '';
      final url = video['share_url']?.toString() ?? '';

      if (id.isEmpty || url.isEmpty) continue;

      final title =
          video['title']?.toString().trim() ?? '';

      final description =
          video['video_description']?.toString().trim() ?? '';

      videos.add(
        VideoItem(
          id: id,
          title: title.isNotEmpty
              ? title
              : description.isNotEmpty
                  ? description
                  : 'B_music02',
          artist: '@b_music02',
          tiktokUrl: url,
          category: 'TikTok',
          thumbnailUrl:
              video['cover_image_url']?.toString(),
        ),
      );
    }

    return videos;
  }
}
