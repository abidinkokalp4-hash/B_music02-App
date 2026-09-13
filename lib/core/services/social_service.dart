import 'package:supabase_flutter/supabase_flutter.dart';

class SocialService {
  SocialService._();

  static final SocialService instance = SocialService._();

  SupabaseClient get _supabase => Supabase.instance.client;
  User? get user => _supabase.auth.currentUser;

  Future<List<SocialProfile>> loadProfiles() async {
    final rows = await _supabase
        .from('profiles')
        .select(
          'id, username, display_name, avatar_url, bio, app_role, show_listening_status, dm_privacy, last_seen_at',
        )
        .order('username');

    return rows
        .map<SocialProfile>(
          (raw) => SocialProfile.fromMap(Map<String, dynamic>.from(raw)),
        )
        .toList();
  }

  Future<Set<String>> loadFollowingIds() async {
    final current = user;
    if (current == null) return <String>{};

    final rows = await _supabase
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', current.id);

    return rows
        .map<String>((row) => row['following_id'].toString())
        .toSet();
  }

  Future<bool> toggleFollow(String profileId) async {
    final current = user;
    if (current == null || current.id == profileId) return false;

    final existing = await _supabase
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', current.id)
        .eq('following_id', profileId)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('user_follows')
          .delete()
          .eq('follower_id', current.id)
          .eq('following_id', profileId);
      return false;
    }

