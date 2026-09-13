import 'package:flutter/material.dart';

import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';

class GroupRoomsScreen extends StatefulWidget {
  const GroupRoomsScreen({super.key});

  @override
  State<GroupRoomsScreen> createState() => _GroupRoomsScreenState();
}

class _GroupRoomsScreenState extends State<GroupRoomsScreen> {
  final SocialService _social = SocialService.instance;

  bool _loading = true;
  List<ChatRoom> _rooms = const [];
  Set<String> _joined = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _social.loadRooms(),
        _social.loadJoinedRoomIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _rooms = results[0] as List<ChatRoom>;
        _joined = results[1] as Set<String>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbet odaları yüklenemedi.')),
      );
    }
  }

  Future<void> _joinOrOpen(ChatRoom room) async {
    try {
      if (!_joined.contains(room.id)) {
        await _social.joinRoom(room.id);
        if (mounted) setState(() => _joined.add(room.id));
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupRoomChatPage(room: room),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaya katılınamadı.')),
      );
    }
  }

  Future<void> _leave(ChatRoom room) async {
    await _social.leaveRoom(room.id);
    if (mounted) setState(() => _joined.remove(room.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.gold,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
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
                          child: const Icon(
                            Icons.forum_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Müzik Odaları',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Türüne göre katıl, konuş, tepki ver',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _load,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (_rooms.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Text('Henüz sohbet odası yok.'),
                        ),
                      )
                    else
                      ..._rooms.map((room) {
                        final joined = _joined.contains(room.id);
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
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: AppColors.gold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      room.description ?? 'B_music02 sohbet odası',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (joined)
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'leave') _leave(room);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'leave',
                                      child: Text('Odadan ayrıl'),
                                    ),
                                  ],
                                ),
                              FilledButton.tonal(
                                onPressed: () => _joinOrOpen(room),
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

class GroupRoomChatPage extends StatefulWidget {
  const GroupRoomChatPage({
    super.key,
    required this.room,
  });

  final ChatRoom room;

  @override
  State<GroupRoomChatPage> createState() => _GroupRoomChatPageState();
}

class _GroupRoomChatPageState extends State<GroupRoomChatPage> {
  final SocialService _social = SocialService.instance;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Map<String, SocialProfile> _profiles = <String, SocialProfile>{};
  Map<String, dynamic>? _replyTo;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final profiles = await _social.loadProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = {for (final profile in profiles) profile.id: profile};
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await _social.sendRoomMessage(
        roomId: widget.room.id,
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
            if (mine)
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj şikâyeti gönderildi.')),
        );
      }
    } else if (choice == 'block') {
      await _social.blockUser(message['sender_id'].toString());
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _editMessage(Map<String, dynamic> message) async {
    final editor = TextEditingController(text: message['body']?.toString() ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mesajı düzenle'),
        content: TextField(
          controller: editor,
          autofocus: true,
          maxLines: 4,
        ),
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
    if (text?.trim().isNotEmpty == true) {
      await _social.editRoomMessage(message['id'].toString(), text!);
    }
  }

  String _name(String? id) {
    return _profiles[id]?.name ?? 'Kullanıcı';
  }

  String _time(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.name),
            const Text(
              'Grup sohbeti',
              style: TextStyle(fontSize: 9, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _social.roomMessageStream(widget.room.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  );
                }
                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Bu odada ilk mesajı sen gönder.'),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final senderId = message['sender_id']?.toString();
                    final mine = senderId == _social.user?.id;
                    return GestureDetector(
                      onLongPress: () => _messageMenu(message),
                      child: Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 310),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
                          decoration: BoxDecoration(
                            color: mine
                                ? AppColors.burgundy
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: mine
                                ? null
                                : Border.all(color: Theme.of(context).dividerColor),
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
                              Text(message['body']?.toString() ?? ''),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _time(message['created_at']?.toString()),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 8,
                                    ),
                                  ),
                                  if (message['edited_at'] != null)
                                    const Text(
                                      ' • düzenlendi',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 8,
                                      ),
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
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Mesaj yaz...',
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(15),
                    ),
                    child: _sending
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
