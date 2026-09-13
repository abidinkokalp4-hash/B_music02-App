import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';

class GroupRoomsV2Screen extends StatefulWidget {
  const GroupRoomsV2Screen({super.key});

  @override
  State<GroupRoomsV2Screen> createState() => _GroupRoomsV2ScreenState();
}

class _GroupRoomsV2ScreenState extends State<GroupRoomsV2Screen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SocialService _social = SocialService.instance;

  bool _loading = true;
  List<Map<String, dynamic>> _rooms = const [];
  Set<String> _joined = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final roomRows = await _supabase
          .from('chat_rooms')
          .select('id, name, slug, description, is_public, created_by, room_type, starts_at, created_at')
          .order('created_at', ascending: false);
      final joined = await _social.loadJoinedRoomIds();
      if (!mounted) return;
      setState(() {
        _rooms = roomRows.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
        _joined = joined;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Odalar yüklenemedi: $error');
    }
  }

  Future<void> _createRoom() async {
    final name = TextEditingController();
    final description = TextEditingController();
    String roomType = 'community';

    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Yeni müzik odası'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Oda adı',
                        prefixIcon: Icon(Icons.forum_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: description,
                      maxLength: 160,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Açıklama'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: roomType,
                      decoration: const InputDecoration(labelText: 'Oda türü'),
                      items: const [
                        DropdownMenuItem(value: 'community', child: Text('Genel müzik odası')),
                        DropdownMenuItem(value: 'fan', child: Text('Sanatçı / fan kulübü')),
                        DropdownMenuItem(value: 'event', child: Text('Etkinlik odası')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => roomType = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Oluştur'),
                ),
              ],
            );
          },
        );
      },
    );

    if (create == true) {
      final user = _supabase.auth.currentUser;
      final cleanName = name.text.trim();
      if (user == null || cleanName.isEmpty) {
        _message('Oda adı gerekli.');
      } else {
        try {
          final slug = '${_slug(cleanName)}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          final row = await _supabase
              .from('chat_rooms')
              .insert({
                'name': cleanName,
                'slug': slug,
                'description': description.text.trim().isEmpty ? null : description.text.trim(),
                'is_public': true,
                'created_by': user.id,
                'room_type': roomType,
              })
              .select('id')
              .single();
          await _social.joinRoom(row['id'].toString());
          await _load();
        } catch (error) {
          _message('Oda oluşturulamadı: $error');
        }
      }
    }

    name.dispose();
    description.dispose();
  }

  String _slug(String value) {
    const from = 'çğıöşüÇĞİÖŞÜ';
    const to = 'cgiosuCGIOSU';
    var text = value;
    for (var i = 0; i < from.length; i++) {
      text = text.replaceAll(from[i], to[i]);
    }
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .substring(0, text.length > 32 ? 32 : text.length)
        .replaceAll(RegExp(r'-+$'), '');
  }

  Future<void> _openRoom(Map<String, dynamic> room) async {
    final id = room['id'].toString();
    try {
      if (!_joined.contains(id)) {
        await _social.joinRoom(id);
        if (mounted) setState(() => _joined.add(id));
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MusicRoomChatPage(room: room)),
      );
    } catch (error) {
      _message('Odaya girilemedi: $error');
    }
  }

  Future<void> _leaveRoom(Map<String, dynamic> room) async {
    final id = room['id'].toString();
    await _social.leaveRoom(id);
    if (mounted) setState(() => _joined.remove(id));
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  IconData _roomIcon(String? type) {
    return switch (type) {
      'fan' => Icons.workspace_premium_rounded,
      'event' => Icons.event_available_rounded,
      _ => Icons.music_note_rounded,
    };
  }

  String _roomTypeText(String? type) {
    return switch (type) {
      'fan' => 'Fan kulübü',
      'event' => 'Etkinlik',
      _ => 'Müzik odası',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_music_room',
        onPressed: _createRoom,
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Oda Kur'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.gold,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [AppColors.gold, AppColors.burgundy],
                            ),
                          ),
                          child: const Icon(Icons.forum_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Müzik Odaları',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Oda kur • şarkı paylaş • sohbet et',
                                style: TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (_rooms.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: Text('İlk müzik odasını sen kur.')),
                      )
                    else
                      ..._rooms.map((room) {
                        final id = room['id'].toString();
                        final joined = _joined.contains(id);
                        final mine = room['created_by']?.toString() == _supabase.auth.currentUser?.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 11),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: joined
                                  ? AppColors.gold.withValues(alpha: 0.35)
                                  : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Icon(
                                  _roomIcon(room['room_type']?.toString()),
                                  color: AppColors.gold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            room['name']?.toString() ?? 'Müzik Odası',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        if (mine) ...[
                                          const SizedBox(width: 5),
                                          const Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold, size: 15),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${_roomTypeText(room['room_type']?.toString())} • ${room['description']?.toString() ?? 'B_music02 topluluğu'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                                    ),
                                  ],
                                ),
                              ),
                              if (joined)
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'leave') _leaveRoom(room);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'leave', child: Text('Odadan ayrıl')),
                                  ],
                                ),
                              FilledButton.tonal(
                                onPressed: () => _openRoom(room),
                                child: Text(joined ? 'Aç' : 'Katıl'),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
        ),
      ),
    );
  }
}

