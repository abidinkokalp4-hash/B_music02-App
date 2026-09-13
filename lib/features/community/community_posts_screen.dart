import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';

class CommunityPostsScreen extends StatefulWidget {
  const CommunityPostsScreen({super.key});

  @override
  State<CommunityPostsScreen> createState() => _CommunityPostsScreenState();
}

class _CommunityPostsScreenState extends State<CommunityPostsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SocialService _social = SocialService.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, SocialProfile> _profiles = <String, SocialProfile>{};
  final Map<String, String> _signedUrls = <String, String>{};
  bool _creating = false;

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
        _profiles = {for (final item in profiles) item.id: item};
      });
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> get _postStream {
    return _supabase
        .from('community_posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100);
  }

  Future<String?> _signedUrl(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    final cached = _signedUrls[path];
    if (cached != null) return cached;
    try {
      final url = await _supabase.storage
          .from('community-posts')
          .createSignedUrl(path, 60 * 60);
      _signedUrls[path] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> _createPost() async {
    if (_creating) return;
    final controller = TextEditingController();
    XFile? selectedImage;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Topluluğa gönder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 3,
                      maxLines: 7,
                      maxLength: 1200,
                      decoration: const InputDecoration(
                        hintText: 'Müzik, sanatçı veya günün hakkında bir şey paylaş...',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (selectedImage != null)
                      Row(
                        children: [
                          const Icon(Icons.image_rounded, color: AppColors.gold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedImage!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setDialogState(() => selectedImage = null);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final image = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 88,
                            maxWidth: 1800,
                          );
                          if (image != null) {
                            setDialogState(() => selectedImage = image);
                          }
                        },
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Fotoğraf ekle'),
                      ),
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
                  child: const Text('Paylaş'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldCreate != true) {
      controller.dispose();
      return;
    }

    final body = controller.text.trim();
    controller.dispose();
    if (body.isEmpty) {
      _message('Gönderi metni boş olamaz.');
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _creating = true);

    String? storagePath;
    try {
      if (selectedImage != null) {
        final Uint8List bytes = await selectedImage!.readAsBytes();
        final extension = _extension(selectedImage!.name);
        storagePath = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
        await _supabase.storage.from('community-posts').uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                cacheControl: '3600',
                contentType: _imageContentType(extension),
              ),
            );
      }

      await _supabase.from('community_posts').insert({
        'user_id': user.id,
        'body': body,
        'media_url': storagePath,
        'post_type': storagePath == null ? 'text' : 'image',
      });
    } catch (error) {
      if (storagePath != null) {
        try {
          await _supabase.storage.from('community-posts').remove([storagePath]);
        } catch (_) {}
      }
      _message('Gönderi yayınlanamadı: $error');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'jpg';
    final value = name.substring(dot + 1).toLowerCase();
    if (value == 'png' || value == 'webp' || value == 'jpeg' || value == 'jpg') {
      return value;
    }
    return 'jpg';
  }

  String _imageContentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<void> _react(String postId, String emoji) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('community_post_reactions').upsert(
      {
        'post_id': postId,
        'user_id': user.id,
        'emoji': emoji,
      },
      onConflict: 'post_id,user_id',
    );
    if (mounted) setState(() {});
  }

  Future<Map<String, int>> _reactionCounts(String postId) async {
    final rows = await _supabase
        .from('community_post_reactions')
        .select('emoji')
        .eq('post_id', postId);
    final result = <String, int>{};
    for (final row in rows) {
      final emoji = row['emoji']?.toString() ?? '';
      if (emoji.isNotEmpty) result[emoji] = (result[emoji] ?? 0) + 1;
    }
    return result;
  }

  Future<void> _openComments(Map<String, dynamic> post) async {
    final postId = post['id'].toString();
    final input = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.comment_rounded, color: AppColors.gold),
                  title: Text('Yorumlar'),
                ),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('community_post_comments')
                        .stream(primaryKey: ['id'])
                        .eq('post_id', postId)
                        .order('created_at'),
                    builder: (context, snapshot) {
                      final rows = snapshot.data ?? const [];
                      if (rows.isEmpty) {
                        return const Center(
                          child: Text('İlk yorumu sen yap.'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final userId = row['user_id']?.toString() ?? '';
                          final mine = userId == _supabase.auth.currentUser?.id;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                              child: Text(
                                _initial(userId),
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            title: Text(
                              _profiles[userId]?.name ?? 'Kullanıcı',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(row['body']?.toString() ?? ''),
                            trailing: mine
                                ? IconButton(
                                    onPressed: () async {
                                      await _supabase
                                          .from('community_post_comments')
                                          .delete()
                                          .eq('id', row['id']);
                                    },
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          maxLines: 4,
                          minLines: 1,
                          decoration: const InputDecoration(hintText: 'Yorum yaz...'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () async {
                          final text = input.text.trim();
                          final user = _supabase.auth.currentUser;
                          if (text.isEmpty || user == null) return;
                          await _supabase.from('community_post_comments').insert({
                            'post_id': postId,
                            'user_id': user.id,
                            'body': text,
                          });
                          input.clear();
                        },
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    input.dispose();
  }

  Future<void> _openPostMenu(Map<String, dynamic> post) async {
    final ownerId = post['user_id']?.toString() ?? '';
    final mine = ownerId == _supabase.auth.currentUser?.id;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              if (mine)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Gönderiyi sil'),
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
        );
      },
    );

    if (choice == 'delete') {
      final mediaPath = post['media_url']?.toString();
      await _supabase.from('community_posts').delete().eq('id', post['id']);
      if (mediaPath?.isNotEmpty == true) {
        try {
          await _supabase.storage.from('community-posts').remove([mediaPath!]);
        } catch (_) {}
      }
    } else if (choice == 'report') {
      final user = _supabase.auth.currentUser;
      if (user == null || user.id == ownerId) return;
      try {
        await _supabase.from('community_post_reports').insert({
          'post_id': post['id'],
          'reporter_id': user.id,
          'reported_user_id': ownerId,
          'reason': 'Uygunsuz içerik',
        });
        _message('Gönderi şikâyeti alındı.');
      } catch (_) {
        _message('Bu gönderiyi daha önce şikâyet etmiş olabilirsin.');
      }
    } else if (choice == 'block') {
      await _social.blockUser(ownerId);
      _message('Kullanıcı engellendi.');
    }
  }

  String _initial(String userId) {
    final name = _profiles[userId]?.name.trim();
    if (name == null || name.isEmpty) return '?';
    return name.characters.first.toUpperCase();
  }

  String _time(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'şimdi';
    if (difference.inHours < 1) return '${difference.inMinutes} dk';
    if (difference.inDays < 1) return '${difference.inHours} sa';
    return '${date.day}.${date.month}.${date.year}';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createPost,
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        icon: _creating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Icon(Icons.add_rounded),
        label: const Text('Paylaş'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }
          final posts = snapshot.data ?? const [];
          if (posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dynamic_feed_rounded, color: AppColors.gold, size: 52),
                    SizedBox(height: 12),
                    Text(
                      'Topluluk akışı henüz boş',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'İlk yazılı veya fotoğraflı gönderiyi sen paylaş.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final userId = post['user_id']?.toString() ?? '';
              final profile = _profiles[userId];
              final mediaPath = post['media_url']?.toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: post['is_featured'] == true
                        ? AppColors.gold.withValues(alpha: 0.4)
                        : Theme.of(context).dividerColor,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                          backgroundImage: profile?.avatarUrl?.trim().isNotEmpty == true
                              ? NetworkImage(profile!.avatarUrl!)
                              : null,
                          child: profile?.avatarUrl?.trim().isNotEmpty == true
                              ? null
                              : Text(
                                  _initial(userId),
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      profile?.name ?? 'Kullanıcı',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  if (post['is_featured'] == true) ...[
                                    const SizedBox(width: 5),
                                    const Icon(Icons.star_rounded, size: 15, color: AppColors.gold),
                                  ],
                                ],
                              ),
                              Text(
                                '@${profile?.username ?? 'kullanici'} • ${_time(post['created_at'])}',
                                style: const TextStyle(color: Colors.white38, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openPostMenu(post),
                          icon: const Icon(Icons.more_horiz_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      post['body']?.toString() ?? '',
                      style: const TextStyle(fontSize: 13, height: 1.45),
                    ),
                    if (mediaPath?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      FutureBuilder<String?>(
                        future: _signedUrl(mediaPath),
                        builder: (context, urlSnapshot) {
                          final url = urlSnapshot.data;
                          if (url == null) {
                            return Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(color: AppColors.gold),
                              ),
                            );
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              url,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'Tepki ver',
                          onSelected: (emoji) => _react(post['id'].toString(), emoji),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: '❤️', child: Text('❤️ Beğendim')),
                            PopupMenuItem(value: '🔥', child: Text('🔥 Ateş')),
                            PopupMenuItem(value: '😂', child: Text('😂 Komik')),
                            PopupMenuItem(value: '🎵', child: Text('🎵 Müzik')),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite_border_rounded, size: 18),
                                SizedBox(width: 5),
                                Text('Tepki', style: TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _openComments(post),
                          icon: const Icon(Icons.mode_comment_outlined, size: 18),
                          label: const Text('Yorum'),
                        ),
                        const Spacer(),
                        FutureBuilder<Map<String, int>>(
                          future: _reactionCounts(post['id'].toString()),
                          builder: (context, reactionSnapshot) {
                            final counts = reactionSnapshot.data ?? const <String, int>{};
                            if (counts.isEmpty) return const SizedBox.shrink();
                            return Text(
                              counts.entries.map((entry) => '${entry.key}${entry.value}').join(' '),
                              style: const TextStyle(fontSize: 10, color: Colors.white54),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
