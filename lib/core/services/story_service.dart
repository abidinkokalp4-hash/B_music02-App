import 'package:supabase_flutter/supabase_flutter.dart';

class MusicStory {
  const MusicStory({
    required this.id,
    required this.userId,
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.startSecond,
    required this.createdAt,
    required this.expiresAt,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String userId;
  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int startSecond;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String username;
  final String displayName;
  final String avatarUrl;

  String get profileName {
    final display = displayName.trim();
    if (display.isNotEmpty) return display;
    final user = username.trim();
    return user.isEmpty ? 'B_music02' : user;
  }
}

class StoryService {
  StoryService._();

  static final StoryService instance = StoryService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<MusicStory>> activeStories() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('music_stories')
        .select(
          'id,user_id,video_id,title,artist,thumbnail_url,start_second,created_at,expires_at,profiles(username,display_name,avatar_url)',
        )
        .gt('expires_at', now)
        .order('created_at', ascending: false)
        .limit(60);

    return rows.map<MusicStory>((raw) {
      final map = Map<String, dynamic>.from(raw);
      final profileRaw = map['profiles'];
      final profile = profileRaw is Map
          ? Map<String, dynamic>.from(profileRaw)
          : <String, dynamic>{};
      return MusicStory(
        id: map['id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        videoId: map['video_id']?.toString() ?? '',
        title: map['title']?.toString() ?? 'Müzik',
        artist: map['artist']?.toString() ?? '',
        thumbnailUrl: map['thumbnail_url']?.toString() ?? '',
        startSecond: int.tryParse(map['start_second']?.toString() ?? '') ?? 0,
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now().toUtc(),
        expiresAt: DateTime.tryParse(map['expires_at']?.toString() ?? '') ?? DateTime.now().toUtc(),
        username: profile['username']?.toString() ?? '',
        displayName: profile['display_name']?.toString() ?? '',
        avatarUrl: profile['avatar_url']?.toString() ?? '',
      );
    }).where((story) => story.id.isNotEmpty && story.videoId.isNotEmpty).toList();
  }

  Future<void> createStory({
    required String videoId,
    required String title,
    required String artist,
    required String thumbnailUrl,
    required int startSecond,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Hikâye paylaşmak için giriş yapmalısınız.');

    await _client.from('music_stories').insert({
      'user_id': user.id,
      'video_id': videoId,
      'title': title.trim(),
      'artist': artist.trim(),
      'thumbnail_url': thumbnailUrl.trim(),
      'start_second': startSecond < 0 ? 0 : startSecond,
      'duration_seconds': 15,
      'expires_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
    });
  }

  Future<void> deleteStory(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('music_stories').delete().eq('id', id).eq('user_id', user.id);
  }
}
