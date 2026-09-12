import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
  });

  @override
  State<CommunityScreen> createState() =>
      _CommunityScreenState();
}

class _CommunityScreenState
    extends State<CommunityScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final ImagePicker _picker =
      ImagePicker();

  final TextEditingController
      _captionController =
      TextEditingController();

  static const int _maxUploadBytes =
      400 * 1024 * 1024;

  int _selectedTab = 0;

  String? _selectedCategoryId;

  bool _loading = true;
  bool _uploading = false;

  List<_CommunityCategory> _categories = [];
  List<_CommunityVideo> _approved = [];
  List<_CommunityVideo> _mine = [];

  User? get _user =>
      _supabase.auth.currentUser;

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

  List<_CommunityVideo>
      get _filteredApproved {
    if (_selectedCategoryId == null) {
      return _approved;
    }

    return _approved
        .where(
          (video) =>
              video.categoryId ==
              _selectedCategoryId,
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();

    _loadContent();
  }

  @override
  void dispose() {
    _captionController.dispose();

    super.dispose();
  }

  Future<void> _loadContent() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final categoryRows =
          await _supabase
              .from(
                'community_categories',
              )
              .select(
                'id, name, slug, sort_order',
              )
              .eq(
                'is_active',
                true,
              )
              .order(
                'sort_order',
              );

      final categories =
          <_CommunityCategory>[];

      final categoryNames =
          <String, String>{};

      for (final raw in categoryRows) {
        final row =
            Map<String, dynamic>.from(
          raw,
        );

        final id =
            row['id']?.toString();

        final name =
            row['name']?.toString();

        if (id == null ||
            id.isEmpty ||
            name == null ||
            name.isEmpty) {
          continue;
        }

        categories.add(
          _CommunityCategory(
            id: id,
            name: name,
            slug:
                row['slug']
                        ?.toString() ??
                    '',
            sortOrder:
                int.tryParse(
                      row['sort_order']
                              ?.toString() ??
                          '0',
                    ) ??
                    0,
          ),
        );

        categoryNames[id] = name;
      }

      final approvedRows =
          await _supabase
              .from(
                'community_videos',
              )
              .select(
                'id, user_id, storage_path, caption, status, rejection_reason, created_at, category_id',
              )
              .eq(
                'status',
                'approved',
              )
              .order(
                'created_at',
                ascending: false,
              );

      final myRows =
          _user == null
              ? <dynamic>[]
              : await _supabase
                  .from(
                    'community_videos',
                  )
                  .select(
                    'id, user_id, storage_path, caption, status, rejection_reason, created_at, category_id',
                  )
                  .eq(
                    'user_id',
                    _user!.id,
                  )
                  .order(
                    'created_at',
                    ascending: false,
                  );

      final approved =
          await _prepareVideos(
        approvedRows,
        categoryNames,
      );

      final mine =
          await _prepareVideos(
        myRows,
        categoryNames,
      );

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _approved = approved;
        _mine = mine;
        _loading = false;

        if (_selectedCategoryId !=
                null &&
            !_categories.any(
              (category) =>
                  category.id ==
                  _selectedCategoryId,
            )) {
          _selectedCategoryId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Topluluk içerikleri yüklenemedi.',
      );
    }
  }

  Future<List<_CommunityVideo>>
      _prepareVideos(
    dynamic rows,
    Map<String, String>
        categoryNames,
  ) async {
    final result =
        <_CommunityVideo>[];

    for (final raw in rows) {
      final row =
          Map<String, dynamic>.from(
        raw,
      );

      final storagePath =
          row['storage_path']
              ?.toString();

      if (storagePath == null ||
          storagePath.isEmpty) {
        continue;
      }

      String? signedUrl;

      try {
        signedUrl =
            await _supabase.storage
                .from(
                  'community-videos',
                )
                .createSignedUrl(
                  storagePath,
                  3600,
                );
      } catch (_) {}

      final categoryId =
          row['category_id']
              ?.toString();

      result.add(
        _CommunityVideo(
          id:
              row['id']
                      ?.toString() ??
                  '',
          userId:
              row['user_id']
                      ?.toString() ??
                  '',
          storagePath:
              storagePath,
          videoUrl:
              signedUrl,
          caption:
              row['caption']
                  ?.toString(),
          status:
              row['status']
                      ?.toString() ??
                  'pending',
          rejectionReason:
              row[
                      'rejection_reason']
                  ?.toString(),
          categoryId:
              categoryId,
          categoryName:
              categoryId != null
                  ? categoryNames[
                          categoryId] ??
                      'Genel'
                  : 'Genel',
          createdAt:
              DateTime.tryParse(
                    row['created_at']
                            ?.toString() ??
                        '',
                  ) ??
                  DateTime.now(),
        ),
      );
    }

    return result;
  }

  Future<void> _pickAndUpload() async {
    if (_user == null) {
      _showMessage(
        'Video yüklemek için giriş yapmalısınız.',
      );

      return;
    }

    if (_uploading) {
      return;
    }

    if (_categories.isEmpty) {
      _showMessage(
        'Henüz kullanılabilir kategori yok.',
      );

      return;
    }

    final video =
        await _picker.pickVideo(
      source:
          ImageSource.gallery,
    );

    if (video == null) {
      return;
    }

    final length =
        await video.length();

    if (length >
        _maxUploadBytes) {
      _showMessage(
        'Video 400 MB sınırını aşıyor.',
      );

      return;
    }

    if (!mounted) return;

    final uploadData =
        await _showUploadConfirmation(
      length,
    );

    if (uploadData == null ||
        !mounted) {
      return;
    }

    setState(() {
      _uploading = true;
    });

    String? uploadedStoragePath;

    try {
      final file =
          File(
        video.path,
      );

      final extension =
          _fileExtension(
        video.name,
      );

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}$extension';

      final storagePath =
          '${_user!.id}/$fileName';

      uploadedStoragePath =
          storagePath;

      await _supabase.storage
          .from(
            'community-videos',
          )
          .upload(
            storagePath,
            file,
            fileOptions:
                FileOptions(
              upsert: false,
              contentType:
                  video.mimeType ??
                      'video/mp4',
            ),
          );

      final caption =
          uploadData.caption
              .trim();

      await _supabase
          .from(
            'community_videos',
          )
          .insert(
        {
          'user_id':
              _user!.id,
          'storage_path':
              storagePath,
          'caption':
              caption.isEmpty
                  ? null
                  : caption,
          'category_id':
              uploadData.categoryId,
          'status':
              'pending',
          'rights_confirmed':
              true,
          'community_rules_accepted':
              true,
        },
      );

      _captionController.clear();

      if (!mounted) return;

      _showMessage(
        'Video gönderildi. Yönetici onayından sonra yayınlanacak.',
      );

      await _loadContent();

      if (!mounted) return;

      setState(() {
        _selectedTab = 1;
      });
    } on StorageException catch (error) {
      if (!mounted) return;

      final message =
          error.message
              .toLowerCase();

      if (message.contains(
            'size',
          ) ||
          message.contains(
            'large',
          ) ||
          message.contains(
            'limit',
          )) {
        _showMessage(
          'Supabase depolama sınırı bu video boyutuna izin vermedi.',
        );
      } else {
        _showMessage(
          'Video yüklenemedi: ${error.message}',
        );
      }
    } catch (_) {
      if (uploadedStoragePath !=
          null) {
        try {
          await _supabase.storage
              .from(
                'community-videos',
              )
              .remove(
            [
              uploadedStoragePath,
            ],
          );
        } catch (_) {}
      }

      if (!mounted) return;

      _showMessage(
        'Video yüklenirken bir hata oluştu.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<_UploadData?>
      _showUploadConfirmation(
    int bytes,
  ) {
    bool rightsConfirmed =
        false;

    bool rulesAccepted =
        false;

    String selectedCategoryId =
        _categories.first.id;

    _captionController.clear();

    return showModalBottomSheet<
        _UploadData>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (
        sheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            final canContinue =
                rightsConfirmed &&
                    rulesAccepted;

            return Padding(
              padding:
                  EdgeInsets.only(
                bottom:
                    MediaQuery.of(
                  context,
                ).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  margin:
                      const EdgeInsets.all(
                    12,
                  ),
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    20,
                    15,
                    20,
                    20,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Theme.of(
                      context,
                    )
                            .colorScheme
                            .surface,
                    borderRadius:
                        BorderRadius
                            .circular(
                      30,
                    ),
                    border:
                        Border.all(
                      color:
                          AppColors.gold
                              .withOpacity(
                        0.22,
                      ),
                    ),
                  ),
                  child:
                      SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 4,
                          decoration:
                              BoxDecoration(
                            color:
                                _text
                                    .withOpacity(
                              0.15,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              20,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration:
                                  BoxDecoration(
                                color:
                                    AppColors.gold
                                        .withOpacity(
                                  0.12,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  15,
                                ),
                              ),
                              child:
                                  const Icon(
                                Icons
                                    .cloud_upload_rounded,
                                color:
                                    AppColors.gold,
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
                                    'Videoyu Gönder',
                                    style:
                                        TextStyle(
                                      color:
                                          _text,
                                      fontSize:
                                          20,
                                      fontWeight:
                                          FontWeight
                                              .w900,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 3,
                                  ),

                                  Text(
                                    _formatBytes(
                                      bytes,
                                    ),
                                    style:
                                        const TextStyle(
                                      color:
                                          AppColors.gold,
                                      fontSize:
                                          11,
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        DropdownButtonFormField<
                            String>(
                          value:
                              selectedCategoryId,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Oynatma listesi',
                            prefixIcon:
                                Icon(
                              Icons
                                  .playlist_play_rounded,
                            ),
                          ),
                          items:
                              _categories
                                  .map(
                            (
                              category,
                            ) {
                              return DropdownMenuItem<
                                  String>(
                                value:
                                    category.id,
                                child:
                                    Text(
                                  category.name,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: (
                            value,
                          ) {
                            if (value ==
                                null) {
                              return;
                            }

                            setSheetState(
                              () {
                                selectedCategoryId =
                                    value;
                              },
                            );
                          },
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        TextField(
                          controller:
                              _captionController,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 500,
                          textCapitalization:
                              TextCapitalization
                                  .sentences,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Açıklama',
                            hintText:
                                'Video hakkında kısa bir açıklama...',
                            alignLabelWithHint:
                                true,
                            prefixIcon:
                                Icon(
                              Icons
                                  .notes_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        CheckboxListTile(
                          value:
                              rightsConfirmed,
                          contentPadding:
                              EdgeInsets.zero,
                          activeColor:
                              AppColors.gold,
                          checkColor:
                              Colors.black,
                          title:
                              const Text(
                            'Bu videoyu paylaşma hakkım var.',
                          ),
                          subtitle:
                              const Text(
                            'Size ait veya paylaşım izni bulunan içerikler yüklenmelidir.',
                          ),
                          onChanged: (
                            value,
                          ) {
                            setSheetState(
                              () {
                                rightsConfirmed =
                                    value ??
                                        false;
                              },
                            );
                          },
                        ),

                        CheckboxListTile(
                          value:
                              rulesAccepted,
                          contentPadding:
                              EdgeInsets.zero,
                          activeColor:
                              AppColors.gold,
                          checkColor:
                              Colors.black,
                          title:
                              const Text(
                            'Topluluk kurallarını kabul ediyorum.',
                          ),
                          onChanged: (
                            value,
                          ) {
                            setSheetState(
                              () {
                                rulesAccepted =
                                    value ??
                                        false;
                              },
                            );
                          },
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets.all(
                            13,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                AppColors.gold
                                    .withOpacity(
                              0.08,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                            border:
                                Border.all(
                              color:
                                  AppColors.gold
                                      .withOpacity(
                                0.15,
                              ),
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
                                    .info_outline_rounded,
                                color:
                                    AppColors.gold,
                                size: 19,
                              ),

                              SizedBox(
                                width: 9,
                              ),

                              Expanded(
                                child: Text(
                                  'Video seçtiğiniz oynatma listesine bağlanır. Yönetici onayından sonra toplulukta yayınlanır.',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        10,
                                    height:
                                        1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          height: 52,
                          child:
                              FilledButton.icon(
                            onPressed:
                                canContinue
                                    ? () {
                                        Navigator.pop(
                                          sheetContext,
                                          _UploadData(
                                            categoryId:
                                                selectedCategoryId,
                                            caption:
                                                _captionController.text,
                                          ),
                                        );
                                      }
                                    : null,
                            icon:
                                const Icon(
                              Icons
                                  .send_rounded,
                            ),
                            label:
                                const Text(
                              'Onaya Gönder',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _fileExtension(
    String name,
  ) {
    final index =
        name.lastIndexOf(
      '.',
    );

    if (index < 0) {
      return '.mp4';
    }

    final extension =
        name.substring(
      index,
    );

    if (extension.length > 8) {
      return '.mp4';
    }

    return extension;
  }

  String _formatBytes(
    int bytes,
  ) {
    final mb =
        bytes /
            (1024 * 1024);

    if (mb >= 100) {
      return '${mb.toStringAsFixed(0)} MB';
    }

    return '${mb.toStringAsFixed(1)} MB';
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(
          message,
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
        child:
            RefreshIndicator(
          color:
              AppColors.gold,
          onRefresh:
              _loadContent,
          child:
              CustomScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child:
                    _buildHeader(),
              ),

              SliverToBoxAdapter(
                child:
                    _buildUploadCard(),
              ),

              SliverToBoxAdapter(
                child:
                    _buildTabs(),
              ),

              if (_selectedTab == 0)
                SliverToBoxAdapter(
                  child:
                      _buildCategoryBar(),
                ),

              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody:
                      false,
                  child:
                      Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          AppColors.gold,
                    ),
                  ),
                )
              else
                _selectedTab == 0
                    ? _buildApprovedSliver()
                    : _buildMineSliver(),

              const SliverToBoxAdapter(
                child:
                    SizedBox(
                  height: 130,
                ),
              ),
            ],
          ),
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
            width: 49,
            height: 49,
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
                  .video_library_rounded,
              color:
                  Colors.white,
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
                  'Topluluk',
                  style:
                      TextStyle(
                    color:
                        _text,
                    fontSize: 26,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing:
                        -0.7,
                  ),
                ),

                Text(
                  'B_music02 kullanıcılarından',
                  style:
                      TextStyle(
                    color:
                        _muted,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed:
                _loadContent,
            icon:
                const Icon(
              Icons.refresh_rounded,
              color:
                  AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        20,
        18,
        18,
      ),
      child:
          GestureDetector(
        onTap:
            _uploading
                ? null
                : _pickAndUpload,
        child:
            AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 200,
          ),
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              26,
            ),
            gradient:
                LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                AppColors.gold
                    .withOpacity(
                  0.15,
                ),
                AppColors.burgundy
                    .withOpacity(
                  0.11,
                ),
                _surface,
              ],
            ),
            border:
                Border.all(
              color:
                  AppColors.gold
                      .withOpacity(
                0.22,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.gold,
                  borderRadius:
                      BorderRadius.circular(
                    19,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          AppColors.gold
                              .withOpacity(
                        0.24,
                      ),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child:
                    _uploading
                        ? const Padding(
                            padding:
                                EdgeInsets.all(
                              18,
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
                                .add_rounded,
                            color:
                                Colors.black,
                            size: 30,
                          ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      _uploading
                          ? 'Video yükleniyor...'
                          : 'Videonu Gönder',
                      style:
                          TextStyle(
                        color:
                            _text,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'Kategori seç • Maksimum 400 MB • Onay sonrası yayınlanır',
                      style:
                          TextStyle(
                        color:
                            _muted,
                        fontSize: 9,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    AppColors.gold,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        0,
        18,
        12,
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
                Theme.of(
              context,
            ).dividerColor,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child:
                  _CommunityTab(
                selected:
                    _selectedTab ==
                        0,
                icon:
                    Icons
                        .explore_rounded,
                title:
                    'Keşfet',
                count:
                    _approved.length,
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
              child:
                  _CommunityTab(
                selected:
                    _selectedTab ==
                        1,
                icon:
                    Icons
                        .account_circle_rounded,
                title:
                    'Gönderilerim',
                count:
                    _mine.length,
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

  Widget _buildCategoryBar() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        0,
        18,
        18,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons
                    .playlist_play_rounded,
                color:
                    AppColors.gold,
                size: 20,
              ),

              const SizedBox(
                width: 7,
              ),

              Text(
                'Oynatma Listeleri',
                style:
                    TextStyle(
                  color:
                      _text,
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 11,
          ),

          SizedBox(
            height: 42,
            child:
                ListView(
              scrollDirection:
                  Axis.horizontal,
              children: [
                _CategoryChip(
                  title:
                      'Tümü',
                  selected:
                      _selectedCategoryId ==
                          null,
                  count:
                      _approved.length,
                  onTap: () {
                    setState(() {
                      _selectedCategoryId =
                          null;
                    });
                  },
                ),

                for (final category
                    in _categories) ...[
                  const SizedBox(
                    width: 8,
                  ),

                  _CategoryChip(
                    title:
                        category.name,
                    selected:
                        _selectedCategoryId ==
                            category.id,
                    count:
                        _approved
                            .where(
                              (
                                video,
                              ) =>
                                  video.categoryId ==
                                  category.id,
                            )
                            .length,
                    onTap: () {
                      setState(() {
                        _selectedCategoryId =
                            category.id;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedSliver() {
    final videos =
        _filteredApproved;

    if (videos.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody:
            false,
        child:
            _EmptyCommunity(
          icon:
              Icons
                  .video_collection_outlined,
          title:
              'Bu listede video yok',
          subtitle:
              'Onaylanan videolar burada görünecek.',
        ),
      );
    }

    return SliverPadding(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 18,
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

            return _CommunityVideoCard(
              video:
                  video,
            );
          },
          childCount:
              videos.length,
        ),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 11,
          mainAxisSpacing: 11,
          childAspectRatio: 0.68,
        ),
      ),
    );
  }

  Widget _buildMineSliver() {
    if (_mine.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody:
            false,
        child:
            _EmptyCommunity(
          icon:
              Icons
                  .cloud_upload_outlined,
          title:
              'Henüz gönderin yok',
          subtitle:
              'Yüklediğin videoların onay durumunu burada takip edebilirsin.',
        ),
      );
    }

    return SliverPadding(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 18,
      ),
      sliver:
          SliverList(
        delegate:
            SliverChildBuilderDelegate(
          (
            context,
            index,
          ) {
            final video =
                _mine[index];

            return Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 10,
              ),
              child:
                  _MySubmissionCard(
                video:
                    video,
              ),
            );
          },
          childCount:
              _mine.length,
        ),
      ),
    );
  }
}

class _CommunityVideoCard
    extends StatefulWidget {
  const _CommunityVideoCard({
    required this.video,
  });

  final _CommunityVideo video;

  @override
  State<_CommunityVideoCard>
      createState() =>
          _CommunityVideoCardState();
}

class _CommunityVideoCardState
    extends State<
        _CommunityVideoCard> {
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
        widget.video.videoUrl;

    if (url == null ||
        url.isEmpty) {
      return;
    }

    try {
      final controller =
          VideoPlayerController
              .networkUrl(
        Uri.parse(
          url,
        ),
      );

      await controller.initialize();

      await controller.seekTo(
        const Duration(
          milliseconds: 300,
        ),
      );

      await controller.pause();

      if (!mounted) {
        await controller.dispose();

        return;
      }

      setState(() {
        _controller =
            controller;

        _ready = true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();

    super.dispose();
  }

  void _open() {
    if (widget.video.videoUrl ==
        null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _CommunityPlayerPage(
          video:
              widget.video,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap:
          _open,
      child:
          ClipRRect(
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        child: Stack(
          fit:
              StackFit.expand,
          children: [
            Container(
              color:
                  const Color(
                0xFF171214,
              ),
            ),

            if (_ready &&
                _controller !=
                    null)
              FittedBox(
                fit:
                    BoxFit.cover,
                clipBehavior:
                    Clip.hardEdge,
                child:
                    SizedBox(
                  width:
                      _controller!
                          .value
                          .size
                          .width,
                  height:
                      _controller!
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
              const Center(
                child:
                    Icon(
                  Icons
                      .video_library_rounded,
                  color:
                      AppColors.gold,
                  size: 42,
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
                      0xB8000000,
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 8,
              top: 8,
              child:
                  Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.black
                          .withOpacity(
                    0.66,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                child:
                    Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons
                          .playlist_play_rounded,
                      color:
                          AppColors.gold,
                      size: 13,
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      widget.video
                          .categoryName,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 8,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Center(
              child:
                  Container(
                width: 49,
                height: 49,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      Colors.black
                          .withOpacity(
                    0.55,
                  ),
                  border:
                      Border.all(
                    color:
                        Colors.white24,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .play_arrow_rounded,
                  color:
                      Colors.white,
                  size: 31,
                ),
              ),
            ),

            if (widget
                        .video
                        .caption
                        ?.trim()
                        .isNotEmpty ==
                    true)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child:
                    Text(
                  widget
                      .video
                      .caption!,
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                    shadows: [
                      Shadow(
                        color:
                            Colors.black,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommunityPlayerPage
    extends StatefulWidget {
  const _CommunityPlayerPage({
    required this.video,
  });

  final _CommunityVideo video;

  @override
  State<_CommunityPlayerPage>
      createState() =>
          _CommunityPlayerPageState();
}

class _CommunityPlayerPageState
    extends State<
        _CommunityPlayerPage> {
  VideoPlayerController?
      _controller;

  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    final url =
        widget.video.videoUrl;

    if (url == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });

      return;
    }

    try {
      final controller =
          VideoPlayerController
              .networkUrl(
        Uri.parse(
          url,
        ),
      );

      await controller.initialize();

      await controller.setLooping(
        true,
      );

      await controller.play();

      if (!mounted) {
        await controller.dispose();

        return;
      }

      setState(() {
        _controller =
            controller;

        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();

    super.dispose();
  }

  void _toggle() {
    final controller =
        _controller;

    if (controller == null) {
      return;
    }

    setState(() {
      if (controller
          .value
          .isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,
      body: SafeArea(
        child: Stack(
          fit:
              StackFit.expand,
          children: [
            if (_loading)
              const Center(
                child:
                    CircularProgressIndicator(
                  color:
                      AppColors.gold,
                ),
              )
            else if (_failed ||
                _controller ==
                    null)
              const Center(
                child:
                    Text(
                  'Video açılamadı.',
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap:
                    _toggle,
                child:
                    Center(
                  child:
                      AspectRatio(
                    aspectRatio:
                        _controller!
                            .value
                            .aspectRatio,
                    child:
                        VideoPlayer(
                      _controller!,
                    ),
                  ),
                ),
              ),

            Positioned(
              top: 12,
              left: 12,
              child:
                  Material(
                color:
                    Colors.black54,
                shape:
                    const CircleBorder(),
                child:
                    IconButton(
                  onPressed:
                      () {
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
                  ),
                ),
              ),
            ),

            Positioned(
              top: 17,
              left: 70,
              child:
                  Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.black54,
                  borderRadius:
                      BorderRadius
                          .circular(
                    15,
                  ),
                ),
                child:
                    Text(
                  widget.video
                      .categoryName,
                  style:
                      const TextStyle(
                    color:
                        AppColors.gold,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ),

            if (!_loading &&
                !_failed &&
                _controller !=
                    null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child:
                    VideoProgressIndicator(
                  _controller!,
                  allowScrubbing:
                      true,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 8,
                  ),
                  colors:
                      const VideoProgressColors(
                    playedColor:
                        AppColors.gold,
                    bufferedColor:
                        Colors.white24,
                    backgroundColor:
                        Colors.white12,
                  ),
                ),
              ),

            if (widget
                        .video
                        .caption
                        ?.trim()
                        .isNotEmpty ==
                    true)
              Positioned(
                left: 18,
                right: 18,
                bottom: 48,
                child:
                    Text(
                  widget
                      .video
                      .caption!,
                  maxLines: 3,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 13,
                    shadows: [
                      Shadow(
                        color:
                            Colors.black,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MySubmissionCard
    extends StatelessWidget {
  const _MySubmissionCard({
    required this.video,
  });

  final _CommunityVideo video;

  Color _statusColor() {
    switch (video.status) {
      case 'approved':
        return const Color(
          0xFF43C977,
        );

      case 'rejected':
        return const Color(
          0xFFE66767,
        );

      default:
        return AppColors.gold;
    }
  }

  String _statusText() {
    switch (video.status) {
      case 'approved':
        return 'Onaylandı';

      case 'rejected':
        return 'Reddedildi';

      default:
        return 'İncelemede';
    }
  }

  IconData _statusIcon() {
    switch (video.status) {
      case 'approved':
        return Icons
            .check_circle_rounded;

      case 'rejected':
        return Icons
            .cancel_rounded;

      default:
        return Icons
            .schedule_rounded;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final text =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .surface,
        borderRadius:
            BorderRadius.circular(
          22,
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
          Container(
            width: 55,
            height: 70,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF171214,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
            ),
            child:
                const Icon(
              Icons.movie_rounded,
              color:
                  AppColors.gold,
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
                  video.caption
                              ?.trim()
                              .isNotEmpty ==
                          true
                      ? video.caption!
                      : 'Topluluk videosu',
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    color:
                        text,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons
                          .playlist_play_rounded,
                      color:
                          AppColors.gold,
                      size: 14,
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    Text(
                      video.categoryName,
                      style:
                          const TextStyle(
                        color:
                            AppColors.gold,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 6,
                ),

                Row(
                  children: [
                    Icon(
                      _statusIcon(),
                      color:
                          _statusColor(),
                      size: 15,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Text(
                      _statusText(),
                      style:
                          TextStyle(
                        color:
                            _statusColor(),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                if (video.status ==
                        'rejected' &&
                    video.rejectionReason
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    video
                        .rejectionReason!,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        TextStyle(
                      color:
                          text.withOpacity(
                        0.40,
                      ),
                      fontSize: 9,
                    ),
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

class _CategoryChip
    extends StatelessWidget {
  const _CategoryChip({
    required this.title,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final int count;
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
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 14,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? AppColors.gold
                  : Theme.of(
                      context,
                    )
                      .colorScheme
                      .surface,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          border:
              Border.all(
            color:
                selected
                    ? AppColors.gold
                    : Theme.of(
                        context,
                      )
                        .dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons
                  .playlist_play_rounded,
              size: 16,
              color:
                  selected
                      ? Colors.black
                      : AppColors.gold,
            ),

            const SizedBox(
              width: 5,
            ),

            Text(
              title,
              style:
                  TextStyle(
                color:
                    selected
                        ? Colors.black
                        : text,
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              width: 6,
            ),

            Text(
              '$count',
              style:
                  TextStyle(
                color:
                    selected
                        ? Colors.black54
                        : text.withOpacity(
                            0.38,
                          ),
                fontSize: 9,
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

class _CommunityTab
    extends StatelessWidget {
  const _CommunityTab({
    required this.selected,
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final int count;
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
              size: 17,
              color:
                  selected
                      ? Colors.black
                      : text.withOpacity(
                          0.45,
                        ),
            ),

            const SizedBox(
              width: 5,
            ),

            Text(
              title,
              style:
                  TextStyle(
                color:
                    selected
                        ? Colors.black
                        : text.withOpacity(
                            0.55,
                          ),
                fontSize: 11,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              width: 5,
            ),

            Text(
              '$count',
              style:
                  TextStyle(
                color:
                    selected
                        ? Colors.black54
                        : AppColors.gold,
                fontSize: 9,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCommunity
    extends StatelessWidget {
  const _EmptyCommunity({
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
              width: 82,
              height: 82,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    AppColors.gold
                        .withOpacity(
                  0.09,
                ),
              ),
              child:
                  Icon(
                icon,
                color:
                    AppColors.gold,
                size: 39,
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

class _UploadData {
  const _UploadData({
    required this.categoryId,
    required this.caption,
  });

  final String categoryId;
  final String caption;
}

class _CommunityCategory {
  const _CommunityCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String slug;
  final int sortOrder;
}

class _CommunityVideo {
  const _CommunityVideo({
    required this.id,
    required this.userId,
    required this.storagePath,
    required this.status,
    required this.createdAt,
    required this.categoryName,
    this.categoryId,
    this.videoUrl,
    this.caption,
    this.rejectionReason,
  });

  final String id;
  final String userId;
  final String storagePath;

  final String? videoUrl;
  final String? caption;

  final String status;
  final String? rejectionReason;

  final String? categoryId;
  final String categoryName;

  final DateTime createdAt;
}
