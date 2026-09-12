import 'package:flutter/material.dart';

import '../../core/services/tiktok_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/video_item.dart';
import '../requests/requests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  final TikTokService _tiktok =
      const TikTokService();

  final List<VideoItem> _videos = [];

  int _selectedSection = 0;

  int? _cursor;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  String? _error;

  static const List<_HomeSection>
      _sections = [
    _HomeSection(
      title: 'Tümü',
      icon: Icons.apps_rounded,
    ),
    _HomeSection(
      title: 'TikTok',
      icon: Icons.music_note_rounded,
    ),
    _HomeSection(
      title: 'YouTube',
      icon: Icons.play_circle_fill_rounded,
    ),
    _HomeSection(
      title: 'Sizden Gelenler',
      icon: Icons.people_alt_rounded,
    ),
    _HomeSection(
      title: 'Sosyal Medya',
      icon: Icons.public_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _loadVideos();
  }

  Future<void> _loadVideos() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _cursor = null;
      _hasMore = true;
    });

    try {
      final page =
          await _tiktok.fetchVideos();

      if (!mounted) return;

      setState(() {
        _videos
          ..clear()
          ..addAll(
            page.videos,
          );

        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Videolar yüklenemedi.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore ||
        !_hasMore ||
        _cursor == null) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final page =
          await _tiktok.fetchVideos(
        cursor: _cursor,
      );

      if (!mounted) return;

      setState(() {
        for (final video
            in page.videos) {
          final exists =
              _videos.any(
            (item) =>
                item.id ==
                video.id,
          );

          if (!exists) {
            _videos.add(
              video,
            );
          }
        }

        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingMore = false;
      });
    }
  }

  void _openRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const RequestsScreen(),
      ),
    );
  }

  Future<void> _openVideo(
    VideoItem video,
  ) async {
    await _tiktok.open(
      video.tiktokUrl,
    );
  }

  void _showThemeSelector() {
    final controller =
        ThemeControllerScope.of(
      context,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (
        sheetContext,
      ) {
        final textColor =
            Theme.of(
          sheetContext,
        ).colorScheme.onSurface;

        final surface =
            Theme.of(
          sheetContext,
        ).colorScheme.surface;

        return SafeArea(
          top: false,
          child: Container(
            margin:
                const EdgeInsets.all(
              12,
            ),
            padding:
                const EdgeInsets.all(
              18,
            ),
            decoration:
                BoxDecoration(
              color:
                  surface,
              borderRadius:
                  BorderRadius.circular(
                28,
              ),
              border:
                  Border.all(
                color:
                    AppColors.gold
                        .withOpacity(
                  0.20,
                ),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        textColor
                            .withOpacity(
                      0.15,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                Text(
                  'Görünüm',
                  style:
                      TextStyle(
                    color:
                        textColor,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                _ThemeOption(
                  icon:
                      Icons.dark_mode_rounded,
                  title:
                      'Gece',
                  selected:
                      controller.isDark,
                  onTap: () async {
                    await controller
                        .setDark();

                    if (sheetContext
                        .mounted) {
                      Navigator.pop(
                        sheetContext,
                      );
                    }
                  },
                ),

                const SizedBox(
                  height: 8,
                ),

                _ThemeOption(
                  icon:
                      Icons.light_mode_rounded,
                  title:
                      'Gündüz',
                  selected:
                      controller.isLight,
                  onTap: () async {
                    await controller
                        .setLight();

                    if (sheetContext
                        .mounted) {
                      Navigator.pop(
                        sheetContext,
                      );
                    }
                  },
                ),

                const SizedBox(
                  height: 8,
                ),

                _ThemeOption(
                  icon:
                      Icons
                          .brightness_auto_rounded,
                  title:
                      'Otomatik',
                  selected:
                      controller.isSystem,
                  onTap: () async {
                    await controller
                        .setSystem();

                    if (sheetContext
                        .mounted) {
                      Navigator.pop(
                        sheetContext,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openStory() {
    showDialog<void>(
      context: context,
      barrierColor:
          Colors.black87,
      builder: (
        dialogContext,
      ) {
        return Dialog(
          backgroundColor:
              Colors.transparent,
          insetPadding:
              const EdgeInsets.all(
            18,
          ),
          child:
              _StoryPreview(
            onClose: () {
              Navigator.pop(
                dialogContext,
              );
            },
          ),
        );
      },
    );
  }

  void _openSocialAccounts() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (
        sheetContext,
      ) {
        final surface =
            Theme.of(
          sheetContext,
        ).colorScheme.surface;

        final text =
            Theme.of(
          sheetContext,
        ).colorScheme.onSurface;

        return SafeArea(
          top: false,
          child: Container(
            margin:
                const EdgeInsets.all(
              12,
            ),
            padding:
                const EdgeInsets.all(
              18,
            ),
            decoration:
                BoxDecoration(
              color:
                  surface,
              borderRadius:
                  BorderRadius.circular(
                28,
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  'Sosyal Medya',
                  style:
                      TextStyle(
                    color:
                        text,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                ListTile(
                  leading:
                      const CircleAvatar(
                    backgroundColor:
                        Colors.black,
                    child:
                        Icon(
                      Icons
                          .music_note_rounded,
                      color:
                          Colors.white,
                    ),
                  ),
                  title:
                      const Text(
                    'TikTok',
                  ),
                  subtitle:
                      const Text(
                    '@b_music02',
                  ),
                  trailing:
                      const Icon(
                    Icons
                        .open_in_new_rounded,
                  ),
                  onTap: () async {
                    Navigator.pop(
                      sheetContext,
                    );

                    await _tiktok.open(
                      'https://www.tiktok.com/@b_music02',
                    );
                  },
                ),

                ListTile(
                  leading:
                      const CircleAvatar(
                    child:
                        Icon(
                      Icons
                          .play_arrow_rounded,
                    ),
                  ),
                  title:
                      const Text(
                    'YouTube',
                  ),
                  subtitle:
                      const Text(
                    'Yakında bağlanacak',
                  ),
                ),

                ListTile(
                  leading:
                      const CircleAvatar(
                    child:
                        Icon(
                      Icons
                          .share_rounded,
                    ),
                  ),
                  title:
                      const Text(
                    'Diğer Hesaplar',
                  ),
                  subtitle:
                      const Text(
                    'Yakında eklenecek',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final text =
        Theme.of(context)
            .colorScheme
            .onSurface;

    final muted =
        text.withOpacity(
      0.45,
    );

    return Scaffold(
      body: SafeArea(
        child:
            RefreshIndicator(
          color:
              AppColors.gold,
          onRefresh:
              _loadVideos,
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
                    15,
                    18,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            RichText(
                          text:
                              TextSpan(
                            style:
                                TextStyle(
                              fontSize:
                                  27,
                              fontWeight:
                                  FontWeight
                                      .w900,
                              letterSpacing:
                                  -1,
                              color:
                                  text,
                            ),
                            children:
                                const [
                              TextSpan(
                                text:
                                    'B_',
                                style:
                                    TextStyle(
                                  color:
                                      AppColors
                                          .gold,
                                ),
                              ),
                              TextSpan(
                                text:
                                    'music02',
                              ),
                            ],
                          ),
                        ),
                      ),

                      _TopButton(
                        icon:
                            Icons
                                .music_note_rounded,
                        onTap:
                            _openRequests,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      _TopButton(
                        icon:
                            Icons
                                .contrast_rounded,
                        onTap:
                            _showThemeSelector,
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    18,
                    20,
                    18,
                    0,
                  ),
                  child:
                      GestureDetector(
                    onTap:
                        _openStory,
                    child:
                        Row(
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          padding:
                              const EdgeInsets.all(
                            3,
                          ),
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            gradient:
                                const LinearGradient(
                              colors: [
                                AppColors.gold,
                                AppColors
                                    .burgundy,
                              ],
                            ),
                          ),
                          child:
                              Container(
                            padding:
                                const EdgeInsets.all(
                              3,
                            ),
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape.circle,
                              color:
                                  Theme.of(
                                context,
                              )
                                      .scaffoldBackgroundColor,
                            ),
                            child:
                                ClipOval(
                              child:
                                  Image.asset(
                                'assets/images/b_music02_logo.png',
                                fit:
                                    BoxFit.cover,
                              ),
                            ),
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
                                'B_music02 Hikâyesi',
                                style:
                                    TextStyle(
                                  color:
                                      text,
                                  fontSize:
                                      15,
                                  fontWeight:
                                      FontWeight
                                          .w900,
                                ),
                              ),

                              const SizedBox(
                                height: 3,
                              ),

                              Text(
                                'TikTok • Reklam • Duyurular',
                                style:
                                    TextStyle(
                                  color:
                                      muted,
                                  fontSize:
                                      10,
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
              ),

              SliverToBoxAdapter(
                child:
                    _buildSections(),
              ),

              if (_selectedSection ==
                  4)
                SliverToBoxAdapter(
                  child:
                      _SocialMediaCard(
                    onTap:
                        _openSocialAccounts,
                  ),
                )
              else if (_selectedSection ==
                      2 ||
                  _selectedSection ==
                      3)
                SliverToBoxAdapter(
                  child:
                      _ComingSoon(
                    title:
                        _selectedSection ==
                                2
                            ? 'YouTube videoları'
                            : 'Sizden Gelenler',
                    subtitle:
                        _selectedSection ==
                                2
                            ? 'YouTube bağlantısı sonraki aşamada eklenecek.'
                            : 'Onaylanan topluluk videoları burada gösterilecek.',
                  ),
                )
              else if (_loading)
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
              else if (_error !=
                  null)
                SliverFillRemaining(
                  hasScrollBody:
                      false,
                  child:
                      Center(
                    child:
                        Text(
                      _error!,
                    ),
                  ),
                )
              else if (_videos
                  .isEmpty)
                const SliverFillRemaining(
                  hasScrollBody:
                      false,
                  child:
                      Center(
                    child:
                        Text(
                      'Video bulunamadı.',
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child:
                      _VideoRail(
                    title:
                        'B_music02 Videoları',
                    videos:
                        _videos,
                    onTap:
                        _openVideo,
                  ),
                ),

                SliverToBoxAdapter(
                  child:
                      _VideoRail(
                    title:
                        'Tekrar İzle',
                    videos:
                        _videos
                            .reversed
                            .toList(),
                    onTap:
                        _openVideo,
                    compact:
                        true,
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      18,
                      4,
                      18,
                      0,
                    ),
                    child:
                        SizedBox(
                      height: 48,
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _loadingMore ||
                                    !_hasMore
                                ? null
                                : _loadMore,
                        icon:
                            _loadingMore
                                ? const SizedBox(
                                    width:
                                        16,
                                    height:
                                        16,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .expand_more_rounded,
                                  ),
                        label:
                            Text(
                          _hasMore
                              ? 'Daha Fazlası'
                              : 'Tüm videolar yüklendi',
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(
                child:
                    SizedBox(
                  height: 125,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSections() {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        20,
        0,
        18,
      ),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection:
              Axis.horizontal,
          padding:
              const EdgeInsets.only(
            right: 18,
          ),
          itemCount:
              _sections.length,
          separatorBuilder:
              (
            context,
            index,
          ) =>
                  const SizedBox(
            width: 8,
          ),
          itemBuilder:
              (
            context,
            index,
          ) {
            final section =
                _sections[index];

            final selected =
                index ==
                    _selectedSection;

            return GestureDetector(
              onTap: () {
                if (index ==
                    4) {
                  _openSocialAccounts();
                }

                setState(() {
                  _selectedSection =
                      index;
                });
              },
              child:
                  AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds:
                      180,
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
                      BorderRadius
                          .circular(
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
                child:
                    Row(
                  children: [
                    Icon(
                      section.icon,
                      size: 16,
                      color:
                          selected
                              ? Colors.black
                              : AppColors
                                  .gold,
                    ),

                    const SizedBox(
                      width: 6,
                    ),

                    Text(
                      section.title,
                      style:
                          TextStyle(
                        color:
                            selected
                                ? Colors.black
                                : Theme.of(
                                    context,
                                  )
                                    .colorScheme
                                    .onSurface,
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VideoRail
    extends StatelessWidget {
  const _VideoRail({
    required this.title,
    required this.videos,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final List<VideoItem> videos;
  final ValueChanged<VideoItem>
      onTap;
  final bool compact;

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
          const EdgeInsets.only(
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 18,
            ),
            child: Text(
              title,
              style:
                  TextStyle(
                color:
                    text,
                fontSize: 17,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(
            height: 11,
          ),

          SizedBox(
            height:
                compact
                    ? 170
                    : 215,
            child:
                ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 18,
              ),
              itemCount:
                  videos.length,
              separatorBuilder:
                  (
                context,
                index,
              ) =>
                      const SizedBox(
                width: 10,
              ),
              itemBuilder:
                  (
                context,
                index,
              ) {
                final video =
                    videos[index];

                return _VideoCard(
                  video:
                      video,
                  compact:
                      compact,
                  onTap: () {
                    onTap(
                      video,
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

class _VideoCard
    extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.compact,
    required this.onTap,
  });

  final VideoItem video;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final thumbnail =
        video.thumbnailUrl;

    return GestureDetector(
      onTap:
          onTap,
      child:
          ClipRRect(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: SizedBox(
          width:
              compact
                  ? 118
                  : 142,
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

              if (thumbnail !=
                      null &&
                  thumbnail
                      .trim()
                      .isNotEmpty)
                Image.network(
                  thumbnail,
                  fit:
                      BoxFit.cover,
                  errorBuilder:
                      (
                    context,
                    error,
                    stackTrace,
                  ) =>
                          const Center(
                    child: Icon(
                      Icons
                          .music_video_rounded,
                      color:
                          AppColors.gold,
                      size: 36,
                    ),
                  ),
                )
              else
                const Center(
                  child: Icon(
                    Icons
                        .music_video_rounded,
                    color:
                        AppColors.gold,
                    size: 36,
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
                        Alignment
                            .bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(
                        0x22000000,
                      ),
                      Color(
                        0x99000000,
                      ),
                    ],
                  ),
                ),
              ),

              Center(
                child:
                    Container(
                  width:
                      compact
                          ? 40
                          : 46,
                  height:
                      compact
                          ? 40
                          : 46,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        Colors.black
                            .withOpacity(
                      0.58,
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryPreview
    extends StatelessWidget {
  const _StoryPreview({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(
    BuildContext context,
  ) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child:
          ClipRRect(
        borderRadius:
            BorderRadius.circular(
          28,
        ),
        child: Container(
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
                  0xFF0B0B0B,
                ),
                Color(
                  0xFF321622,
                ),
                Color(
                  0xFF0B0B0B,
                ),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 14,
                left: 14,
                right: 55,
                child:
                    const LinearProgressIndicator(
                  value: 1,
                  minHeight: 3,
                  color:
                      Colors.white,
                  backgroundColor:
                      Colors.white24,
                ),
              ),

              Positioned(
                top: 8,
                right: 8,
                child:
                    IconButton(
                  onPressed:
                      onClose,
                  icon:
                      const Icon(
                    Icons
                        .close_rounded,
                    color:
                        Colors.white,
                  ),
                ),
              ),

              Center(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(
                    26,
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/b_music02_logo.png',
                        width: 105,
                        height: 105,
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      const Text(
                        'B_music02',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              28,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'TikTok hesabımızdaki yeni müzikleri takip edin.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              Colors.white70,
                          height:
                              1.4,
                        ),
                      ),

                      const SizedBox(
                        height: 25,
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.gold,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),
                        ),
                        child:
                            const Text(
                          'Buraya reklam verebilirsiniz',
                          style:
                              TextStyle(
                            color:
                                Colors.black,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      const Text(
                        'Abdinkokalp0102@gmail.com',
                        style:
                            TextStyle(
                          color:
                              Colors.white54,
                          fontSize:
                              10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopButton
    extends StatelessWidget {
  const _TopButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap:
          onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              Theme.of(
            context,
          )
                  .colorScheme
                  .surface,
          border:
              Border.all(
            color:
                Theme.of(
              context,
            ).dividerColor,
          ),
        ),
        child:
            Icon(
          icon,
          color:
              AppColors.gold,
          size: 21,
        ),
      ),
    );
  }
}

class _ThemeOption
    extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      tileColor:
          selected
              ? AppColors.gold
                  .withOpacity(
                  0.12,
                )
              : null,
      leading:
          Icon(
        icon,
        color:
            selected
                ? AppColors.gold
                : null,
      ),
      title:
          Text(
        title,
        style:
            TextStyle(
          fontWeight:
              selected
                  ? FontWeight.w900
                  : FontWeight.w600,
        ),
      ),
      trailing:
          selected
              ? const Icon(
                  Icons
                      .check_circle_rounded,
                  color:
                      AppColors.gold,
                )
              : null,
      onTap:
          onTap,
    );
  }
}

class _SocialMediaCard
    extends StatelessWidget {
  const _SocialMediaCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        10,
        18,
        0,
      ),
      child:
          GestureDetector(
        onTap:
            onTap,
        child: Container(
          padding:
              const EdgeInsets.all(
            22,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              25,
            ),
            color:
                Theme.of(
              context,
            )
                    .colorScheme
                    .surface,
            border:
                Border.all(
              color:
                  AppColors.gold
                      .withOpacity(
                0.2,
              ),
            ),
          ),
          child:
              const Row(
            children: [
              Icon(
                Icons
                    .public_rounded,
                color:
                    AppColors.gold,
                size: 34,
              ),

              SizedBox(
                width: 15,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'B_music02 Sosyal Medya',
                      style:
                          TextStyle(
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    SizedBox(
                      height: 4,
                    ),

                    Text(
                      'Hesaplarımızı görüntülemek için dokunun.',
                      style:
                          TextStyle(
                        fontSize:
                            10,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
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
}

class _ComingSoon
    extends StatelessWidget {
  const _ComingSoon({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.all(
        30,
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  AppColors.gold
                      .withOpacity(
                0.1,
              ),
            ),
            child:
                const Icon(
              Icons
                  .video_collection_rounded,
              color:
                  AppColors.gold,
              size: 38,
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
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
          ),
        ],
      ),
    );
  }
}

class _HomeSection {
  const _HomeSection({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;
}
