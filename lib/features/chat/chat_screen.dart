import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/contact_service.dart';
import '../../core/theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
  });

  @override
  State<ChatScreen> createState() =>
      _ChatScreenState();
}

class _ChatScreenState
    extends State<ChatScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final ContactService _contactService =
      const ContactService();

  final TextEditingController
      _messageController =
      TextEditingController();

  final FocusNode _messageFocus =
      FocusNode();

  final Map<String, _ProfileInfo>
      _profiles = {};

  int _selectedTab = 0;

  bool _loadingProfiles = true;
  bool _sending = false;

  User? get _user =>
      _supabase.auth.currentUser;

  bool get _isDark =>
      Theme.of(context).brightness ==
      Brightness.dark;

  Color get _background =>
      Theme.of(context)
          .scaffoldBackgroundColor;

  Color get _surface =>
      Theme.of(context)
          .colorScheme
          .surface;

  Color get _text =>
      Theme.of(context)
          .colorScheme
          .onSurface;

  Color get _muted =>
      _text.withOpacity(
        0.48,
      );

  @override
  void initState() {
    super.initState();

    _loadProfiles();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocus.dispose();

    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final rows =
          await _supabase
              .from(
                'profiles',
              )
              .select(
                'id, username, display_name, avatar_url',
              );

      final map =
          <String, _ProfileInfo>{};

      for (final raw in rows) {
        final row =
            Map<String, dynamic>.from(
          raw,
        );

        final id =
            row['id']?.toString();

        if (id == null ||
            id.isEmpty) {
          continue;
        }

        map[id] =
            _ProfileInfo(
          id: id,
          username:
              row['username']
                  ?.toString(),
          displayName:
              row['display_name']
                  ?.toString(),
          avatarUrl:
              row['avatar_url']
                  ?.toString(),
        );
      }

      if (!mounted) return;

      setState(() {
        _profiles
          ..clear()
          ..addAll(
            map,
          );

        _loadingProfiles = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingProfiles = false;
      });
    }
  }

  String _nameFor(
    String? userId,
  ) {
    if (userId == null) {
      return 'Kullanıcı';
    }

    final profile =
        _profiles[userId];

    if (profile == null) {
      return 'Kullanıcı';
    }

    return profile.name;
  }

  String? _avatarFor(
    String? userId,
  ) {
    if (userId == null) {
      return null;
    }

    return _profiles[userId]
        ?.avatarUrl;
  }

  Future<void>
      _sendGlobalMessage() async {
    final user = _user;

    final body =
        _messageController.text
            .trim();

    if (user == null ||
        body.isEmpty ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _supabase
          .from(
            'global_messages',
          )
          .insert(
        {
          'sender_id':
              user.id,
          'body':
              body,
        },
      );

      _messageController.clear();

      _messageFocus.requestFocus();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Mesaj gönderilemedi.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void>
      _openAdvertisingEmail() async {
    final opened =
        await _contactService
            .openAdvertisingEmail();

    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'E-posta uygulaması açılamadı.',
        ),
      ),
    );
  }

  void _openDirectChat(
    _ProfileInfo profile,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _DirectChatPage(
          profile:
              profile,
          profiles:
              _profiles,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            const SizedBox(
              height: 12,
            ),

            _buildTabs(),

            const SizedBox(
              height: 10,
            ),

            Expanded(
              child:
                  _selectedTab == 0
                      ? _buildGlobalChat()
                      : _buildDirectUsers(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        16,
        18,
        0,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  AppColors.gold,
                  AppColors.burgundy,
                ],
              ),
            ),
            child:
                const Icon(
              Icons
                  .forum_rounded,
              color:
                  Colors.white,
              size: 25,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Sohbet',
                  style:
                      TextStyle(
                    color:
                        _text,
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing:
                        -0.7,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  'B_music02 topluluğu',
                  style:
                      TextStyle(
                    color:
                        _muted,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed:
                _loadProfiles,
            icon:
                const Icon(
              Icons
                  .refresh_rounded,
              color:
                  AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 18,
      ),
      child: Container(
        height: 52,
        padding:
            const EdgeInsets.all(
          5,
        ),
        decoration:
            BoxDecoration(
          color:
              _surface,
          borderRadius:
              BorderRadius.circular(
            24,
          ),
          border:
              Border.all(
            color:
                AppColors.gold
                    .withOpacity(
              0.13,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabButton(
                selected:
                    _selectedTab ==
                        0,
                icon:
                    Icons
                        .groups_rounded,
                title:
                    'Genel',
                onTap: () {
                  setState(() {
                    _selectedTab =
                        0;
                  });
                },
              ),
            ),

            const SizedBox(
              width: 5,
            ),

            Expanded(
              child: _TabButton(
                selected:
                    _selectedTab ==
                        1,
                icon:
                    Icons
                        .mark_chat_unread_rounded,
                title:
                    'Özel Mesajlar',
                onTap: () {
                  setState(() {
                    _selectedTab =
                        1;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalChat() {
    if (_user == null) {
      return const Center(
        child: Text(
          'Sohbet için giriş yapmalısınız.',
        ),
      );
    }

    final stream =
        _supabase
            .from(
              'global_messages',
            )
            .stream(
              primaryKey: [
                'id',
              ],
            )
            .order(
              'created_at',
              ascending: false,
            );

    return Column(
      children: [
        Expanded(
          child:
              StreamBuilder<
                  List<
                      Map<
                          String,
                          dynamic>>>(
            stream:
                stream,
            builder:
                (
              context,
              snapshot,
            ) {
              if (snapshot
                      .connectionState ==
                  ConnectionState
                      .waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        AppColors.gold,
                  ),
                );
              }

              final messages =
                  snapshot.data ??
                      [];

              if (messages
                  .isEmpty) {
                return _EmptyChat(
                  icon:
                      Icons
                          .chat_bubble_outline_rounded,
                  title:
                      'İlk mesajı sen gönder',
                  subtitle:
                      'Topluluk sohbeti burada başlayacak.',
                );
              }

              return ListView.builder(
                reverse: true,
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  14,
                  8,
                  14,
                  10,
                ),
                itemCount:
                    messages
                        .length,
                itemBuilder:
                    (
                  context,
                  index,
                ) {
                  final message =
                      messages[
                          index];

                  final senderId =
                      message[
                              'sender_id']
                          ?.toString();

                  final mine =
                      senderId ==
                          _user!
                              .id;

                  return _MessageBubble(
                    mine:
                        mine,
                    name:
                        mine
                            ? 'Sen'
                            : _nameFor(
                                senderId,
                              ),
                    avatarUrl:
                        _avatarFor(
                      senderId,
                    ),
                    body:
                        message[
                                'body']
                            ?.toString() ??
                            '',
                    createdAt:
                        message[
                                'created_at']
                            ?.toString(),
                  );
                },
              );
            },
          ),
        ),

        Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            14,
            0,
            14,
            9,
          ),
          child: _AdBanner(
            onTap:
                _openAdvertisingEmail,
          ),
        ),

        _ChatComposer(
          controller:
              _messageController,
          focusNode:
              _messageFocus,
          sending:
              _sending,
          onSend:
              _sendGlobalMessage,
        ),
      ],
    );
  }

  Widget _buildDirectUsers() {
    if (_loadingProfiles) {
      return const Center(
        child:
            CircularProgressIndicator(
          color:
              AppColors.gold,
        ),
      );
    }

    final myId =
        _user?.id;

    final users =
        _profiles.values
            .where(
              (
                profile,
              ) =>
                  profile.id !=
                  myId,
            )
            .toList()
          ..sort(
            (
              a,
              b,
            ) =>
                a.name
                    .toLowerCase()
                    .compareTo(
                      b.name
                          .toLowerCase(),
                    ),
          );

    if (users.isEmpty) {
      return _EmptyChat(
        icon:
            Icons
                .person_search_rounded,
        title:
            'Kullanıcı bulunamadı',
        subtitle:
            'Yeni üyeler geldikçe burada görünecek.',
      );
    }

    return Column(
      children: [
        Expanded(
          child:
              ListView.separated(
            padding:
                const EdgeInsets
                    .fromLTRB(
              14,
              8,
              14,
              12,
            ),
            itemCount:
                users.length,
            separatorBuilder:
                (
              context,
              index,
            ) =>
                    const SizedBox(
              height: 8,
            ),
            itemBuilder:
                (
              context,
              index,
            ) {
              final profile =
                  users[index];

              return _DirectUserTile(
                profile:
                    profile,
                onTap: () {
                  _openDirectChat(
                    profile,
                  );
                },
              );
            },
          ),
        ),

        Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            14,
            0,
            14,
            14,
          ),
          child: _AdBanner(
            onTap:
                _openAdvertisingEmail,
          ),
        ),
      ],
    );
  }
}

class _DirectChatPage
    extends StatefulWidget {
  const _DirectChatPage({
    required this.profile,
    required this.profiles,
  });

  final _ProfileInfo profile;

  final Map<String, _ProfileInfo>
      profiles;

  @override
  State<_DirectChatPage>
      createState() =>
          _DirectChatPageState();
}

class _DirectChatPageState
    extends State<
        _DirectChatPage> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final ContactService _contactService =
      const ContactService();

  final TextEditingController
      _controller =
      TextEditingController();

  final FocusNode _focusNode =
      FocusNode();

  bool _sending = false;

  User? get _user =>
      _supabase.auth.currentUser;

  Color get _surface =>
      Theme.of(context)
          .colorScheme
          .surface;

  Color get _text =>
      Theme.of(context)
          .colorScheme
          .onSurface;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  Future<void> _send() async {
    final user = _user;

    final body =
        _controller.text
            .trim();

    if (user == null ||
        body.isEmpty ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await _supabase
          .from(
            'direct_messages',
          )
          .insert(
        {
          'sender_id':
              user.id,
          'recipient_id':
              widget.profile.id,
          'body':
              body,
        },
      );

      _controller.clear();
      _focusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Mesaj gönderilemedi.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void>
      _openAdvertisingEmail() async {
    final opened =
        await _contactService
            .openAdvertisingEmail();

    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'E-posta uygulaması açılamadı.',
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final user =
        _user;

    return Scaffold(
      backgroundColor:
          Theme.of(context)
              .scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Theme.of(context)
                .scaffoldBackgroundColor,
        titleSpacing: 0,
        title: Row(
          children: [
            _Avatar(
              name:
                  widget
                      .profile
                      .name,
              avatarUrl:
                  widget
                      .profile
                      .avatarUrl,
              size: 39,
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    widget
                        .profile
                        .name,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      color:
                          _text,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  Text(
                    'Özel mesaj',
                    style:
                        TextStyle(
                      color:
                          _text
                              .withOpacity(
                        0.45,
                      ),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body:
          user == null
              ? const Center(
                  child: Text(
                    'Oturum bulunamadı.',
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child:
                          StreamBuilder<
                              List<
                                  Map<
                                      String,
                                      dynamic>>>(
                        stream:
                            _supabase
                                .from(
                                  'direct_messages',
                                )
                                .stream(
                                  primaryKey: [
                                    'id',
                                  ],
                                )
                                .order(
                                  'created_at',
                                  ascending:
                                      false,
                                ),
                        builder:
                            (
                          context,
                          snapshot,
                        ) {
                          if (snapshot
                                  .connectionState ==
                              ConnectionState
                                  .waiting) {
                            return const Center(
                              child:
                                  CircularProgressIndicator(
                                color:
                                    AppColors.gold,
                              ),
                            );
                          }

                          final allRows =
                              snapshot
                                      .data ??
                                  [];

                          final messages =
                              allRows.where(
                            (
                              message,
                            ) {
                              final sender =
                                  message[
                                          'sender_id']
                                      ?.toString();

                              final recipient =
                                  message[
                                          'recipient_id']
                                      ?.toString();

                              return (sender ==
                                          user.id &&
                                      recipient ==
                                          widget
                                              .profile
                                              .id) ||
                                  (sender ==
                                          widget
                                              .profile
                                              .id &&
                                      recipient ==
                                          user.id);
                            },
                          ).toList();

                          if (messages
                              .isEmpty) {
                            return _EmptyChat(
                              icon:
                                  Icons
                                      .favorite_border_rounded,
                              title:
                                  'Sohbete başla',
                              subtitle:
                                  '${widget.profile.name} kullanıcısına ilk mesajını gönder.',
                            );
                          }

                          return ListView.builder(
                            reverse:
                                true,
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              14,
                              10,
                              14,
                              14,
                            ),
                            itemCount:
                                messages
                                    .length,
                            itemBuilder:
                                (
                              context,
                              index,
                            ) {
                              final message =
                                  messages[
                                      index];

                              final senderId =
                                  message[
                                          'sender_id']
                                      ?.toString();

                              final mine =
                                  senderId ==
                                      user.id;

                              return _MessageBubble(
                                mine:
                                    mine,
                                name:
                                    mine
                                        ? 'Sen'
                                        : widget
                                            .profile
                                            .name,
                                avatarUrl:
                                    mine
                                        ? null
                                        : widget
                                            .profile
                                            .avatarUrl,
                                body:
                                    message[
                                            'body']
                                        ?.toString() ??
                                        '',
                                createdAt:
                                    message[
                                            'created_at']
                                        ?.toString(),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        14,
                        0,
                        14,
                        9,
                      ),
                      child:
                          _AdBanner(
                        onTap:
                            _openAdvertisingEmail,
                      ),
                    ),

                    _ChatComposer(
                      controller:
                          _controller,
                      focusNode:
                          _focusNode,
                      sending:
                          _sending,
                      onSend:
                          _send,
                    ),
                  ],
                ),
    );
  }
}

class _ChatComposer
    extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(
    BuildContext context,
  ) {
    final surface =
        Theme.of(context)
            .colorScheme
            .surface;

    final text =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets
                .fromLTRB(
          12,
          9,
          12,
          10,
        ),
        decoration:
            BoxDecoration(
          color:
              Theme.of(context)
                  .scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color:
                  Theme.of(context)
                      .dividerColor,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration:
                    BoxDecoration(
                  color:
                      surface,
                  borderRadius:
                      BorderRadius
                          .circular(
                    24,
                  ),
                  border:
                      Border.all(
                    color:
                        AppColors.gold
                            .withOpacity(
                      0.12,
                    ),
                  ),
                ),
                child: TextField(
                  controller:
                      controller,
                  focusNode:
                      focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization:
                      TextCapitalization
                          .sentences,
                  style:
                      TextStyle(
                    color:
                        text,
                    fontSize: 14,
                  ),
                  decoration:
                      const InputDecoration(
                    hintText:
                        'Mesaj yaz...',
                    border:
                        InputBorder.none,
                    contentPadding:
                        EdgeInsets
                            .symmetric(
                      horizontal: 17,
                      vertical: 13,
                    ),
                  ),
                  onSubmitted:
                      (_) {
                    if (!sending) {
                      onSend();
                    }
                  },
                ),
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            GestureDetector(
              onTap:
                  sending
                      ? null
                      : onSend,
              child: Container(
                width: 49,
                height: 49,
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  gradient:
                      LinearGradient(
                    colors: [
                      AppColors.gold,
                      AppColors.burgundy,
                    ],
                  ),
                ),
                child:
                    sending
                        ? const Padding(
                            padding:
                                EdgeInsets.all(
                              15,
                            ),
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons
                                .send_rounded,
                            color:
                                Colors.white,
                            size: 21,
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble
    extends StatelessWidget {
  const _MessageBubble({
    required this.mine,
    required this.name,
    required this.avatarUrl,
    required this.body,
    required this.createdAt,
  });

  final bool mine;
  final String name;
  final String? avatarUrl;
  final String body;
  final String? createdAt;

  String _time() {
    if (createdAt == null) {
      return '';
    }

    final date =
        DateTime.tryParse(
      createdAt!,
    );

    if (date == null) {
      return '';
    }

    final local =
        date.toLocal();

    final hour =
        local.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final minute =
        local.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$hour:$minute';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final text =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        vertical: 5,
      ),
      child: Row(
        mainAxisAlignment:
            mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            _Avatar(
              name:
                  name,
              avatarUrl:
                  avatarUrl,
              size: 31,
            ),

            const SizedBox(
              width: 7,
            ),
          ],

          Flexible(
            child: Container(
              constraints:
                  const BoxConstraints(
                maxWidth: 300,
              ),
              padding:
                  const EdgeInsets
                      .fromLTRB(
                13,
                9,
                13,
                7,
              ),
              decoration:
                  BoxDecoration(
                gradient:
                    mine
                        ? const LinearGradient(
                            begin:
                                Alignment.topLeft,
                            end:
                                Alignment.bottomRight,
                            colors: [
                              AppColors.burgundy,
                              Color(
                                0xFF4B1428,
                              ),
                            ],
                          )
                        : null,
                color:
                    mine
                        ? null
                        : Theme.of(
                            context,
                          )
                            .colorScheme
                            .surface,
                borderRadius:
                    BorderRadius.only(
                  topLeft:
                      const Radius
                          .circular(
                    18,
                  ),
                  topRight:
                      const Radius
                          .circular(
                    18,
                  ),
                  bottomLeft:
                      Radius.circular(
                    mine
                        ? 18
                        : 5,
                  ),
                  bottomRight:
                      Radius.circular(
                    mine
                        ? 5
                        : 18,
                  ),
                ),
                border:
                    mine
                        ? null
                        : Border.all(
                            color:
                                Theme.of(
                              context,
                            ).dividerColor,
                          ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        bottom: 3,
                      ),
                      child: Text(
                        name,
                        style:
                            const TextStyle(
                          color:
                              AppColors.gold,
                          fontSize:
                              10,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),

                  Text(
                    body,
                    style:
                        TextStyle(
                      color:
                          mine
                              ? Colors.white
                              : text,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Align(
                    alignment:
                        Alignment
                            .centerRight,
                    child: Text(
                      _time(),
                      style:
                          TextStyle(
                        color:
                            mine
                                ? Colors.white54
                                : text.withOpacity(
                                    0.36,
                                  ),
                        fontSize: 8,
                      ),
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

class _DirectUserTile
    extends StatelessWidget {
  const _DirectUserTile({
    required this.profile,
    required this.onTap,
  });

  final _ProfileInfo profile;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final text =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: Ink(
          padding:
              const EdgeInsets.all(
            13,
          ),
          decoration:
              BoxDecoration(
            color:
                Theme.of(context)
                    .colorScheme
                    .surface,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border:
                Border.all(
              color:
                  Theme.of(
                context,
              ).dividerColor,
            ),
          ),
          child: Row(
            children: [
              _Avatar(
                name:
                    profile.name,
                avatarUrl:
                    profile
                        .avatarUrl,
                size: 51,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          TextStyle(
                        color:
                            text,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      profile.username !=
                                  null &&
                              profile
                                  .username!
                                  .isNotEmpty
                          ? '@${profile.username}'
                          : 'Mesaj gönder',
                      style:
                          TextStyle(
                        color:
                            text.withOpacity(
                          0.42,
                        ),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 39,
                height: 39,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.gold
                          .withOpacity(
                    0.11,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons
                      .chat_rounded,
                  color:
                      AppColors.gold,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton
    extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final text =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return GestureDetector(
      onTap:
          onTap,
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 180,
        ),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            19,
          ),
          gradient:
              selected
                  ? const LinearGradient(
                      colors: [
                        AppColors.gold,
                        Color(
                          0xFFF0CF7A,
                        ),
                      ],
                    )
                  : null,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color:
                  selected
                      ? Colors.black
                      : text.withOpacity(
                          0.45,
                        ),
            ),

            const SizedBox(
              width: 6,
            ),

            Text(
              title,
              style:
                  TextStyle(
                color:
                    selected
                        ? Colors.black
                        : text.withOpacity(
                            0.60,
                          ),
                fontSize: 12,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdBanner
    extends StatelessWidget {
  const _AdBanner({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final text =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        child: Ink(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 13,
            vertical: 10,
          ),
          decoration:
              BoxDecoration(
            gradient:
                LinearGradient(
              colors: [
                AppColors.gold
                    .withOpacity(
                  0.14,
                ),
                AppColors.burgundy
                    .withOpacity(
                  0.10,
                ),
              ],
            ),
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border:
                Border.all(
              color:
                  AppColors.gold
                      .withOpacity(
                0.24,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.gold
                          .withOpacity(
                    0.14,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons
                      .campaign_rounded,
                  color:
                      AppColors.gold,
                  size: 21,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Buraya reklam verebilirsiniz',
                      style:
                          TextStyle(
                        color:
                            text,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    const Text(
                      'Reklam iletişimi için dokunun',
                      style:
                          TextStyle(
                        color:
                            AppColors.gold,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .mail_outline_rounded,
                color:
                    AppColors.gold,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChat
    extends StatelessWidget {
  const _EmptyChat({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(
    BuildContext context,
  ) {
    final text =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.gold
                        .withOpacity(
                  0.09,
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  Icon(
                icon,
                color:
                    AppColors.gold,
                size: 38,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              title,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    text,
                fontSize: 18,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              subtitle,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    text.withOpacity(
                  0.42,
                ),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar
    extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.avatarUrl,
    required this.size,
  });

  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(
    BuildContext context,
  ) {
    final validAvatar =
        avatarUrl != null &&
            avatarUrl!
                .trim()
                .isNotEmpty;

    final letter =
        name.trim().isEmpty
            ? '?'
            : name
                .trim()
                .substring(
                  0,
                  1,
                )
                .toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        gradient:
            const LinearGradient(
          colors: [
            AppColors.gold,
            AppColors.burgundy,
          ],
        ),
      ),
      padding:
          const EdgeInsets.all(
        2,
      ),
      child: ClipOval(
        child:
            validAvatar
                ? Image.network(
                    avatarUrl!,
                    fit:
                        BoxFit.cover,
                    errorBuilder:
                        (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return _letterAvatar(
                        letter,
                      );
                    },
                  )
                : _letterAvatar(
                    letter,
                  ),
      ),
    );
  }

  Widget _letterAvatar(
    String letter,
  ) {
    return Container(
      color:
          const Color(
        0xFF171214,
      ),
      alignment:
          Alignment.center,
      child: Text(
        letter,
        style:
            const TextStyle(
          color:
              AppColors.gold,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileInfo {
  const _ProfileInfo({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String get name {
    final display =
        displayName?.trim();

    if (display != null &&
        display.isNotEmpty) {
      return display;
    }

    final user =
        username?.trim();

    if (user != null &&
        user.isNotEmpty) {
      return user;
    }

    return 'Kullanıcı';
  }
}
