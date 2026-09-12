import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityHomeVideo {
  const CommunityHomeVideo({
    required this.id,
    required this.storagePath,
    required this.videoUrl,
    required this.createdAt,
    this.caption,
  });

  final String id;
  final String storagePath;
  final String videoUrl;
  final String? caption;
  final DateTime createdAt;
}

class CommunityVideoService {
  CommunityVideoService({
    SupabaseClient? supabase,
  }) : _supabase =
            supabase ??
            Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<CommunityHomeVideo>>
      fetchApprovedVideos({
    int limit = 30,
  }) async {
    final rows =
        await _supabase
            .from(
              'community_videos',
            )
            .select(
              'id, storage_path, caption, created_at',
            )
            .eq(
              'status',
              'approved',
            )
            .order(
              'created_at',
              ascending: false,
            )
            .limit(limit);

    final videos =
        <CommunityHomeVideo>[];

    for (final raw in rows) {
      final row =
          Map<String, dynamic>.from(
        raw,
      );

      final id =
          row['id']
              ?.toString();

      final storagePath =
          row['storage_path']
              ?.toString();

      if (id == null ||
          id.isEmpty ||
          storagePath == null ||
          storagePath.isEmpty) {
        continue;
      }

      try {
        final signedUrl =
            await _supabase.storage
                .from(
                  'community-videos',
                )
                .createSignedUrl(
                  storagePath,
                  3600,
                );

        final createdAt =
            DateTime.tryParse(
                  row['created_at']
                          ?.toString() ??
                      '',
                ) ??
                DateTime.now();

        videos.add(
          CommunityHomeVideo(
            id: id,
            storagePath:
                storagePath,
            videoUrl:
                signedUrl,
            caption:
                row['caption']
                    ?.toString(),
            createdAt:
                createdAt,
          ),
        );
      } catch (_) {
        // Tek bir video açılamazsa
        // diğer videolar yüklenmeye devam eder.
      }
    }

    return videos;
  }
}
