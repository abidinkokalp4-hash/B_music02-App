import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        title: const Text('Sohbet'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _ChatCard(
            icon: Icons.public,
            title: 'Global Sohbet',
            subtitle: 'B_music02 topluluğundaki herkesle sohbet et.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalChatScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _ChatCard(
            icon: Icons.forum_outlined,
            title: 'Özel Sohbet',
            subtitle: '@kullaniciadi ile kullanıcı bul ve özel mesaj gönder.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivateChatsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor:
                    const Color(0xFFD4AF37).withOpacity(0.14),
                child: Icon(
                  icon,
                  color: const Color(0xFFD4AF37),
                  size: 29,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

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
        _blockedUsers.addAll(ids);
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _getProfile(
    String userId,
  ) async {
    if (_profileCache.containsKey(userId)) {
      return _profileCache[userId]!;
    }

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
        _message('Kullanıcı engellenemedi.');
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

    String reason = 'Uygunsuz içerik';

    final selected =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title:
                  const Text('Mesajı Şikâyet Et'),
              content:
                  DropdownButtonFormField<String>(
                value: reason,
                items: const [
                  DropdownMenuItem(
                    value: 'Uygunsuz içerik',
                    child:
                        Text('Uygunsuz içerik'),
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

    if (selected == null) return;

    try {
      await _supabase
          .from('message_reports')
          .insert({
        'reporter_id': me.id,
        'reported_user_id': senderId,
        'message_type': 'global',
        'message_id': messageId,
        'message_snapshot': text,
        'reason': selected,
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
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId =
        _supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor:
          const Color(0xFF0B0B0B),
      appBar: AppBar(
        title:
            const Text('Global Sohbet'),
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
                            message[
                                    'sender_id']
                                ?.toString(),
                          ),
                        )
                        .toList();

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz mesaj yok.\nİlk mesajı siz gönderin.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.white54,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.all(
                    12,
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
                            .toString();

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

                        return Align(
                          alignment: mine
                              ? Alignment
                                  .centerRight
                              : Alignment
                                  .centerLeft,
                          child:
                              GestureDetector(
                            onLongPress: () {
                              showModalBottomSheet(
                                context:
                                    context,
                                builder:
                                    (sheetContext) {
                                  return SafeArea(
                                    child: Column(
                                      mainAxisSize:
                                          MainAxisSize
                                              .min,
                                      children: [
                                        if (mine)
                                          ListTile(
                                            leading:
                                                const Icon(
                                              Icons
                                                  .delete_outline,
                                            ),
                                            title:
                                                const Text(
                                              'Mesajı Sil',
                                            ),
                                            onTap:
                                                () {
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
                                            leading:
                                                const Icon(
                                              Icons
                                                  .flag_outlined,
                                            ),
                                            title:
                                                const Text(
                                              'Şikâyet Et',
                                            ),
                                            onTap:
                                                () {
                                              Navigator.pop(
                                                sheetContext,
                                              );

                                              _reportMessage(
                                                messageId:
                                                    message['id']
                                                        .toString(),
                                                senderId:
                                                    senderId,
                                                text:
                                                    body,
                                              );
                                            },
                                          ),
                                          ListTile(
                                            leading:
                                                const Icon(
                                              Icons
                                                  .block_outlined,
                                            ),
                                            title:
                                                Text(
                                              '@$username engelle',
                                            ),
                                            onTap:
                                                () {
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
                            },
                            child:
                                Container(
                              constraints:
                                  BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(
                                          context,
                                        ).size.width *
                                        0.78,
                              ),
                              margin:
                                  const EdgeInsets
                                      .symmetric(
                                vertical: 5,
                              ),
                              padding:
                                  const EdgeInsets
                                      .all(12),
                              decoration:
                                  BoxDecoration(
                                color: mine
                                    ? const Color(
                                            0xFFD4AF37)
                                        .withOpacity(
                                            0.17)
                                    : Colors
                                        .white
                                        .withOpacity(
                                            0.07),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                            16),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    '@$username',
                                    style:
                                        const TextStyle(
                                      color: Color(
                                          0xFFD4AF37),
                                      fontSize:
                                          12,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(body),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _controller,
                      maxLength: 1000,
                      minLines: 1,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(
                        counterText: '',
                        hintText:
                            'Mesaj yaz...',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  IconButton.filled(
                    onPressed:
                        _sending
                            ? null
                            : _sendMessage,
                    icon: const Icon(
                      Icons.send,
                    ),
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

  List<Map<String, dynamic>> _results =
      [];

  bool _loading = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(
    String value,
  ) async {
    final text = value
        .trim()
        .replaceFirst('@', '')
        .toLowerCase();

    final myId =
        _supabase.auth.currentUser?.id;

    if (text.length < 2 ||
        myId == null) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final rows = await _supabase
          .from('profiles')
          .select(
            'id,username,display_name,avatar_url',
          )
          .ilike(
            'username',
            '%$text%',
          )
          .neq(
            'id',
            myId,
          )
          .limit(20);

      if (!mounted) return;

      setState(() {
        _results = rows
            .map<Map<String, dynamic>>(
              (row) => Map<String,
                  dynamic>.from(row),
            )
            .toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF0B0B0B),
      appBar: AppBar(
        title:
            const Text('Özel Sohbet'),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(14),
            child: TextField(
              controller: _search,
              onChanged: _searchUsers,
              decoration:
                  const InputDecoration(
                prefixIcon:
                    Icon(Icons.search),
                hintText:
                    '@kullaniciadi ara',
                border:
                    OutlineInputBorder(),
              ),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'Mesajlaşmak istediğiniz kişiyi\nkullanıcı adıyla arayın.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.white54,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount:
                        _results.length,
                    separatorBuilder:
                        (_, __) =>
                            const Divider(
                      height: 1,
                    ),
                    itemBuilder:
                        (context, index) {
                      final profile =
                          _results[index];

                      final username =
                          profile['username']
                                  ?.toString() ??
                              'kullanici';

                      final displayName =
                          profile['display_name']
                              ?.toString();

                      final avatar =
                          profile['avatar_url']
                              ?.toString();

                      return ListTile(
                        leading:
                            CircleAvatar(
                          backgroundImage: avatar !=
                                      null &&
                                  avatar.isNotEmpty
                              ? NetworkImage(
                                  avatar,
                                )
                              : null,
                          child: avatar ==
                                      null ||
                                  avatar.isEmpty
                              ? const Icon(
                                  Icons
                                      .person_outline,
                                )
                              : null,
                        ),
                        title: Text(
                          displayName !=
                                      null &&
                                  displayName
                                      .isNotEmpty
                              ? displayName
                              : '@$username',
                        ),
                        subtitle: Text(
                          '@$username',
                        ),
                        trailing:
                            const Icon(
                          Icons
                              .chevron_right,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DirectChatScreen(
                                profile:
                                    profile,
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

class DirectChatScreen
    extends StatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.profile,
  });

  final Map<String, dynamic> profile;

  @override
  State<DirectChatScreen> createState() =>
      _DirectChatScreenState();
}

class _DirectChatScreenState
    extends State<DirectChatScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final TextEditingController _controller =
      TextEditingController();

  bool _sending = false;
  bool _blocked = false;

  String get _otherId =>
      widget.profile['id'].toString();

  @override
  void initState() {
    super.initState();
    _checkBlocked();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkBlocked() async {
    final me = _supabase.auth.currentUser;

    if (me == null) return;

    try {
      final rows = await _supabase
          .from('user_blocks')
          .select(
            'blocker_id,blocked_id',
          );

      final blocked =
          rows.any((row) {
        final blocker =
            row['blocker_id']?.toString();

        final blockedUser =
            row['blocked_id']?.toString();

        return (blocker == me.id &&
                blockedUser == _otherId) ||
            (blocker == _otherId &&
                blockedUser == me.id);
      });

      if (mounted) {
        setState(() {
          _blocked = blocked;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final me = _supabase.auth.currentUser;

    final text = _controller.text.trim();

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
          .from('direct_messages')
          .insert({
        'sender_id': me.id,
        'recipient_id': _otherId,
        'body': text,
      });

      _controller.clear();
    } catch (_) {
      _message(
        'Mesaj gönderilemedi.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _block() async {
    final me = _supabase.auth.currentUser;

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

    _message('Kullanıcı engellendi.');
  }

  Future<void> _deleteMessage(
    String id,
  ) async {
    try {
      await _supabase
          .from('direct_messages')
          .delete()
          .eq('id', id);
    } catch (_) {
      _message('Mesaj silinemedi.');
    }
  }

  Future<void> _report(
    Map<String, dynamic> message,
  ) async {
    final me = _supabase.auth.currentUser;

    if (me == null) return;

    try {
      await _supabase
          .from('message_reports')
          .insert({
        'reporter_id': me.id,
        'reported_user_id': _otherId,
        'message_type': 'direct',
        'message_id': message['id'],
        'message_snapshot':
            message['body'],
        'reason':
            'Uygunsuz özel mesaj',
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
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me =
        _supabase.auth.currentUser;

    final username =
        widget.profile['username']
                ?.toString() ??
            'kullanici';

    return Scaffold(
      backgroundColor:
          const Color(0xFF0B0B0B),
      appBar: AppBar(
        title: Text('@$username'),
        actions: [
          IconButton(
            tooltip:
                'Kullanıcıyı Engelle',
            onPressed:
                _blocked ? null : _block,
            icon: const Icon(
              Icons.block_outlined,
            ),
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
                10,
              ),
              color: Colors.red
                  .withOpacity(0.18),
              child: const Text(
                'Bu kullanıcıyla mesajlaşma engellendi.',
                textAlign:
                    TextAlign.center,
              ),
            ),
          Expanded(
            child: StreamBuilder<
                List<Map<String, dynamic>>>(
              stream: _supabase
                  .from(
                      'direct_messages')
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
                        .where((message) {
                  final sender =
                      message['sender_id']
                          ?.toString();

                  final recipient =
                      message[
                              'recipient_id']
                          ?.toString();

                  return (sender ==
                              me?.id &&
                          recipient ==
                              _otherId) ||
                      (sender ==
                              _otherId &&
                          recipient ==
                              me?.id);
                }).toList();

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz mesaj yok.',
                      style: TextStyle(
                        color:
                            Colors.white54,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  itemCount:
                      messages.length,
                  itemBuilder: (
                    context,
                    index,
                  ) {
                    final message =
                        messages[index];

                    final mine =
                        message['sender_id']
                                ?.toString() ==
                            me?.id;

                    return Align(
                      alignment: mine
                          ? Alignment
                              .centerRight
                          : Alignment
                              .centerLeft,
                      child:
                          GestureDetector(
                        onLongPress: () {
                          showModalBottomSheet(
                            context:
                                context,
                            builder:
                                (sheetContext) {
                              return SafeArea(
                                child: Column(
                                  mainAxisSize:
                                      MainAxisSize
                                          .min,
                                  children: [
                                    if (mine)
                                      ListTile(
                                        leading:
                                            const Icon(
                                          Icons
                                              .delete_outline,
                                        ),
                                        title:
                                            const Text(
                                          'Mesajı Sil',
                                        ),
                                        onTap:
                                            () {
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
                                        leading:
                                            const Icon(
                                          Icons
                                              .flag_outlined,
                                        ),
                                        title:
                                            const Text(
                                          'Şikâyet Et',
                                        ),
                                        onTap:
                                            () {
                                          Navigator.pop(
                                            sheetContext,
                                          );

                                          _report(
                                            message,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          constraints:
                              BoxConstraints(
                            maxWidth:
                                MediaQuery.of(
                                      context,
                                    ).size.width *
                                    0.78,
                          ),
                          margin:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 5,
                          ),
                          padding:
                              const EdgeInsets
                                  .all(12),
                          decoration:
                              BoxDecoration(
                            color: mine
                                ? const Color(
                                        0xFFD4AF37)
                                    .withOpacity(
                                        0.17)
                                : Colors
                                    .white
                                    .withOpacity(
                                        0.07),
                            borderRadius:
                                BorderRadius
                                    .circular(16),
                          ),
                          child: Text(
                            message['body']
                                    ?.toString() ??
                                '',
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _controller,
                      enabled:
                          !_blocked,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(
                        counterText: '',
                        hintText:
                            'Mesaj yaz...',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  IconButton.filled(
                    onPressed:
                        _sending ||
                                _blocked
                            ? null
                            : _sendMessage,
                    icon: const Icon(
                      Icons.send,
                    ),
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
