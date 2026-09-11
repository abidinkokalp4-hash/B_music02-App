import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _videos = [];

  bool _loading = true;
  bool _uploading = false;
  bool _isAdmin = false;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      await _checkAdmin();
      await _loadVideos();
    } catch (e) {
      _message(
        'Videolar yüklenirken hata oluştu.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _checkAdmin() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    final profile = await _supabase
        .from('profiles')
        .select('app_role')
        .eq('id', user.id)
        .single();

    final role = profile['app_role']?.toString();

    _isAdmin = role == 'admin' || role == 'moderator';
  }

  Future<void> _loadVideos() async {
    final result = await _supabase
        .from('community_videos')
        .select(
          '''
          id,
          user_id,
          storage_path,
          caption,
          approved_at,
          created_at,
          profile:profiles!community_videos_user_id_fkey(
            username,
            display_name,
            avatar_url
          )
          ''',
        )
        .eq('status', 'approved')
        .order('approved_at', ascending: false);

    final loaded = <Map<String, dynamic>>[];

    for (final raw in result) {
      final video = Map<String, dynamic>.from(raw);

      final path = video['storage_path']?.toString();

      if (path == null || path.isEmpty) continue;

      try {
        final signedUrl = await _supabase.storage
            .from('community-videos')
            .createSignedUrl(
              path,
              60 * 60,
            );

        video['signed_url'] = signedUrl;
        loaded.add(video);
      } catch (_) {
        // Bir video açılamazsa diğer videolar yüklenmeye devam eder.
      }
    }

    if (!mounted) return;

    setState(() {
      _videos = loaded;
      _currentPage = 0;
    });
  }

  Future<void> _uploadVideo() async {
    if (_uploading) return;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _message(
        'Video yüklemek için giriş yapmalısınız.',
        error: true,
      );
      return;
    }

    final video = await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video == null) return;

    final draft = await _showUploadDialog();

    if (draft == null) return;

    setState(() {
      _uploading = true;
    });

    String? uploadedPath;

    try {
      final bytes = await video.readAsBytes();

      const maxBytes = 100 * 1024 * 1024;

      if (bytes.length > maxBytes) {
        _message(
          'Video en fazla 100 MB olabilir.',
          error: true,
        );
        return;
      }

      final extension = _extension(video.name);

      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';

      uploadedPath = path;

      await _supabase.storage
          .from('community-videos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(extension),
              upsert: false,
            ),
          );

      await _supabase.from('community_videos').insert({
        'user_id': user.id,
        'storage_path': path,
        'caption': draft.caption.isEmpty
            ? null
            : draft.caption,
        'status': 'pending',
        'rights_confirmed': true,
        'community_rules_accepted': true,
      });

      _message(
        'Videonuz gönderildi. Yönetici onayından sonra yayınlanacak.',
      );
    } catch (e) {
      if (uploadedPath != null) {
        try {
          await _supabase.storage
              .from('community-videos')
              .remove([uploadedPath]);
        } catch (_) {}
      }

      _message(
        'Video yüklenemedi.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<_UploadDraft?> _showUploadDialog() async {
    final captionController = TextEditingController();

    bool rights = false;
    bool rules = false;

    final result = await showDialog<_UploadDraft>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF171717),
              title: const Text(
                'Video Gönder',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: captionController,
                      maxLength: 500,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        hintText:
                            'Videonuz hakkında kısa bir açıklama yazın',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: rights,
                      onChanged: (value) {
                        setDialogState(() {
                          rights = value ?? false;
                        });
                      },
                      title: const Text(
                        'Bu videoyu paylaşma hakkına sahibim.',
                        style: TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: rules,
                      onChanged: (value) {
                        setDialogState(() {
                          rules = value ?? false;
                        });
                      },
                      title: const Text(
                        'B_music02 topluluk kurallarını kabul ediyorum.',
                        style: TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Video, yönetici onayından önce diğer kullanıcılara gösterilmez.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: rights && rules
                      ? () {
                          Navigator.pop(
                            dialogContext,
                            _UploadDraft(
                              caption:
                                  captionController.text.trim(),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );

    captionController.dispose();

    return result;
  }

  Future<void> _showMyVideos() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    try {
      final rows = await _supabase
          .from('community_videos')
          .select(
            'id,caption,status,rejection_reason,created_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF141414),
        isScrollControlled: true,
        builder: (context) {
          return SafeArea(
            child: SizedBox(
              height:
                  MediaQuery.of(context).size.height * 0.72,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Gönderilerim',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: Text(
                              'Henüz video göndermediniz.',
                            ),
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.all(16),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final video = rows[index];

                              final status =
                                  video['status']?.toString() ??
                                      'pending';

                              return ListTile(
                                leading: Icon(
                                  _statusIcon(status),
                                  color:
                                      _statusColor(status),
                                ),
                                title: Text(
                                  _statusText(status),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (video['caption'] !=
                                            null &&
                                        video['caption']
                                            .toString()
                                            .isNotEmpty)
                                      Text(
                                        video['caption']
                                            .toString(),
                                        maxLines: 2,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    if (status ==
                                            'rejected' &&
                                        video['rejection_reason'] !=
                                            null)
                                      Text(
                                        'Red nedeni: ${video['rejection_reason']}',
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      _message(
        'Gönderiler alınamadı.',
        error: true,
      );
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return 'Yayında';
      case 'rejected':
        return 'Reddedildi';
      default:
        return 'Onay Bekliyor';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _extension(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('.') && !lower.endsWith('.')) {
      final ext = lower.split('.').last;

      if ([
        'mp4',
        'mov',
        'webm',
        'm4v',
        '3gp',
      ].contains(ext)) {
        return ext;
      }
    }

    return 'mp4';
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      case '3gp':
        return 'video/3gpp';
      default:
        return 'video/mp4';
    }
  }

  void _message(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Sizden Gelenler',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Gönderilerim',
            onPressed: _showMyVideos,
            icon: const Icon(
              Icons.video_library_outlined,
            ),
          ),
          if (_isAdmin)
            IconButton(
              tooltip: 'Yönetici Paneli',
              icon: const Icon(
                Icons.admin_panel_settings,
                color: Color(0xFFD4AF37),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AdminCommunityScreen(),
                  ),
                );

                await _loadEverything();
              },
            ),
          IconButton(
            onPressed: _loadEverything,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _videos.isEmpty
          ? _EmptyCommunity(
              uploading: _uploading,
              onUpload: _uploadVideo,
            )
          : Stack(
              children: [
                PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: _videos.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return CommunityVideoPage(
                      video: _videos[index],
                      active: index == _currentPage,
                    );
                  },
                ),
                Positioned(
                  right: 18,
                  bottom: 24,
                  child: FloatingActionButton.extended(
                    heroTag: 'community-upload',
                    onPressed:
                        _uploading ? null : _uploadVideo,
                    backgroundColor:
                        const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    icon: _uploading
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(
                            Icons.add_a_photo_outlined,
                          ),
                    label: Text(
                      _uploading
                          ? 'Yükleniyor'
                          : 'Video Yükle',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class CommunityVideoPage extends StatefulWidget {
  const CommunityVideoPage({
    super.key,
    required this.video,
    required this.active,
  });

  final Map<String, dynamic> video;
  final bool active;

  @override
  State<CommunityVideoPage> createState() =>
      _CommunityVideoPageState();
}

class _CommunityVideoPageState
    extends State<CommunityVideoPage> {
  VideoPlayerController? _controller;

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final url = widget.video['signed_url']?.toString();

    if (url == null || url.isEmpty) return;

    final controller =
        VideoPlayerController.networkUrl(
      Uri.parse(url),
    );

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);

      if (widget.active) {
        await controller.play();
      }

      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(
    covariant CommunityVideoPage oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (!_ready || _controller == null) return;

    if (widget.active && !oldWidget.active) {
      _controller!.play();
    } else if (!widget.active && oldWidget.active) {
      _controller!.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile =
        widget.video['profile'] is Map
            ? Map<String, dynamic>.from(
                widget.video['profile'],
              )
            : <String, dynamic>{};

    final username =
        profile['username']?.toString() ?? 'kullanici';

    final displayName =
        profile['display_name']?.toString();

    final caption =
        widget.video['caption']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        final controller = _controller;

        if (controller == null || !_ready) return;

        setState(() {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            child: !_ready || _controller == null
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : Center(
                    child: AspectRatio(
                      aspectRatio:
                          _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xC9000000),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 80,
            bottom: 32,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (displayName != null &&
                    displayName.isNotEmpty)
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  '@$username',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    caption,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (_ready &&
              _controller != null &&
              !_controller!.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 72,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCommunity extends StatelessWidget {
  const _EmptyCommunity({
    required this.uploading,
    required this.onUpload,
  });

  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_collection_outlined,
              size: 82,
              color: Color(0xFFD4AF37),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sizden Gelenler',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Henüz onaylanmış topluluk videosu bulunmuyor.\nİlk videoyu siz gönderin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: uploading ? null : onUpload,
              icon: const Icon(
                Icons.video_call_outlined,
              ),
              label: Text(
                uploading
                    ? 'Yükleniyor...'
                    : 'Video Gönder',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminCommunityScreen extends StatefulWidget {
  const AdminCommunityScreen({super.key});

  @override
  State<AdminCommunityScreen> createState() =>
      _AdminCommunityScreenState();
}

class _AdminCommunityScreenState
    extends State<AdminCommunityScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  late final TabController _tabController;

  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load(
    String status,
  ) async {
    final rows = await _supabase
        .from('community_videos')
        .select(
          '''
          id,
          user_id,
          storage_path,
          caption,
          status,
          rejection_reason,
          created_at,
          approved_at,
          profile:profiles!community_videos_user_id_fkey(
            username,
            display_name
          )
          ''',
        )
        .eq('status', status)
        .order('created_at', ascending: false);

    return rows
        .map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(e),
        )
        .toList();
  }

  void _refresh() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        title: const Text(
          'Video Yönetimi',
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'Bekleyenler',
            ),
            Tab(
              text: 'Yayındakiler',
            ),
            Tab(
              text: 'Reddedilenler',
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AdminVideoList(
            key: ValueKey(
              'pending-$_refreshKey',
            ),
            future: _load('pending'),
            pending: true,
            onChanged: _refresh,
          ),
          _AdminVideoList(
            key: ValueKey(
              'approved-$_refreshKey',
            ),
            future: _load('approved'),
            pending: false,
            onChanged: _refresh,
          ),
          _AdminVideoList(
            key: ValueKey(
              'rejected-$_refreshKey',
            ),
            future: _load('rejected'),
            pending: false,
            onChanged: _refresh,
          ),
        ],
      ),
    );
  }
}

class _AdminVideoList extends StatelessWidget {
  const _AdminVideoList({
    super.key,
    required this.future,
    required this.pending,
    required this.onChanged,
  });

  final Future<List<Map<String, dynamic>>> future;
  final bool pending;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Videolar alınamadı.',
            ),
          );
        }

        final videos = snapshot.data ?? [];

        if (videos.isEmpty) {
          return const Center(
            child: Text(
              'Bu bölümde video bulunmuyor.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final video = videos[index];

            final profile =
                video['profile'] is Map
                    ? Map<String, dynamic>.from(
                        video['profile'],
                      )
                    : <String, dynamic>{};

            final username =
                profile['username']?.toString() ??
                    'kullanici';

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.play_arrow,
                  ),
                ),
                title: Text(
                  '@$username',
                ),
                subtitle: Text(
                  video['caption']?.toString().isNotEmpty ==
                          true
                      ? video['caption'].toString()
                      : 'Açıklama yok',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () async {
                  final changed =
                      await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminVideoDetailScreen(
                        video: video,
                        canModerate: pending,
                      ),
                    ),
                  );

                  if (changed == true) {
                    onChanged();
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class AdminVideoDetailScreen
    extends StatefulWidget {
  const AdminVideoDetailScreen({
    super.key,
    required this.video,
    required this.canModerate,
  });

  final Map<String, dynamic> video;
  final bool canModerate;

  @override
  State<AdminVideoDetailScreen> createState() =>
      _AdminVideoDetailScreenState();
}

class _AdminVideoDetailScreenState
    extends State<AdminVideoDetailScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  VideoPlayerController? _controller;

  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    try {
      final path =
          widget.video['storage_path'].toString();

      final url = await _supabase.storage
          .from('community-videos')
          .createSignedUrl(
            path,
            60 * 30,
          );

      final controller =
          VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      _controller = controller;

      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _approve() async {
    await _moderate(
      decision: 'approved',
    );
  }

  Future<void> _reject() async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Videoyu Reddet',
          ),
          content: TextField(
            controller: controller,
            maxLength: 300,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Red nedeni',
              hintText:
                  'Örn. uygunsuz içerik veya telif',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                final text =
                    controller.text.trim();

                if (text.isEmpty) return;

                Navigator.pop(
                  dialogContext,
                  text,
                );
              },
              child: const Text('Reddet'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null) return;

    await _moderate(
      decision: 'rejected',
      reason: reason,
    );
  }

  Future<void> _moderate({
    required String decision,
    String? reason,
  }) async {
    setState(() {
      _processing = true;
    });

    try {
      await _supabase.rpc(
        'moderate_community_video',
        params: {
          'p_video_id': widget.video['id'],
          'p_decision': decision,
          'p_reason': reason,
        },
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'İşlem gerçekleştirilemedi.',
          ),
        ),
      );

      setState(() {
        _processing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption =
        widget.video['caption']?.toString() ??
            '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Video İncele',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : _controller == null ||
                          !_controller!
                              .value.isInitialized
                      ? const Text(
                          'Video açılamadı.',
                        )
                      : AspectRatio(
                          aspectRatio: _controller!
                              .value.aspectRatio,
                          child: VideoPlayer(
                            _controller!,
                          ),
                        ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            color: const Color(0xFF151515),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (caption.isNotEmpty)
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                if (widget.canModerate) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _processing ? null : _reject,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.red.shade700,
                          ),
                          icon: const Icon(Icons.close),
                          label:
                              const Text('Reddet'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _processing ? null : _approve,
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.green.shade700,
                          ),
                          icon:
                              const Icon(Icons.check),
                          label:
                              const Text('Onayla'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadDraft {
  const _UploadDraft({
    required this.caption,
  });

  final String caption;
}
