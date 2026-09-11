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

    if (uri == null) {
      return false;
    }

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
    final allVideos = <VideoItem>[];

    int? cursor;
    bool hasMore = true;

    for (int page = 0; page < 20 && hasMore; page++) {
      try {
        final Uri uri;

        if (cursor == null) {
          uri = Uri.parse(_apiUrl);
        } else {
          uri = Uri.parse(
            '$_apiUrl?cursor=${Uri.encodeComponent(cursor.toString())}',
          );
        }

        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          if (allVideos.isNotEmpty) {
            break;
          }

          throw Exception(
            'Sunucu hatası: ${response.statusCode}',
          );
        }

        final decoded = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        if (decoded is! Map<String, dynamic>) {
          if (allVideos.isNotEmpty) {
            break;
          }

          throw Exception('Geçersiz sunucu cevabı.');
        }

        if (decoded['ok'] != true) {
          if (allVideos.isNotEmpty) {
            break;
          }

          throw Exception(
            decoded['message']?.toString() ??
                'TikTok videoları alınamadı.',
          );
        }

        final rawVideos = decoded['videos'];

        if (rawVideos is List) {
          for (final rawVideo in rawVideos) {
            if (rawVideo is! Map) continue;

            final video =
                Map<String, dynamic>.from(rawVideo);

            final id =
                video['id']?.toString().trim() ?? '';

            final shareUrl =
                video['share_url']?.toString().trim() ?? '';

            if (id.isEmpty || shareUrl.isEmpty) {
              continue;
            }

            final description =
                video['video_description']
                        ?.toString()
                        .trim() ??
                    '';

            final apiTitle =
                video['title']?.toString().trim() ?? '';

            final title = apiTitle.isNotEmpty
                ? apiTitle
                : description.isNotEmpty
                    ? description
                    : 'B_music02';

            final thumbnail =
                video['cover_image_url']
                    ?.toString()
                    .trim();

            if (allVideos.any((item) => item.id == id)) {
              continue;
            }

            allVideos.add(
              VideoItem(
                id: id,
                title: title,
                artist: '@b_music02',
                tiktokUrl: shareUrl,
                category: 'TikTok',
                thumbnailUrl:
                    thumbnail != null && thumbnail.isNotEmpty
                        ? thumbnail
                        : null,
              ),
            );
          }
        }

        final nextCursor = decoded['cursor'];

        if (nextCursor is int) {
          cursor = nextCursor;
        } else {
          cursor = int.tryParse(
            nextCursor?.toString() ?? '',
          );
        }

        hasMore =
            decoded['has_more'] == true && cursor != null;
      } catch (_) {
        // İlk sayfadan video geldiyse sonraki sayfadaki
        // geçici hata yüzünden bütün listeyi çöpe atma.
        if (allVideos.isNotEmpty) {
          break;
        }

        rethrow;
      }
    }

    if (allVideos.isEmpty) {
      throw Exception('TikTok videosu bulunamadı.');
    }

    return allVideos;
  }
}
