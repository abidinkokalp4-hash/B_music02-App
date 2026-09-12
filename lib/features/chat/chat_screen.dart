import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _gold = Color(0xFFD4AF57);
const _burgundy = Color(0xFF7A1F3D);
const _background = Color(0xFF090909);
const _surface = Color(0xFF151114);

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            20,
            18,
            120,
          ),
          children: [
            const Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: _burgundy,
                  child: Icon(
                    Icons.forum_rounded,
                    color: _gold,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sohbet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'B_music02 topluluğu',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            const Text(
              'Toplulukla bağlantıda kal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Herkesle sohbet et veya bir kullanıcıya özel mesaj gönder.',
              style: TextStyle(
                color: Colors.white54,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 22),

            _ChatCard(
              icon: Icons.public_rounded,
              title: 'Global Sohbet',
              subtitle:
                  'B_music02 topluluğundaki herkesle canlı sohbet et.',
              badge: 'TOPLULUK',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const GlobalChatScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            _ChatCard(
              icon: Icons.mark_chat_unread_outlined,
              title: 'Özel Mesajlar',
              subtitle:
                  'Kullanıcı ara ve birebir özel sohbet başlat.',
              badge: 'ÖZEL',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const PrivateChatsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF21131A),
                Color(0xFF121212),
              ],
            ),
            border: Border.all(
              color: _gold.withOpacity(0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _burgundy.withOpacity(0.48),
                  border: Border.all(
                    color: _gold.withOpacity(0.45),
                  ),
                ),
                child: Icon(
                  icon,
                  color: _gold,
                  size: 29,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.10),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 9,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 7),

              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// GLOBAL SOHBET
// =======================================================

class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({super.key});

  @override
  State<GlobalChatScreen> createState() =>
      _GlobalChatScreenState();
}

class _GlobalChatScreenState
    extends State<GlobalChatScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final Map<String, Map<String, dynamic>>
      _profileCache = {};

  final Set<String> _blockedUsers = {};

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedUsers() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    try {
      final rows = await _supabase
          .from('user_blocks')
          .select('blocker_id,blocked_id');

      final ids = <String>{};

      for (final row in rows) {
        final blocker =
            row['blocker_id']?.toString();

        final blocked =
            row['blocked_id']?.toString();

        if (blocker == user.id &&
            blocked != null) {
          ids.add(blocked);
        }

        if (blocked == user.id &&
            blocker != null) {
          ids.add(blocker);
        }
      }

      if (!mounted) return;

      setState(() {
        _blockedUsers
          ..clear()
          ..addAll(ids);
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _getProfile(
    String userId,
  ) async {
    if (_profileCache.containsKey(userId)) {
      return _profileCache[userId]!;
    }

    try {
      final row = await _supabase
          .from('profiles')
          .select(
            'id,username,display_name,avatar_url',
          )
          .eq('id', userId)
          .single();

      final profile =
          Map<String, dynamic>.from(row);

      _profileCache[userId] = profile;

      return profile;
    } catch (_) {
      return {
        'id': userId,
        'username': 'kullanici',
      };
    }
  }

  Future<void> _sendMessage() async {
    final user = _supabase.auth.currentUser;
    final text = _controller.text.trim();

    if (user == null ||
        text.isEmpty ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _supabase
          .from('global_messages')
          .insert({
        'sender_id': user.id,
        'body': text,
      });

      _controller.clear();
    } catch (_) {
      _message('Mesaj gönderilemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _deleteMessage(
    String id,
  ) async {
    try {
      await _supabase
          .from('global_messages')
          .delete()
          .eq('id', id);
    } catch (_) {
      _message('Mesaj silinemedi.');
    }
  }

  Future<void> _blockUser(
    String userId,
  ) async {
    final me = _supabase.auth.currentUser;

    if (me == null) return;

    try {
      await _supabase
          .from('user_blocks')
          .insert({
        'blocker_id': me.id,
        'blocked_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        _message(
          'Kullanıcı engellenemedi.',
        );
        return;
      }
    }

    if (!mounted) return;

    setState(() {
      _blockedUsers.add(userId);
    });

    _message('Kullanıcı engellendi.');
  }

  Future<void> _reportMessage({
    required String messageId,
    required String senderId,
    required String text,
  }) async {
    final me = _supabase.auth.currentUser;

    if (me == null) return;

    final reason =
        await _selectReportReason();

    if (reason == null) return;

    try {
      await _supabase
          .from('message_reports')
          .insert({
        'reporter_id': me.id,
        'reported_user_id': senderId,
        'message_type': 'global',
        'message_id': messageId,
        'message_snapshot': text,
        'reason': reason,
      });

      _message(
        'Şikâyet yöneticiye gönderildi.',
      );
    } catch (_) {
      _message(
        'Şikâyet gönderilemedi.',
      );
    }
  }

  Future<String?> _selectReportReason() async {
    String reason = 'Uygunsuz içerik';

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              backgroundColor: _surface,
              title: const Text(
                'Mesajı Şikâyet Et',
              ),
              content:
                  DropdownButtonFormField<String>(
                value: reason,
                items: const [
                  DropdownMenuItem(
                    value: 'Uygunsuz içerik',
                    child: Text(
                      'Uygunsuz içerik',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Hakaret',
                    child: Text('Hakaret'),
                  ),
                  DropdownMenuItem(
                    value: 'Spam',
                    child: Text('Spam'),
                  ),
                  DropdownMenuItem(
                    value: 'Diğer',
                    child: Text('Diğer'),
                  ),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    reason =
                        value ?? reason;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      reason,
                    );
                  },
                  child:
                      const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId =
        _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Global Sohbet',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'B_music02 topluluğu',
              style: TextStyle(
                color: _gold,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<
                List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('global_messages')
                  .stream(
                    primaryKey: ['id'],
                  )
                  .order('created_at'),
              builder: (
                context,
                snapshot,
              ) {
                final messages =
                    (snapshot.data ?? [])
                        .where(
                          (message) =>
                              !_blockedUsers
                                  .contains(
                            message['sender_id']
                                ?.toString(),
                          ),
                        )
                        .toList();

                if (messages.isEmpty) {
                  return const _EmptyChat(
                    title:
                        'Henüz mesaj yok',
                    subtitle:
                        'İlk mesajı siz gönderin.',
                  );
                }

                return ListView.builder(
                  controller:
                      _scrollController,
                  padding:
                      const EdgeInsets.fromLTRB(
                    14,
                    12,
                    14,
                    16,
                  ),
                  itemCount:
                      messages.length,
                  itemBuilder: (
                    context,
                    index,
                  ) {
                    final message =
                        messages[index];

                    final senderId =
                        message['sender_id']
                                ?.toString() ??
                            '';

                    final mine =
                        senderId == myId;

                    final body =
                        message['body']
                                ?.toString() ??
                            '';

                    return FutureBuilder<
                        Map<String,
                            dynamic>>(
                      future: _getProfile(
                        senderId,
                      ),
                      builder: (
                        context,
                        profileSnapshot,
                      ) {
                        final profile =
                            profileSnapshot
                                    .data ??
                                {};

                        final username =
                            profile['username']
                                    ?.toString() ??
                                'kullanici';

                        return _MessageBubble(
                          mine: mine,
                          username:
                              username,
                          body: body,
                          onLongPress:
                              () {
                            _showGlobalOptions(
                              context:
                                  context,
                              mine: mine,
                              message:
                                  message,
                              senderId:
                                  senderId,
                              username:
                                  username,
                              body: body,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          _MessageComposer(
            controller: _controller,
            sending: _sending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  void _showGlobalOptions({
    required BuildContext context,
    required bool mine,
    required Map<String, dynamic> message,
    required String senderId,
    required String username,
    required String body,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              if (mine)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Mesajı Sil',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _deleteMessage(
                      message['id']
                          .toString(),
                    );
                  },
                )
              else ...[
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: _gold,
                  ),
                  title: const Text(
                    'Şikâyet Et',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _reportMessage(
                      messageId:
                          message['id']
                              .toString(),
                      senderId: senderId,
                      text: body,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.block_outlined,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    '@$username kullanıcısını engelle',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _blockUser(
                      senderId,
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// =======================================================
// ÖZEL SOHBET / KULLANICI ARAMA
// =======================================================

class PrivateChatsScreen
    extends StatefulWidget {
  const PrivateChatsScreen({
    super.key,
  });

  @override
  State<PrivateChatsScreen> createState() =>
      _PrivateChatsScreenState();
}

class _PrivateChatsScreenState
    extends State<PrivateChatsScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final TextEditingController _search =
      TextEditingController();

  List<Map<String, dynamic>> _users =
      [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final me =
        _supabase.auth.currentUser;

    if (me == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final rows = await _supabase
          .from('profiles')
          .select(
            'id,username,display_name,avatar_url',
          )
          .order('username');

      final users =
          <Map<String, dynamic>>[];

      for (final row in rows) {
        final item =
            Map<String, dynamic>.from(
          row,
        );

        if (item['id']?.toString() ==
            me.id) {
          continue;
        }

        users.add(item);
      }

      if (!mounted) return;

      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>>
      get _filtered {
    final query =
        _search.text
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      return _users;
    }

    return _users.where((user) {
      final username =
          user['username']
                  ?.toString()
                  .toLowerCase() ??
              '';

      final displayName =
          user['display_name']
                  ?.toString()
                  .toLowerCase() ??
              '';

      return username.contains(
            query,
          ) ||
          displayName.contains(
            query,
          );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text(
          'Özel Mesaj',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12,
            ),
            child: TextField(
              controller: _search,
              onChanged: (_) {
                setState(() {});
              },
              decoration:
                  InputDecoration(
                hintText:
                    'Kullanıcı adı ara',
                prefixIcon:
                    const Icon(
                  Icons.search_rounded,
                  color: _gold,
                ),
                filled: true,
                fillColor: _surface,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  borderSide:
                      BorderSide(
                    color: Colors.white
                        .withOpacity(
                      0.08,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(
                      color: _gold,
                    ),
                  )
                : users.isEmpty
                    ? const _EmptyChat(
                        title:
                            'Kullanıcı bulunamadı',
                        subtitle:
                            'Başka bir kullanıcı adı deneyin.',
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          5,
                          16,
                          30,
                        ),
                        itemCount:
                            users.length,
                        separatorBuilder:
                            (_, __) =>
                                const SizedBox(
                          height: 8,
                        ),
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final user =
                              users[index];

                          return _UserTile(
                            user: user,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PrivateChatRoomScreen(
                                    otherUser:
                                        user,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final username =
        user['username']?.toString() ??
            'kullanici';

    final displayName =
        user['display_name']
            ?.toString();

    final avatar =
        user['avatar_url']?.toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(20),
        child: Ink(
          padding:
              const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                    _burgundy,
                backgroundImage:
                    avatar != null &&
                            avatar.isNotEmpty
                        ? NetworkImage(
                            avatar,
                          )
                        : null,
                child: avatar == null ||
                        avatar.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: _gold,
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName != null &&
                              displayName
                                  .trim()
                                  .isNotEmpty
                          ? displayName
                          : '@$username',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chat_bubble_outline_rounded,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// BİREBİR MESAJLAŞMA
// =======================================================

class PrivateChatRoomScreen
    extends StatefulWidget {
  const PrivateChatRoomScreen({
    super.key,
    required this.otherUser,
  });

  final Map<String, dynamic>
      otherUser;

  @override
  State<PrivateChatRoomScreen>
      createState() =>
          _PrivateChatRoomScreenState();
}

class _PrivateChatRoomScreenState
    extends State<PrivateChatRoomScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final TextEditingController _controller =
      TextEditingController();

  bool _sending = false;
  bool _blocked = false;

  String get _otherId =>
      widget.otherUser['id']
          .toString();

  String get _username =>
      widget.otherUser['username']
              ?.toString() ??
          'kullanici';

  @override
  void initState() {
    super.initState();
    _checkBlock();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkBlock() async {
    final me =
        _supabase.auth.currentUser;

    if (me == null) return;

    try {
      final rows = await _supabase
          .from('user_blocks')
          .select(
            'blocker_id,blocked_id',
          );

      final blocked = rows.any(
        (row) {
          final blocker =
              row['blocker_id']
                  ?.toString();

          final target =
              row['blocked_id']
                  ?.toString();

          return (blocker ==
                      me.id &&
                  target ==
                      _otherId) ||
              (blocker ==
                      _otherId &&
                  target == me.id);
        },
      );

      if (!mounted) return;

      setState(() {
        _blocked = blocked;
      });
    } catch (_) {}
  }

  Future<void> _send() async {
    final me =
        _supabase.auth.currentUser;

    final text =
        _controller.text.trim();

    if (me == null ||
        text.isEmpty ||
        _sending ||
        _blocked) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _supabase
          .from('private_messages')
          .insert({
        'sender_id': me.id,
        'receiver_id': _otherId,
        'body': text,
      });

      _controller.clear();
    } catch (_) {
      _message(
        'Özel mesaj gönderilemedi.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _deleteMessage(
    String id,
  ) async {
    try {
      await _supabase
          .from('private_messages')
          .delete()
          .eq('id', id);
    } catch (_) {
      _message(
        'Mesaj silinemedi.',
      );
    }
  }

  Future<void> _block() async {
    final me =
        _supabase.auth.currentUser;

    if (me == null) return;

    try {
      await _supabase
          .from('user_blocks')
          .insert({
        'blocker_id': me.id,
        'blocked_id': _otherId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        _message(
          'Kullanıcı engellenemedi.',
        );
        return;
      }
    }

    if (!mounted) return;

    setState(() {
      _blocked = true;
    });

    _message(
      '@$_username engellendi.',
    );
  }

  Future<void> _report(
    Map<String, dynamic> message,
  ) async {
    final me =
        _supabase.auth.currentUser;

    if (me == null) return;

    try {
      await _supabase
          .from('message_reports')
          .insert({
        'reporter_id': me.id,
        'reported_user_id':
            _otherId,
        'message_type': 'private',
        'message_id':
            message['id'].toString(),
        'message_snapshot':
            message['body']
                    ?.toString() ??
                '',
        'reason':
            'Uygunsuz içerik',
      });

      _message(
        'Şikâyet yöneticiye gönderildi.',
      );
    } catch (_) {
      _message(
        'Şikâyet gönderilemedi.',
      );
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
            SnackBarBehavior.floating,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me =
        _supabase.auth.currentUser;

    if (me == null) {
      return const Scaffold(
        backgroundColor:
            _background,
        body: Center(
          child: Text(
            'Oturum bulunamadı.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              '@$_username',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            Text(
              _blocked
                  ? 'Engellendi'
                  : 'Özel sohbet',
              style: TextStyle(
                color: _blocked
                    ? Colors.redAccent
                    : _gold,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value ==
                  'block') {
                _block();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .block_outlined,
                      color:
                          Colors.redAccent,
                    ),
                    SizedBox(width: 9),
                    Text(
                      'Kullanıcıyı Engelle',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_blocked)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                12,
              ),
              color: Colors.red
                  .withOpacity(0.10),
              child: const Text(
                'Bu kullanıcıyla mesajlaşma kapalı.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ),

          Expanded(
            child: StreamBuilder<
                List<Map<String, dynamic>>>(
              stream: _supabase
                  .from(
                    'private_messages',
                  )
                  .stream(
                    primaryKey: ['id'],
                  )
                  .order('created_at'),
              builder: (
                context,
                snapshot,
              ) {
                final all =
                    snapshot.data ?? [];

                final messages =
                    all.where(
                  (message) {
                    final sender =
                        message['sender_id']
                            ?.toString();

                    final receiver =
                        message['receiver_id']
                            ?.toString();

                    return (sender ==
                                me.id &&
                            receiver ==
                                _otherId) ||
                        (sender ==
                                _otherId &&
                            receiver ==
                                me.id);
                  },
                ).toList();

                if (messages.isEmpty) {
                  return _EmptyChat(
                    title:
                        'Sohbeti başlat',
                    subtitle:
                        '@$_username kullanıcısına ilk mesajı gönder.',
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  itemCount:
                      messages.length,
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final message =
                        messages[index];

                    final mine =
                        message['sender_id']
                                ?.toString() ==
                            me.id;

                    final body =
                        message['body']
                                ?.toString() ??
                            '';

                    return _MessageBubble(
                      mine: mine,
                      username: mine
                          ? 'Sen'
                          : _username,
                      body: body,
                      onLongPress:
                          () {
                        _showPrivateOptions(
                          message,
                          mine,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          if (!_blocked)
            _MessageComposer(
              controller:
                  _controller,
              sending: _sending,
              onSend: _send,
            ),
        ],
      ),
    );
  }

  void _showPrivateOptions(
    Map<String, dynamic> message,
    bool mine,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              if (mine)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color:
                        Colors.redAccent,
                  ),
                  title: const Text(
                    'Mesajı Sil',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _deleteMessage(
                      message['id']
                          .toString(),
                    );
                  },
                )
              else
                ListTile(
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: _gold,
                  ),
                  title: const Text(
                    'Şikâyet Et',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _report(message);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// =======================================================
// ORTAK ARAYÜZLER
// =======================================================

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.mine,
    required this.username,
    required this.body,
    required this.onLongPress,
  });

  final bool mine;
  final String username;
  final String body;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context)
                        .size
                        .width *
                    0.78,
          ),
          margin:
              const EdgeInsets.symmetric(
            vertical: 5,
          ),
          padding:
              const EdgeInsets.fromLTRB(
            14,
            10,
            14,
            11,
          ),
          decoration: BoxDecoration(
            color: mine
                ? _burgundy
                    .withOpacity(0.62)
                : _surface,
            borderRadius:
                BorderRadius.only(
              topLeft:
                  const Radius.circular(
                18,
              ),
              topRight:
                  const Radius.circular(
                18,
              ),
              bottomLeft:
                  Radius.circular(
                mine ? 18 : 4,
              ),
              bottomRight:
                  Radius.circular(
                mine ? 4 : 18,
              ),
            ),
            border: Border.all(
              color: mine
                  ? _gold.withOpacity(
                      0.20,
                    )
                  : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                username.startsWith('@') ||
                        username == 'Sen'
                    ? username
                    : '@$username',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageComposer
    extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          9,
          12,
          10,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          border: Border(
            top: BorderSide(
              color: Colors.white10,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization:
                    TextCapitalization
                        .sentences,
                decoration:
                    InputDecoration(
                  hintText:
                      'Mesaj yaz...',
                  hintStyle:
                      const TextStyle(
                    color:
                        Colors.white38,
                  ),
                  filled: true,
                  fillColor: _surface,
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      22,
                    ),
                    borderSide:
                        const BorderSide(
                      color:
                          Colors.white10,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 17,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            Material(
              color: _gold,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder:
                    const CircleBorder(),
                onTap:
                    sending ? null : onSend,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: sending
                      ? const Padding(
                          padding:
                              EdgeInsets.all(
                            14,
                          ),
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color:
                                Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons
                              .send_rounded,
                          color:
                              Colors.black,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat
    extends StatelessWidget {
  const _EmptyChat({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration:
                  BoxDecoration(
                shape: BoxShape.circle,
                color: _burgundy
                    .withOpacity(0.24),
              ),
              child: const Icon(
                Icons
                    .chat_bubble_outline_rounded,
                color: _gold,
                size: 34,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Text(
              title,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            Text(
              subtitle,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