    await _supabase.from('user_follows').insert({
      'follower_id': current.id,
      'following_id': profileId,
    });
    return true;
  }

  Future<List<ListeningPresence>> loadListeningPresence() async {
    final presenceRows = await _supabase
        .from('user_music_presence')
        .select(
          'user_id, song_title, artist, album, is_playing, is_public, updated_at',
        )
        .eq('is_public', true)
        .order('updated_at', ascending: false)
        .limit(20);

    if (presenceRows.isEmpty) return <ListeningPresence>[];

    final profiles = await loadProfiles();
    final byId = <String, SocialProfile>{
      for (final profile in profiles) profile.id: profile,
    };

    return presenceRows.map<ListeningPresence>((raw) {
      final map = Map<String, dynamic>.from(raw);
      final id = map['user_id'].toString();
      return ListeningPresence.fromMap(
        map,
        profile: byId[id],
      );
    }).toList();
  }

  Future<void> publishListeningPresence({
    required String? title,
    required String? artist,
    required String? album,
    required bool isPlaying,
  }) async {
    final current = user;
    if (current == null) return;

    bool isPublic = true;
    try {
      final profile = await _supabase
          .from('profiles')
          .select('show_listening_status')
          .eq('id', current.id)
          .single();
      isPublic = profile['show_listening_status'] != false;
    } catch (_) {}

    await _supabase.from('user_music_presence').upsert(
      {
        'user_id': current.id,
        'song_title': title,
        'artist': artist,
        'album': album,
        'is_playing': isPlaying,
        'is_public': isPublic,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  Future<List<CommunityPoll>> loadPolls() async {
    final pollRows = await _supabase
        .from('community_polls')
        .select('id, user_id, question, is_active, expires_at, created_at')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(20);

    final optionRows = await _supabase
        .from('community_poll_options')
        .select('id, poll_id, label, sort_order')
        .order('sort_order');

    final voteRows = await _supabase
        .from('community_poll_votes')
        .select('poll_id, option_id, user_id');

    final currentUserId = user?.id;
    final optionsByPoll = <String, List<PollOption>>{};
    final counts = <String, int>{};
    final selectedByPoll = <String, String>{};

    for (final raw in voteRows) {
      final row = Map<String, dynamic>.from(raw);
      final optionId = row['option_id'].toString();
      counts[optionId] = (counts[optionId] ?? 0) + 1;
      if (currentUserId != null && row['user_id']?.toString() == currentUserId) {
        selectedByPoll[row['poll_id'].toString()] = optionId;
      }
    }

    for (final raw in optionRows) {
      final row = Map<String, dynamic>.from(raw);
      final pollId = row['poll_id'].toString();
      final option = PollOption(
        id: row['id'].toString(),
        label: row['label']?.toString() ?? '',
        votes: counts[row['id'].toString()] ?? 0,
      );
      optionsByPoll.putIfAbsent(pollId, () => <PollOption>[]).add(option);
    }

    return pollRows.map<CommunityPoll>((raw) {
      final row = Map<String, dynamic>.from(raw);
      final id = row['id'].toString();
      return CommunityPoll(
        id: id,
        userId: row['user_id'].toString(),
        question: row['question']?.toString() ?? '',
        options: optionsByPoll[id] ?? <PollOption>[],
        selectedOptionId: selectedByPoll[id],
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
      );
    }).toList();
  }

  Future<void> createPoll(String question, List<String> options) async {
    final current = user;
    final cleanQuestion = question.trim();
    final cleanOptions = options
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (current == null || cleanQuestion.isEmpty || cleanOptions.length < 2) {
      throw ArgumentError('Anket için soru ve en az iki seçenek gerekli.');
    }

    final poll = await _supabase
        .from('community_polls')
        .insert({
          'user_id': current.id,
          'question': cleanQuestion,
          'is_active': true,
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(days: 7))
              .toIso8601String(),
        })
        .select('id')
        .single();

    final pollId = poll['id'].toString();
    await _supabase.from('community_poll_options').insert(
      List.generate(
        cleanOptions.length,
        (index) => {
          'poll_id': pollId,
          'label': cleanOptions[index],
          'sort_order': index,
        },
      ),
    );
  }

  Future<void> vote(String pollId, String optionId) async {
    final current = user;
    if (current == null) return;

    await _supabase.from('community_poll_votes').upsert(
      {
        'poll_id': pollId,
        'option_id': optionId,
        'user_id': current.id,
      },
      onConflict: 'poll_id,user_id',
    );
  }

  Future<List<ChatRoom>> loadRooms() async {
    final rows = await _supabase
        .from('chat_rooms')
        .select('id, name, slug, description, is_public, created_at')
        .order('name');

    return rows
        .map<ChatRoom>(
          (raw) => ChatRoom.fromMap(Map<String, dynamic>.from(raw)),
        )
        .toList();
  }

  Future<Set<String>> loadJoinedRoomIds() async {
    final current = user;
    if (current == null) return <String>{};

    final rows = await _supabase
        .from('chat_room_members')
        .select('room_id')
        .eq('user_id', current.id);

    return rows.map<String>((row) => row['room_id'].toString()).toSet();
  }

  Future<void> joinRoom(String roomId) async {
    final current = user;
    if (current == null) return;

    await _supabase.from('chat_room_members').upsert(
      {
        'room_id': roomId,
        'user_id': current.id,
        'role': 'member',
      },
      onConflict: 'room_id,user_id',
    );
  }

  Future<void> leaveRoom(String roomId) async {
    final current = user;
    if (current == null) return;

    await _supabase
        .from('chat_room_members')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', current.id);
  }

  Stream<List<Map<String, dynamic>>> roomMessageStream(String roomId) {
    return _supabase
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
  }

  Future<void> sendRoomMessage({
    required String roomId,
    required String body,
    String? replyTo,
  }) async {
    final current = user;
    final clean = body.trim();
    if (current == null || clean.isEmpty) return;

    await _supabase.from('room_messages').insert({
      'room_id': roomId,
      'sender_id': current.id,
      'body': clean,
      'reply_to': replyTo,
      'message_type': 'text',
    });
  }

  Future<void> editRoomMessage(String messageId, String body) async {
    final clean = body.trim();
    if (clean.isEmpty) return;
    await _supabase.from('room_messages').update({
      'body': clean,
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> deleteRoomMessage(String messageId) async {
    await _supabase.from('room_messages').delete().eq('id', messageId);
  }

  Future<void> reactToMessage({
    required String type,
    required String messageId,
    required String emoji,
  }) async {
    final current = user;
    if (current == null) return;

    await _supabase.from('message_reactions').upsert(
      {
        'message_type': type,
        'message_id': messageId,
        'user_id': current.id,
        'emoji': emoji,
      },
      onConflict: 'message_type,message_id,user_id',
    );
  }

  Future<Map<String, int>> loadReactionCounts({
    required String type,
    required String messageId,
  }) async {
    final rows = await _supabase
        .from('message_reactions')
        .select('emoji')
        .eq('message_type', type)
        .eq('message_id', messageId);

    final counts = <String, int>{};
    for (final row in rows) {
      final emoji = row['emoji']?.toString() ?? '';
      if (emoji.isNotEmpty) counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> reportMessage({
    required String type,
    required String messageId,
    required String reportedUserId,
    required String snapshot,
    String reason = 'Uygunsuz içerik',
  }) async {
    final current = user;
    if (current == null || current.id == reportedUserId) return;

    await _supabase.from('message_reports').insert({
      'reporter_id': current.id,
      'reported_user_id': reportedUserId,
      'message_type': type,
      'message_id': messageId,
      'message_snapshot': snapshot,
      'reason': reason,
      'status': 'open',
    });
  }

  Future<void> blockUser(String userId) async {
    final current = user;
    if (current == null || current.id == userId) return;

    await _supabase.from('user_blocks').upsert(
      {
        'blocker_id': current.id,
        'blocked_id': userId,
      },
      onConflict: 'blocker_id,blocked_id',
    );
  }

  Future<void> backupMusic(Map<String, dynamic> payload) async {
    final current = user;
    if (current == null) throw StateError('Oturum bulunamadı.');

    await _supabase.from('user_music_backups').upsert(
      {
        'user_id': current.id,
        'payload': payload,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  Future<Map<String, dynamic>?> restoreMusicBackup() async {
    final current = user;
    if (current == null) return null;

    final row = await _supabase
        .from('user_music_backups')
        .select('payload')
        .eq('user_id', current.id)
        .maybeSingle();

    if (row == null || row['payload'] is! Map) return null;
    return Map<String, dynamic>.from(row['payload'] as Map);
  }

  Future<void> touchLastSeen() async {
    final current = user;
    if (current == null) return;
    await _supabase.from('profiles').update({
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', current.id);
  }
}

class SocialProfile {
  const SocialProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.role,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String role;

  String get name => displayName.trim().isNotEmpty ? displayName : username;

  factory SocialProfile.fromMap(Map<String, dynamic> map) {
    final username = map['username']?.toString() ?? 'kullanici';
    return SocialProfile(
      id: map['id'].toString(),
      username: username,
      displayName: map['display_name']?.toString() ?? username,
      avatarUrl: map['avatar_url']?.toString(),
      bio: map['bio']?.toString(),
      role: map['app_role']?.toString() ?? 'user',
    );
  }
}

class ListeningPresence {
  const ListeningPresence({
    required this.userId,
    required this.title,
    required this.artist,
    required this.album,
    required this.isPlaying,
    required this.updatedAt,
    this.profile,
  });

  final String userId;
  final String? title;
  final String? artist;
  final String? album;
  final bool isPlaying;
  final DateTime? updatedAt;
  final SocialProfile? profile;

  factory ListeningPresence.fromMap(
    Map<String, dynamic> map, {
    SocialProfile? profile,
  }) {
    return ListeningPresence(
      userId: map['user_id'].toString(),
      title: map['song_title']?.toString(),
      artist: map['artist']?.toString(),
      album: map['album']?.toString(),
      isPlaying: map['is_playing'] == true,
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
      profile: profile,
    );
  }
}

class PollOption {
  const PollOption({
    required this.id,
    required this.label,
    required this.votes,
  });

  final String id;
  final String label;
  final int votes;
}

class CommunityPoll {
  const CommunityPoll({
    required this.id,
    required this.userId,
    required this.question,
    required this.options,
    required this.selectedOptionId,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String userId;
  final String question;
  final List<PollOption> options;
  final String? selectedOptionId;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  int get totalVotes => options.fold<int>(0, (sum, option) => sum + option.votes);
}

class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.isPublic,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final bool isPublic;

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      id: map['id'].toString(),
      name: map['name']?.toString() ?? 'Oda',
      slug: map['slug']?.toString() ?? '',
      description: map['description']?.toString(),
      isPublic: map['is_public'] != false,
    );
  }
}
