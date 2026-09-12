import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() =>
      _CommunityScreenState();
}

class _CommunityScreenState
    extends State<CommunityScreen> {
  static const gold = Color(0xFFD4AF57);
  static const burgundy = Color(0xFF7A1F3D);
  static const background = Color(0xFF090909);
  static const surface = Color(0xFF151114);

  final SupabaseClient _supabase =
      Supabase.instance.client;

  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _videos = [];

  bool _loading = true;
  bool _uploading = false;
  bool _isAdmin = false;

  String _filter = 'Tümü';

  static const List<String> _filters = [
    'Tümü',
    'Canlı',
    'Cover',
    'Remix',
    'Yeni',
  ];

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
    } catch (_) {
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

    try {
      final profile = await _supabase
          .from('profiles')
          .select('app_role')
          .eq('id', user.id)
          .single();

      final role =
          profile['app_role']?.toString();

      _isAdmin =
          role == 'admin' ||
          role == 'moderator';
    } catch (_) {
      _isAdmin = false;
    }
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
        .order(
          'approved_at',
          ascending: false,
        );

    final loaded =
        <Map<String, dynamic>>[];

    for (final raw in result) {
      final video =
          Map<String, dynamic>.from(raw);

      final path =
          video['storage_path']
              ?.toString();

      if (path == null ||
          path.isEmpty) {
        continue;
      }

      try {
        final signedUrl =
            await _supabase.storage
                .from(
                  'community-videos',
                )
                .createSignedUrl(
                  path,
                  60 * 60,
                );

        video['signed_url'] =
            signedUrl;

        loaded.add(video);
      } catch (_) {
        // Bir video açılmazsa
        // diğer videolar yüklenir.
      }
    }

    if (!mounted) return;

    setState(() {
      _videos = loaded;
    });
  }

  List<Map<String, dynamic>>
      get _filteredVideos {
    if (_filter == 'Tümü') {
      return _videos;
    }

    if (_filter == 'Yeni') {
      final limit =
          DateTime.now().subtract(
        const Duration(days: 7),
      );

      return _videos.where((video) {
        final raw =
            video['created_at']
                ?.toString();

        if (raw == null) {
          return false;
        }

        final date =
            DateTime.tryParse(raw);

        if (date == null) {
          return false;
        }

        return date.isAfter(limit);
      }).toList();
    }

    final keyword =
        _filter.toLowerCase();

    return _videos.where((video) {
      final caption =
          video['caption']
              ?.toString()
              .toLowerCase() ??
          '';

      return caption.contains(
        keyword,
      );
    }).toList();
  }

  Future<void> _uploadVideo() async {
    if (_uploading) return;

    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      _message(
        'Video yüklemek için giriş yapmalısınız.',
        error: true,
      );

      return;
    }

    final video =
        await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video == null) return;

    final draft =
        await _showUploadDialog();

    if (draft == null) return;

    setState(() {
      _uploading = true;
    });

    String? uploadedPath;

    try {
      final bytes =
          await video.readAsBytes();

      const maxBytes =
          100 * 1024 * 1024;

      if (bytes.length >
          maxBytes) {
        _message(
          'Video en fazla 100 MB olabilir.',
          error: true,
        );

        return;
      }

      final extension =
          _extension(video.name);

      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';

      uploadedPath = path;

      await _supabase.storage
          .from(
            'community-videos',
          )
          .uploadBinary(
            path,
            bytes,
            fileOptions:
                FileOptions(
              contentType:
                  _contentType(
                extension,
              ),
              upsert: false,
            ),
          );

      await _supabase
          .from(
            'community_videos',
          )
          .insert({
        'user_id': user.id,
        'storage_path': path,
        'caption':
            draft.caption.isEmpty
                ? null
                : draft.caption,
        'status': 'pending',
        'rights_confirmed':
            true,
        'community_rules_accepted':
            true,
      });

      _message(
        'Videonuz gönderildi. Yönetici onayından sonra yayınlanacak.',
      );
    } catch (_) {
      if (uploadedPath !=
          null) {
        try {
          await _supabase.storage
              .from(
                'community-videos',
              )
              .remove(
            [uploadedPath],
          );
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

  Future<_UploadDraft?>
      _showUploadDialog() async {
    final captionController =
        TextEditingController();

    bool rights = false;
    bool rules = false;

    final result =
        await showDialog<
            _UploadDraft>(
      context: context,
      barrierDismissible:
          false,
      builder: (
        dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              backgroundColor:
                  const Color(
                0xFF171317,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons
                        .video_call_outlined,
                    color: gold,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Video Gönder',
                  ),
                ],
              ),
              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    TextField(
                      controller:
                          captionController,
                      maxLength: 500,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Açıklama',
                        hintText:
                            'Video hakkında kısa bir açıklama yazın',
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    CheckboxListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      value: rights,
                      activeColor:
                          gold,
                      onChanged:
                          (value) {
                        setDialogState(
                          () {
                            rights =
                                value ??
                                    false;
                          },
                        );
                      },
                      title:
                          const Text(
                        'Bu videoyu paylaşma hakkına sahibim.',
                        style:
                            TextStyle(
                          fontSize:
                              13,
                        ),
                      ),
                    ),

                    CheckboxListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      value: rules,
                      activeColor:
                          gold,
                      onChanged:
                          (value) {
                        setDialogState(
                          () {
                            rules =
                                value ??
                                    false;
                          },
                        );
                      },
                      title:
                          const Text(
                        'B_music02 topluluk kurallarını kabul ediyorum.',
                        style:
                            TextStyle(
                          fontSize:
                              13,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Container(
                      padding:
                          const EdgeInsets
                              .all(12),
                      decoration:
                          BoxDecoration(
                        color: gold
                            .withOpacity(
                          0.07,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                      child:
                          const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Icon(
                            Icons
                                .verified_user_outlined,
                            color:
                                gold,
                            size: 18,
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Expanded(
                            child:
                                Text(
                              'Video, yönetici onayından önce diğer kullanıcılara gösterilmez.',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white60,
                                fontSize:
                                    12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text(
                    'Vazgeç',
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      rights &&
                              rules
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
                  child:
                      const Text(
                    'Gönder',
                  ),
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

  Future<void>
      _showMyVideos() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) return;

    try {
      final rows =
          await _supabase
              .from(
                'community_videos',
              )
              .select(
                'id,caption,status,rejection_reason,created_at',
              )
              .eq(
                'user_id',
                user.id,
              )
              .order(
                'created_at',
                ascending:
                    false,
              );

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor:
            surface,
        isScrollControlled:
            true,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: SizedBox(
              height:
                  MediaQuery.of(
                        context,
                      )
                          .size
                          .height *
                      0.72,
              child: Column(
                children: [
                  const Padding(
                    padding:
                        EdgeInsets.all(
                      18,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .video_library_outlined,
                          color:
                              gold,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Gönderilerim',
                          style:
                              TextStyle(
                            fontSize:
                                21,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child:
                        rows.isEmpty
                            ? const Center(
                                child:
                                    Text(
                                  'Henüz video göndermediniz.',
                                ),
                              )
                            : ListView
                                .separated(
                                padding:
                                    const EdgeInsets
                                        .all(
                                  16,
                                ),
                                itemCount:
                                    rows.length,
                                separatorBuilder:
                                    (
                                  _,
                                  __,
                                ) =>
                                        const SizedBox(
                                  height:
                                      8,
                                ),
                                itemBuilder:
                                    (
                                  context,
                                  index,
                                ) {
                                  final video =
                                      rows[index];

                                  final status =
                                      video['status']?.toString() ??
                                          'pending';

                                  return Container(
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.white.withOpacity(
                                        0.04,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(
                                        18,
                                      ),
                                      border:
                                          Border.all(
                                        color:
                                            Colors.white10,
                                      ),
                                    ),
                                    child:
                                        ListTile(
                                      leading:
                                          CircleAvatar(
                                        backgroundColor:
                                            _statusColor(
                                          status,
                                        ).withOpacity(
                                          0.15,
                                        ),
                                        child:
                                            Icon(
                                          _statusIcon(
                                            status,
                                          ),
                                          color:
                                              _statusColor(
                                            status,
                                          ),
                                        ),
                                      ),
                                      title:
                                          Text(
                                        _statusText(
                                          status,
                                        ),
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                      subtitle:
                                          Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (video['caption'] !=
                                                  null &&
                                              video['caption']
                                                  .toString()
                                                  .isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                top:
                                                    4,
                                              ),
                                              child:
                                                  Text(
                                                video['caption']
                                                    .toString(),
                                                maxLines:
                                                    2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          if (status ==
                                                  'rejected' &&
                                              video['rejection_reason'] !=
                                                  null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                top:
                                                    5,
                                              ),
                                              child:
                                                  Text(
                                                'Red nedeni: ${video['rejection_reason']}',
                                                style:
                                                    const TextStyle(
                                                  color:
                                                      Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
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

  String _statusText(
    String status,
  ) {
    switch (status) {
      case 'approved':
        return 'Yayında';
      case 'rejected':
        return 'Reddedildi';
      default:
        return 'Onay Bekliyor';
    }
  }

  IconData _statusIcon(
    String status,
  ) {
    switch (status) {
      case 'approved':
        return Icons
            .check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _extension(
    String name,
  ) {
    final lower =
        name.toLowerCase();

    if (lower.contains('.') &&
        !lower.endsWith('.')) {
      final ext =
          lower.split('.').last;

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

  String _contentType(
    String extension,
  ) {
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        behavior:
            SnackBarBehavior.floating,
        content: Text(message),
        backgroundColor: error
            ? Colors.red.shade700
            : const Color(
                0xFF242124,
              ),
      ),
    );
  }

  void _openVideo(
    Map<String, dynamic> video,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CommunityPlayerScreen(
          video: video,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Scaffold(
        backgroundColor:
            background,
        body: Center(
          child:
              CircularProgressIndicator(
            color: gold,
          ),
        ),
      );
    }

    final videos =
        _filteredVideos;

    final featured =
        videos.isNotEmpty
            ? videos.first
            : (_videos.isNotEmpty
                ? _videos.first
                : null);

    return Scaffold(
      backgroundColor:
          background,
      floatingActionButton:
          FloatingActionButton
              .extended(
        heroTag:
            'community-upload',
        onPressed: _uploading
            ? null
            : _uploadVideo,
        backgroundColor: gold,
        foregroundColor:
            Colors.black,
        icon: _uploading
            ? const SizedBox(
                width: 19,
                height: 19,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      Colors.black,
                ),
              )
            : const Icon(
                Icons
                    .add_rounded,
              ),
        label: Text(
          _uploading
              ? 'Yükleniyor'
              : 'Video Gönder',
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child:
            RefreshIndicator(
          color: gold,
          onRefresh:
              _loadEverything,
          child:
              CustomScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    18,
                    18,
                    18,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      _buildHeader(),

                      const SizedBox(
                        height: 24,
                      ),

                      if (featured !=
                          null)
                        _buildFeatured(
                          featured,
                        ),

                      if (featured !=
                          null)
                        const SizedBox(
                          height: 22,
                        ),

                      _buildFilters(),

                      const SizedBox(
                        height: 24,
                      ),

                      Row(
                        children: [
                          const Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Topluluk',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize:
                                        27,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      3,
                                ),
                                Text(
                                  'B_music02 topluluğundan videolar',
                                  style:
                                      TextStyle(
                                    color:
                                        Colors.white54,
                                    fontSize:
                                        12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal:
                                  11,
                              vertical:
                                  6,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  surface,
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                              border:
                                  Border.all(
                                color:
                                    gold.withOpacity(
                                  0.22,
                                ),
                              ),
                            ),
                            child:
                                Text(
                              '${videos.length}',
                              style:
                                  const TextStyle(
                                color:
                                    gold,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 14,
                      ),
                    ],
                  ),
                ),
              ),

              if (videos.isEmpty)
                SliverToBoxAdapter(
                  child:
                      _buildEmptyFiltered(),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    18,
                    0,
                    18,
                    120,
                  ),
                  sliver:
                      SliverGrid(
                    delegate:
                        SliverChildBuilderDelegate(
                      (
                        context,
                        index,
                      ) {
                        final video =
                            videos[index];

                        return CommunityVideoTile(
                          video:
                              video,
                          onTap:
                              () {
                            _openVideo(
                              video,
                            );
                          },
                        );
                      },
                      childCount:
                          videos.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          2,
                      crossAxisSpacing:
                          12,
                      mainAxisSpacing:
                          12,
                      childAspectRatio:
                          0.72,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,
            color: burgundy,
            border: Border.all(
              color: gold
                  .withOpacity(
                0.65,
              ),
            ),
          ),
          child: const Icon(
            Icons
                .groups_rounded,
            color: gold,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                'Sizden Gelenler',
                style: TextStyle(
                  color:
                      Colors.white,
                  fontSize: 23,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              SizedBox(
                height: 2,
              ),
              Text(
                'Topluluk sahnesi',
                style: TextStyle(
                  color: gold,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        IconButton(
          tooltip:
              'Gönderilerim',
          onPressed:
              _showMyVideos,
          icon: const Icon(
            Icons
                .video_library_outlined,
            color:
                Colors.white,
          ),
        ),

        if (_isAdmin)
          IconButton(
            tooltip:
                'Yönetici Paneli',
            onPressed:
                () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AdminCommunityScreen(),
                ),
              );

              await _loadEverything();
            },
            icon: const Icon(
              Icons
                  .admin_panel_settings_rounded,
              color: gold,
            ),
          ),
      ],
    );
  }

  Widget _buildFeatured(
    Map<String, dynamic>
        video,
  ) {
    final caption =
        video['caption']
            ?.toString()
            .trim();

    final profile =
        video['profile'] is Map
            ? Map<String,
                    dynamic>.from(
                video['profile'],
              )
            : <String,
                dynamic>{};

    final username =
        profile['username']
            ?.toString() ??
        'kullanici';

    return GestureDetector(
      onTap: () {
        _openVideo(video);
      },
      child: Container(
        height: 205,
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            25,
          ),
          gradient:
              const LinearGradient(
            begin:
                Alignment.topLeft,
            end: Alignment
                .bottomRight,
            colors: [
              burgundy,
              Color(
                0xFF241118,
              ),
              Color(
                0xFF111111,
              ),
            ],
          ),
          border: Border.all(
            color: gold
                .withOpacity(
              0.42,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: burgundy
                  .withOpacity(
                0.18,
              ),
              blurRadius: 30,
              offset:
                  const Offset(
                0,
                12,
              ),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -25,
              top: -30,
              child:
                  Container(
                width: 170,
                height: 170,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color: gold
                      .withOpacity(
                    0.06,
                  ),
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets
                      .all(
                20,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons
                            .auto_awesome_rounded,
                        color:
                            gold,
                        size:
                            18,
                      ),
                      SizedBox(
                        width:
                            7,
                      ),
                      Text(
                        'BU HAFTANIN SAHNESİ',
                        style:
                            TextStyle(
                          color:
                              gold,
                          fontSize:
                              11,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing:
                              1.4,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    caption ==
                                null ||
                            caption
                                .isEmpty
                        ? 'Topluluktan öne çıkan performans'
                        : caption,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          22,
                      height:
                          1.05,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    '@$username',
                    style:
                        const TextStyle(
                      color:
                          Colors.white60,
                      fontSize:
                          13,
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal:
                          15,
                      vertical:
                          9,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          gold,
                      borderRadius:
                          BorderRadius.circular(
                        24,
                      ),
                    ),
                    child:
                        const Row(
                      mainAxisSize:
                          MainAxisSize
                              .min,
                      children: [
                        Icon(
                          Icons
                              .play_arrow_rounded,
                          color:
                              Colors.black,
                        ),
                        SizedBox(
                          width:
                              4,
                        ),
                        Text(
                          'İzle',
                          style:
                              TextStyle(
                            color:
                                Colors.black,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 40,
      child:
          ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount:
            _filters.length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 8,
        ),
        itemBuilder:
            (context, index) {
          final item =
              _filters[index];

          final selected =
              item == _filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _filter =
                    item;
              });
            },
            child:
                AnimatedContainer(
              duration:
                  const Duration(
                milliseconds:
                    200,
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal:
                    17,
              ),
              alignment:
                  Alignment.center,
              decoration:
                  BoxDecoration(
                color: selected
                    ? gold
                    : surface,
                borderRadius:
                    BorderRadius.circular(
                  22,
                ),
                border:
                    Border.all(
                  color: selected
                      ? gold
                      : Colors
                          .white10,
                ),
              ),
              child: Text(
                item,
                style:
                    TextStyle(
                  color: selected
                      ? Colors
                          .black
                      : Colors
                          .white70,
                  fontSize:
                      13,
                  fontWeight:
                      selected
                          ? FontWeight
                              .w900
                          : FontWeight
                              .w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyFiltered() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        24,
        60,
        24,
        130,
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons
                  .video_collection_outlined,
              color:
                  Colors.white24,
              size: 68,
            ),

            const SizedBox(
              height: 16,
            ),

            Text(
              _videos.isEmpty
                  ? 'Henüz onaylanmış video yok.'
                  : '$_filter kategorisinde video bulunamadı.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white60,
                fontSize: 15,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            if (_videos.isEmpty)
              ElevatedButton.icon(
                onPressed:
                    _uploading
                        ? null
                        : _uploadVideo,
                icon:
                    const Icon(
                  Icons
                      .add_rounded,
                ),
                label:
                    const Text(
                  'İlk Videoyu Gönder',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CommunityVideoTile
    extends StatefulWidget {
  const CommunityVideoTile({
    super.key,
    required this.video,
    required this.onTap,
  });

  final Map<String, dynamic>
      video;

  final VoidCallback onTap;

  @override
  State<CommunityVideoTile>
      createState() =>
          _CommunityVideoTileState();
}

class _CommunityVideoTileState
    extends State<CommunityVideoTile> {
  static const gold =
      Color(0xFFD4AF57);

  VideoPlayerController?
      _controller;

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final url =
        widget.video[
                'signed_url']
            ?.toString();

    if (url == null ||
        url.isEmpty) {
      return;
    }

    final controller =
        VideoPlayerController
            .networkUrl(
      Uri.parse(url),
    );

    _controller = controller;

    try {
      await controller
          .initialize();

      await controller.pause();

      await controller.seekTo(
        const Duration(
          milliseconds: 100,
        ),
      );

      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final profile =
        widget.video['profile']
                is Map
            ? Map<String,
                    dynamic>.from(
                widget.video[
                    'profile'],
              )
            : <String,
                dynamic>{};

    final username =
        profile['username']
            ?.toString() ??
        'kullanici';

    final caption =
        widget.video['caption']
            ?.toString()
            .trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: Container(
          decoration:
              BoxDecoration(
            color: const Color(
              0xFF131313,
            ),
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color:
                  Colors.white10,
            ),
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(
              19,
            ),
            child: Stack(
              fit:
                  StackFit.expand,
              children: [
                if (_ready &&
                    _controller !=
                        null)
                  FittedBox(
                    fit:
                        BoxFit.cover,
                    child:
                        SizedBox(
                      width: _controller!
                          .value
                          .size
                          .width,
                      height: _controller!
                          .value
                          .size
                          .height,
                      child:
                          VideoPlayer(
                        _controller!,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration:
                        const BoxDecoration(
                      gradient:
                          LinearGradient(
                        begin:
                            Alignment.topLeft,
                        end:
                            Alignment.bottomRight,
                        colors: [
                          Color(
                            0xFF4B1327,
                          ),
                          Color(
                            0xFF191015,
                          ),
                          Colors.black,
                        ],
                      ),
                    ),
                    child:
                        const Center(
                      child:
                          CircularProgressIndicator(
                        color:
                            gold,
                        strokeWidth:
                            2,
                      ),
                    ),
                  ),

                const DecoratedBox(
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topCenter,
                      end:
                          Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(
                          0x22000000,
                        ),
                        Color(
                          0xE6000000,
                        ),
                      ],
                      stops: [
                        0.4,
                        0.62,
                        1,
                      ],
                    ),
                  ),
                ),

                const Center(
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        Color(
                      0x77000000,
                    ),
                    child: Icon(
                      Icons
                          .play_arrow_rounded,
                      color:
                          Colors.white,
                      size: 33,
                    ),
                  ),
                ),

                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        caption ==
                                    null ||
                                caption
                                    .isEmpty
                            ? 'B_music02 Topluluk'
                            : caption,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              13,
                          height:
                              1.15,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        '@$username',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Colors.white60,
                          fontSize:
                              11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CommunityPlayerScreen
    extends StatefulWidget {
  const CommunityPlayerScreen({
    super.key,
    required this.video,
  });

  final Map<String, dynamic>
      video;

  @override
  State<CommunityPlayerScreen>
      createState() =>
          _CommunityPlayerScreenState();
}

class _CommunityPlayerScreenState
    extends State<CommunityPlayerScreen> {
  static const gold =
      Color(0xFFD4AF57);

  VideoPlayerController?
      _controller;

  bool _ready = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final url =
        widget.video[
                'signed_url']
            ?.toString();

    if (url == null ||
        url.isEmpty) {
      return;
    }

    final controller =
        VideoPlayerController
            .networkUrl(
      Uri.parse(url),
    );

    _controller = controller;

    try {
      await controller
          .initialize();

      await controller
          .setLooping(true);

      await controller.play();

      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    } catch (_) {}
  }

  void _togglePlayback() {
    final controller =
        _controller;

    if (!_ready ||
        controller == null) {
      return;
    }

    setState(() {
      if (controller
          .value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }

      _showControls = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final profile =
        widget.video['profile']
                is Map
            ? Map<String,
                    dynamic>.from(
                widget.video[
                    'profile'],
              )
            : <String,
                dynamic>{};

    final username =
        profile['username']
            ?.toString() ??
        'kullanici';

    final caption =
        widget.video['caption']
            ?.toString() ??
        '';

    return Scaffold(
      backgroundColor:
          Colors.black,
      body: GestureDetector(
        onTap: _togglePlayback,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready &&
                _controller != null)
              Center(
                child:
                    AspectRatio(
                  aspectRatio:
                      _controller!
                              .value
                              .aspectRatio ==
                          0
                      ? 9 / 16
                      : _controller!
                          .value
                          .aspectRatio,
                  child:
                      VideoPlayer(
                    _controller!,
                  ),
                ),
              )
            else
              const Center(
                child:
                    CircularProgressIndicator(
                  color: gold,
                ),
              ),

            const DecoratedBox(
              decoration:
                  BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topCenter,
                  end:
                      Alignment.bottomCenter,
                  colors: [
                    Color(
                      0x66000000,
                    ),
                    Colors.transparent,
                    Color(
                      0xB8000000,
                    ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Align(
                alignment:
                    Alignment.topLeft,
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(10),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon:
                        const Icon(
                      Icons
                          .arrow_back_rounded,
                      color:
                          Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),

            if (_ready &&
                _showControls &&
                _controller != null)
              Center(
                child:
                    AnimatedOpacity(
                  opacity:
                      _showControls
                          ? 1
                          : 0,
                  duration:
                      const Duration(
                    milliseconds:
                        180,
                  ),
                  child:
                      CircleAvatar(
                    radius: 34,
                    backgroundColor:
                        Colors.black
                            .withOpacity(
                      0.45,
                    ),
                    child: Icon(
                      _controller!
                              .value
                              .isPlaying
                          ? Icons
                              .pause_rounded
                          : Icons
                              .play_arrow_rounded,
                      color:
                          Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),

            Positioned(
              left: 18,
              right: 18,
              bottom: 30,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    '@$username',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  if (caption
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 8,
                    ),
                    Text(
                      caption,
                      maxLines: 3,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            14,
                        height:
                            1.3,
                      ),
                    ),
                  ],

                  if (_ready &&
                      _controller !=
                          null) ...[
                    const SizedBox(
                      height: 14,
                    ),
                    VideoProgressIndicator(
                      _controller!,
                      allowScrubbing:
                          true,
                      colors:
                          const VideoProgressColors(
                        playedColor:
                            gold,
                        bufferedColor:
                            Colors.white30,
                        backgroundColor:
                            Colors.white12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminCommunityScreen
    extends StatefulWidget {
  const AdminCommunityScreen({
    super.key,
  });

  @override
  State<AdminCommunityScreen>
      createState() =>
          _AdminCommunityScreenState();
}

class _AdminCommunityScreenState
    extends State<AdminCommunityScreen> {
  static const gold =
      Color(0xFFD4AF57);

  final SupabaseClient _supabase =
      Supabase.instance.client;

  List<Map<String, dynamic>>
      _pending = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final result =
          await _supabase
              .from(
                'community_videos',
              )
              .select(
                '''
                id,
                user_id,
                storage_path,
                caption,
                status,
                created_at,
                profile:profiles!community_videos_user_id_fkey(
                  username,
                  display_name,
                  avatar_url
                )
                ''',
              )
              .eq(
                'status',
                'pending',
              )
              .order(
                'created_at',
                ascending:
                    false,
              );

      final loaded =
          <Map<String, dynamic>>[];

      for (final raw
          in result) {
        final item =
            Map<String,
                dynamic>.from(
          raw,
        );

        final path =
            item['storage_path']
                ?.toString();

        if (path != null &&
            path.isNotEmpty) {
          try {
            item['signed_url'] =
                await _supabase
                    .storage
                    .from(
                      'community-videos',
                    )
                    .createSignedUrl(
                      path,
                      60 * 60,
                    );
          } catch (_) {}
        }

        loaded.add(item);
      }

      if (!mounted) return;

      setState(() {
        _pending = loaded;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Onay bekleyen videolar alınamadı.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _approve(
    Map<String, dynamic> video,
  ) async {
    final id = video['id'];

    if (id == null) return;

    try {
      await _supabase
          .from(
            'community_videos',
          )
          .update({
        'status': 'approved',
        'approved_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
        'rejection_reason':
            null,
      }).eq(
        'id',
        id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Video yayına alındı.',
          ),
        ),
      );

      await _load();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Video onaylanamadı.',
          ),
        ),
      );
    }
  }

  Future<void> _reject(
    Map<String, dynamic> video,
  ) async {
    final id = video['id'];

    if (id == null) return;

    final controller =
        TextEditingController();

    final reason =
        await showDialog<
            String>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              const Color(
            0xFF171717,
          ),
          title: const Text(
            'Videoyu Reddet',
          ),
          content: TextField(
            controller:
                controller,
            maxLines: 4,
            maxLength: 300,
            decoration:
                const InputDecoration(
              labelText:
                  'Red nedeni',
              hintText:
                  'Kullanıcıya gösterilecek açıklama',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text(
                'Vazgeç',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final text =
                    controller.text
                        .trim();

                if (text
                    .isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  text,
                );
              },
              child:
                  const Text(
                'Reddet',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (reason == null ||
        reason.isEmpty) {
      return;
    }

    try {
      await _supabase
          .from(
            'community_videos',
          )
          .update({
        'status': 'rejected',
        'rejection_reason':
            reason,
        'approved_at': null,
      }).eq(
        'id',
        id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Video reddedildi.',
          ),
        ),
      );

      await _load();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Video reddedilemedi.',
          ),
        ),
      );
    }
  }

  void _preview(
    Map<String, dynamic> video,
  ) {
    final url =
        video['signed_url']
            ?.toString();

    if (url == null ||
        url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Video önizlemesi açılamadı.',
          ),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CommunityPlayerScreen(
          video: video,
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
          const Color(
        0xFF090909,
      ),
      appBar: AppBar(
        title: const Text(
          'Yönetici Paneli',
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: gold,
              ),
            )
          : _pending.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize
                            .min,
                    children: [
                      Icon(
                        Icons
                            .verified_rounded,
                        size: 72,
                        color:
                            Colors.green,
                      ),
                      SizedBox(
                        height: 16,
                      ),
                      Text(
                        'Onay bekleyen video yok.',
                        style:
                            TextStyle(
                          color:
                              Colors.white70,
                          fontSize:
                              16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    16,
                    16,
                    16,
                    40,
                  ),
                  itemCount:
                      _pending.length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height: 12,
                  ),
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final video =
                        _pending[
                            index];

                    final profile =
                        video['profile']
                                is Map
                            ? Map<String,
                                    dynamic>.from(
                                video[
                                    'profile'],
                              )
                            : <String,
                                dynamic>{};

                    final username =
                        profile['username']
                                ?.toString() ??
                            'kullanici';

                    final caption =
                        video['caption']
                                ?.toString()
                                .trim() ??
                            '';

                    return Container(
                      padding:
                          const EdgeInsets
                              .all(
                        16,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFF151515,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                        border:
                            Border.all(
                          color:
                              Colors.white10,
                        ),
                      ),
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor:
                                    Color(
                                  0xFF7A1F3D,
                                ),
                                child:
                                    Icon(
                                  Icons
                                      .person_outline,
                                  color:
                                      gold,
                                ),
                              ),

                              const SizedBox(
                                width:
                                    10,
                              ),

                              Expanded(
                                child:
                                    Text(
                                  '@$username',
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w900,
                                    fontSize:
                                        15,
                                  ),
                                ),
                              ),

                              const ContainerStatusPending(),
                            ],
                          ),

                          if (caption
                              .isNotEmpty) ...[
                            const SizedBox(
                              height:
                                  14,
                            ),
                            Text(
                              caption,
                              style:
                                  const TextStyle(
                                color:
                                    Colors.white70,
                              ),
                            ),
                          ],

                          const SizedBox(
                            height:
                                16,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child:
                                    OutlinedButton.icon(
                                  onPressed:
                                      () {
                                    _preview(
                                      video,
                                    );
                                  },
                                  icon:
                                      const Icon(
                                    Icons
                                        .play_circle_outline_rounded,
                                  ),
                                  label:
                                      const Text(
                                    'İncele',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width:
                                    8,
                              ),

                              Expanded(
                                child:
                                    OutlinedButton.icon(
                                  onPressed:
                                      () {
                                    _reject(
                                      video,
                                    );
                                  },
                                  icon:
                                      const Icon(
                                    Icons
                                        .close_rounded,
                                  ),
                                  label:
                                      const Text(
                                    'Reddet',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          SizedBox(
                            width:
                                double
                                    .infinity,
                            child:
                                ElevatedButton.icon(
                              onPressed:
                                  () {
                                _approve(
                                  video,
                                );
                              },
                              icon:
                                  const Icon(
                                Icons
                                    .check_rounded,
                              ),
                              label:
                                  const Text(
                                'Onayla ve Yayınla',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class ContainerStatusPending
    extends StatelessWidget {
  const ContainerStatusPending({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color: Colors.orange
            .withOpacity(
          0.12,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: const Text(
        'Onay Bekliyor',
        style: TextStyle(
          color:
              Colors.orange,
          fontSize: 10,
          fontWeight:
              FontWeight.w800,
        ),
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