class MusicRoomChatPage extends StatefulWidget {
  const MusicRoomChatPage({
    super.key,
    required this.room,
  });

  final Map<String, dynamic> room;

  @override
  State<MusicRoomChatPage> createState() => _MusicRoomChatPageState();
}

class _MusicRoomChatPageState extends State<MusicRoomChatPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SocialService _social = SocialService.instance;
  final LocalMusicService _music = LocalMusicService.instance;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  Map<String, SocialProfile> _profiles = <String, SocialProfile>{};
  Map<String, dynamic>? _replyTo;
  bool _sending = false;

  String get _roomId => widget.room['id'].toString();
  bool get _isRoomOwner =>
      widget.room['created_by']?.toString() == _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final profiles = await _social.loadProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = {for (final item in profiles) item.id: item};
      });
    } catch (_) {}
  }

  Future<void> _sendText() async {
    if (_sending || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _social.sendRoomMessage(
        roomId: _roomId,
        body: _controller.text,
        replyTo: _replyTo?['id']?.toString(),
      );
      _controller.clear();
      if (mounted) setState(() => _replyTo = null);
      _focus.requestFocus();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendCurrentSong() async {
    final user = _supabase.auth.currentUser;
    final tag = _music.player.sequenceState.currentSource?.tag;
    final item = tag is MediaItem ? tag : null;
    if (user == null || item == null) {
      _message('Önce Müziklerim bölümünden bir şarkı çal.');
      return;
    }

    await _supabase.from('room_messages').insert({
      'room_id': _roomId,
      'sender_id': user.id,
      'body': '${item.title} — ${item.artist ?? 'Bilinmeyen sanatçı'}',
      'reply_to': _replyTo?['id'],
      'message_type': 'song',
      'metadata': {
        'song_id': item.id,
        'title': item.title,
        'artist': item.artist,
        'album': item.album,
        'art_uri': item.artUri?.toString(),
      },
    });
    if (mounted) setState(() => _replyTo = null);
  }

  Future<Map<String, int>> _reactions(String messageId) async {
    return _social.loadReactionCounts(type: 'room', messageId: messageId);
  }

  Future<void> _togglePin(Map<String, dynamic> message) async {
    if (!_isRoomOwner) return;
    await _supabase
        .from('room_messages')
        .update({'is_pinned': message['is_pinned'] != true})
        .eq('id', message['id']);
  }

  Future<void> _messageMenu(Map<String, dynamic> message) async {
    final mine = message['sender_id']?.toString() == _social.user?.id;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Yanıtla'),
              onTap: () => Navigator.pop(sheetContext, 'reply'),
            ),
            for (final emoji in const ['❤️', '🔥', '😂', '🎵'])
              ListTile(
                leading: Text(emoji, style: const TextStyle(fontSize: 22)),
                title: Text('$emoji tepki ver'),
                onTap: () => Navigator.pop(sheetContext, 'react:$emoji'),
              ),
            if (_isRoomOwner)
              ListTile(
                leading: Icon(message['is_pinned'] == true ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(message['is_pinned'] == true ? 'Sabitlemeyi kaldır' : 'Mesajı sabitle'),
                onTap: () => Navigator.pop(sheetContext, 'pin'),
              ),
            if (mine && message['message_type'] != 'song')
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Düzenle'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Sil'),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Şikâyet et'),
                onTap: () => Navigator.pop(sheetContext, 'report'),
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: const Text('Kullanıcıyı engelle'),
                onTap: () => Navigator.pop(sheetContext, 'block'),
              ),
          ],
        ),
      ),
    );

    if (choice == null) return;
    final id = message['id']?.toString() ?? '';
    if (choice == 'reply') {
      setState(() => _replyTo = message);
      _focus.requestFocus();
    } else if (choice.startsWith('react:')) {
      await _social.reactToMessage(
        type: 'room',
        messageId: id,
        emoji: choice.substring(6),
      );
      if (mounted) setState(() {});
    } else if (choice == 'pin') {
      await _togglePin(message);
    } else if (choice == 'delete') {
      await _social.deleteRoomMessage(id);
    } else if (choice == 'edit') {
      await _editMessage(message);
    } else if (choice == 'report') {
      await _social.reportMessage(
        type: 'room',
        messageId: id,
        reportedUserId: message['sender_id'].toString(),
        snapshot: message['body']?.toString() ?? '',
      );
      _message('Mesaj şikâyeti gönderildi.');
    } else if (choice == 'block') {
      await _social.blockUser(message['sender_id'].toString());
      _message('Kullanıcı engellendi.');
    }
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final editor = TextEditingController(text: message['body']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mesajı düzenle'),
        content: TextField(controller: editor, autofocus: true, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editor.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    editor.dispose();
    if (value?.trim().isNotEmpty == true) {
      await _social.editRoomMessage(message['id'].toString(), value!);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _name(String? id) => _profiles[id]?.name ?? 'Kullanıcı';

  String _time(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _songCard(Map<String, dynamic> message) {
    final raw = message['metadata'];
    final metadata = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: AppColors.gold.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.music_note_rounded, color: AppColors.gold),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata['title']?.toString() ?? message['body']?.toString() ?? 'Müzik',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  metadata['artist']?.toString() ?? 'Bilinmeyen sanatçı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.gold, fontSize: 9),
                ),
              ],
            ),
          ),
          const Icon(Icons.headphones_rounded, color: AppColors.gold, size: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room['name']?.toString() ?? 'Müzik Odası'),
            Text(
              _isRoomOwner ? 'Oda yöneticisi sensin' : 'B_music02 grup sohbeti',
              style: const TextStyle(fontSize: 9, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _social.roomMessageStream(_roomId),
            builder: (context, snapshot) {
              final pinned = (snapshot.data ?? const <Map<String, dynamic>>[])
                  .where((message) => message['is_pinned'] == true)
                  .toList();
              if (pinned.isEmpty) return const SizedBox.shrink();
              final latest = pinned.first;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppColors.gold.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin_rounded, color: AppColors.gold, size: 17),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        latest['body']?.toString() ?? 'Sabitlenen mesaj',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _social.roomMessageStream(_roomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.gold));
                }
                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return const Center(child: Text('Bu odada ilk mesajı sen gönder.'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final senderId = message['sender_id']?.toString();
                    final mine = senderId == _social.user?.id;
                    final isSong = message['message_type']?.toString() == 'song';
                    return GestureDetector(
                      onLongPress: () => _messageMenu(message),
                      child: Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.burgundy : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: mine ? null : Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Text(
                                  _name(senderId),
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              if (message['reply_to'] != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 5),
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '↩ Yanıtlanan mesaj',
                                    style: TextStyle(fontSize: 9, color: Colors.white54),
                                  ),
                                ),
                              if (isSong) _songCard(message) else Text(message['body']?.toString() ?? ''),
                              const SizedBox(height: 5),
                              FutureBuilder<Map<String, int>>(
                                future: _reactions(message['id'].toString()),
                                builder: (context, reactionSnapshot) {
                                  final counts = reactionSnapshot.data ?? const <String, int>{};
                                  if (counts.isEmpty) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      counts.entries.map((entry) => '${entry.key}${entry.value}').join(' '),
                                      style: const TextStyle(fontSize: 9, color: Colors.white70),
                                    ),
                                  );
                                },
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (message['is_pinned'] == true)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.push_pin_rounded, size: 11, color: AppColors.gold),
                                    ),
                                  Text(
                                    _time(message['created_at']?.toString()),
                                    style: const TextStyle(color: Colors.white38, fontSize: 8),
                                  ),
                                  if (message['edited_at'] != null)
                                    const Text(
                                      ' • düzenlendi',
                                      style: TextStyle(color: Colors.white38, fontSize: 8),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_replyTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppColors.gold.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, color: AppColors.gold, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _replyTo?['body']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _replyTo = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Çalan şarkıyı paylaş',
                    onPressed: _sendCurrentSong,
                    icon: const Icon(Icons.music_note_rounded, color: AppColors.gold),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(hintText: 'Mesaj yaz...'),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 7),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendText,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
