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

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int? _cursor;
  String? _error;

  String _section = 'Tümü';

  static const List<String> _sections = [
    'Tümü',
    'TikTok',
    'YouTube',
    'Sizden Gelenler',
    'Sosyal Medya',
  ];

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

  Color get _primaryText =>
      Theme.of(context)
          .colorScheme
          .onSurface;

  Color get _secondaryText =>
      _primaryText.withOpacity(
        0.52,
      );

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
          ..addAll(page.videos);

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

  Future<void> _openVideo(
    VideoItem video,
  ) async {
    final opened =
        await _tiktok.open(
      video.tiktokUrl,
    );

    if (!mounted || opened) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Video açılamadı.',
        ),
      ),
    );
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

  void _openStory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (
        sheetContext,
      ) {
        return _StoryPreview(
          onAdvertise: () {
            Navigator.pop(
              sheetContext,
            );

            _showAdInfo();
          },
        );
      },
    );
  }

  void _showAdInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (
        context,
      ) {
        return SafeArea(
          child: Container(
            margin:
                const EdgeInsets.all(
              14,
            ),
            padding:
                const EdgeInsets.all(
              22,
            ),
            decoration:
                BoxDecoration(
              color: _surface,
              borderRadius:
                  BorderRadius
                      .circular(
                28,
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
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.gold
                            .withOpacity(
                      0.12,
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
                    size: 30,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                Text(
                  'Buraya reklam verebilirsiniz',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        _primaryText,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Reklam iletişimi için:',
                  style:
                      TextStyle(
                    color:
                        _secondaryText,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                const SelectableText(
                  'Abdinkokalp0102@gmail.com',
                  style:
                      TextStyle(
                    color:
                        AppColors.gold,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  'Sonraki adımda bu alanı tek dokunuşla e-posta uygulamasına yönlendireceğiz.',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        _secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSocialMedia() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (
        context,
      ) {
        return SafeArea(
          child: Container(
            margin:
                const EdgeInsets.all(
              14,
            ),
            padding:
                const EdgeInsets
                    .fromLTRB(
              18,
              10,
              18,
              22,
            ),
            decoration:
                BoxDecoration(
              color: _surface,
              borderRadius:
                  BorderRadius
                      .circular(
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
                  width: 42,
                  height: 4,
                  margin:
                      const EdgeInsets
                          .only(
                    bottom: 18,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Theme.of(
                      context,
                    ).dividerColor,
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                ),

                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
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
                            .share_rounded,
                        color:
                            AppColors.gold,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child: Text(
                        'Sosyal Medya Hesapları',
                        style:
                            TextStyle(
                          color:
                              _primaryText,
                          fontSize: 19,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                _SocialTile(
                  icon:
                      Icons.music_note_rounded,
                  title:
                      'TikTok',
                  subtitle:
                      '@b_music02',
                  onTap: () async {
                    await _tiktok.open(
                      'https://www.tiktok.com/@b_music02',
                    );
                  },
                ),

                const SizedBox(
                  height: 9,
                ),

                _SocialTile(
                  icon:
                      Icons.play_circle_fill_rounded,
                  title:
                      'YouTube',
                  subtitle:
                      'Hesap bağlantısı sonraki adımda eklenecek',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
                  },
                ),

                const SizedBox(
                  height: 9,
                ),

                _SocialTile(
                  icon:
                      Icons.alternate_email_rounded,
                  title:
                      'Diğer Hesaplar',
                  subtitle:
                      'Bağlantıları tek tek ekleyeceğiz',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _themeIcon(
    ThemeMode mode,
  ) {
    switch (mode) {
      case ThemeMode.dark:
        return Icons
            .dark_mode_rounded;

      case ThemeMode.light:
        return Icons
            .light_mode_rounded;

      case ThemeMode.system:
        return Icons
            .brightness_auto_rounded;
    }
  }

  void _openThemeSelector() {
    final controller =
        ThemeControllerScope.of(
      context,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (
        sheetContext,
      ) {
        return SafeArea(
          child: Container(
            margin:
                const EdgeInsets.all(
              14,
            ),
            padding:
                const EdgeInsets
                    .fromLTRB(
              18,
              12,
              18,
              22,
            ),
            decoration:
                BoxDecoration(
              color:
                  Theme.of(context)
                      .colorScheme
                      .surface,
              borderRadius:
                  BorderRadius
                      .circular(
                28,
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
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  'Görünüm',
                  style:
                      TextStyle(
                    color:
                        Theme.of(
                      context,
                    )
                            .colorScheme
                            .onSurface,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                _ThemeOption(
                  icon: Icons
                      .brightness_auto_rounded,
                  title:
                      'Otomatik',
                  selected:
                      controller
                              .themeMode ==
                          ThemeMode.system,
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

                const SizedBox(
                  height: 8,
                ),

                _ThemeOption(
                  icon: Icons
                      .dark_mode_rounded,
                  title:
                      'Gece',
                  selected:
                      controller
                              .themeMode ==
                          ThemeMode.dark,
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
                  icon: Icons
                      .light_mode_rounded,
                  title:
                      'Gündüz',
                  selected:
                      controller
                              .themeMode ==
                          ThemeMode.light,
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
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectSection(
    String section,
  ) {
    if (section ==
        'Sosyal Medya') {
      _showSocialMedia();
      return;
    }

    setState(() {
      _section = section;
    });
  }

  List<VideoItem>
      get _visibleVideos {
    if (_section == 'Tümü' ||
        _section == 'TikTok') {
      return _videos;
    }

    return const [];
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final controller =
        ThemeControllerScope.of(
      context,
    );

    final videos =
        _visibleVideos;

    return Scaffold(
      backgroundColor:
          _background,
      body: SafeArea(
        child:
            RefreshIndicator(
          color:
              AppColors.gold,
          onRefresh:
              _loadVideos,
          child: ListView(
            padding:
                const EdgeInsets
                    .fromLTRB(
              18,
              16,
              18,
              120,
            ),
            children: [
              _buildTopBar(
                controller,
              ),

              const SizedBox(
                height: 22,
              ),

              _buildStory(),

              const SizedBox(
                height: 24,
              ),

              _buildSectionTabs(),

              const SizedBox(
                height: 24,
              ),

              _buildSectionHeader(),

              const SizedBox(
                height: 14,
              ),

              if (_loading)
                const SizedBox(
                  height: 210,
                  child: Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          AppColors.gold,
                    ),
                  ),
                )
              else if (_error != null)
                _buildError()
              else if (videos.isEmpty)
                _buildEmpty()
              else
                _buildVideoRail(
                  videos,
                ),

              if (_section ==
                      'Tümü' ||
                  _section ==
                      'TikTok') ...[
                const SizedBox(
                  height: 28,
                ),

                _buildMoreRow(),

                const SizedBox(
                  height: 14,
                ),

                _buildSecondRail(
                  videos,
                ),
              ],

              const SizedBox(
                height: 28,
              ),

              _buildRequestButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    ThemeController controller,
  ) {
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'B_',
                  style:
                      TextStyle(
                    color:
                        _primaryText,
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing:
                        -1.5,
                  ),
                ),
                const TextSpan(
                  text:
                      'music02',
                  style:
                      TextStyle(
                    color:
                        AppColors.gold,
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing:
                        -1.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        _TopIconButton(
          icon:
              Icons.music_note_rounded,
          onTap:
              _openRequests,
          tooltip:
              'İstek',
        ),

        const SizedBox(
          width: 9,
        ),

        _TopIconButton(
          icon: _themeIcon(
            controller.themeMode,
          ),
          onTap:
              _openThemeSelector,
          tooltip:
              'Tema',
        ),
      ],
    );
  }

  Widget _buildStory() {
    return Row(
      children: [
        GestureDetector(
          onTap:
              _openStory,
          child: Column(
            children: [
              Container(
                width: 78,
                height: 78,
                padding:
                    const EdgeInsets.all(
                  3,
                ),
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  gradient:
                      LinearGradient(
                    colors: [
                      AppColors.gold,
                      AppColors.burgundy,
                      AppColors.gold,
                    ],
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.all(
                    3,
                  ),
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        _background,
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
                height: 7,
              ),

              Text(
                'Hikâye',
                style:
                    TextStyle(
                  color:
                      _primaryText,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 18,
        ),

        Expanded(
          child: GestureDetector(
            onTap:
                _openStory,
            child: Container(
              height: 78,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 16,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius
                        .circular(
                  22,
                ),
                gradient:
                    LinearGradient(
                  colors:
                      _isDark
                          ? [
                              const Color(
                                0xFF231118,
                              ),
                              const Color(
                                0xFF121212,
                              ),
                            ]
                          : [
                              const Color(
                                0xFFFFF8E8,
                              ),
                              Colors.white,
                            ],
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
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.gold
                              .withOpacity(
                        0.13,
                      ),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        const Icon(
                      Icons
                          .play_arrow_rounded,
                      color:
                          AppColors.gold,
                      size: 28,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'B_music02 Hikâyesi',
                          style:
                              TextStyle(
                            color:
                                _primaryText,
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          'Yeni içerikler ve reklam alanı',
                          style:
                              TextStyle(
                            color:
                                _secondaryText,
                            fontSize: 10,
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
      ],
    );
  }

  Widget _buildSectionTabs() {
    return SizedBox(
      height: 45,
      child:
          ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount:
            _sections.length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 8,
        ),
        itemBuilder:
            (
          context,
          index,
        ) {
          final item =
              _sections[index];

          final selected =
              _section == item;

          return GestureDetector(
            onTap: () {
              _selectSection(
                item,
              );
            },
            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 15,
              ),
              decoration:
                  BoxDecoration(
                color:
                    selected
                        ? AppColors.gold
                        : _surface,
                borderRadius:
                    BorderRadius
                        .circular(
                  22,
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
                    _sectionIcon(
                      item,
                    ),
                    size: 17,
                    color:
                        selected
                            ? Colors.black
                            : _secondaryText,
                  ),

                  const SizedBox(
                    width: 6,
                  ),

                  Text(
                    item,
                    style:
                        TextStyle(
                      color:
                          selected
                              ? Colors.black
                              : _primaryText,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _sectionIcon(
    String section,
  ) {
    switch (section) {
      case 'TikTok':
        return Icons
            .music_note_rounded;

      case 'YouTube':
        return Icons
            .play_circle_fill_rounded;

      case 'Sizden Gelenler':
        return Icons
            .video_library_rounded;

      case 'Sosyal Medya':
        return Icons
            .share_rounded;

      default:
        return Icons
            .apps_rounded;
    }
  }

  Widget _buildSectionHeader() {
    String title;

    switch (_section) {
      case 'TikTok':
        title =
            'TikTok Videoları';
        break;

      case 'YouTube':
        title =
            'YouTube Videoları';
        break;

      case 'Sizden Gelenler':
        title =
            'Sizden Gelenler';
        break;

      default:
        title =
            'Senin İçin';
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style:
                TextStyle(
              color:
                  _primaryText,
              fontSize: 22,
              fontWeight:
                  FontWeight.w900,
              letterSpacing:
                  -0.5,
            ),
          ),
        ),

        if (_section ==
                'Tümü' ||
            _section ==
                'TikTok')
          TextButton(
            onPressed:
                _loadMore,
            child:
                const Text(
              'Daha Fazla',
              style:
                  TextStyle(
                color:
                    AppColors.gold,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoRail(
    List<VideoItem> videos,
  ) {
    return SizedBox(
      height: 220,
      child:
          ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount:
            videos.length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 11,
        ),
        itemBuilder:
            (
          context,
          index,
        ) {
          final video =
              videos[index];

          return _HorizontalVideoCard(
            video: video,
            onTap: () {
              _openVideo(
                video,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMoreRow() {
    return Row(
      children: [
        Text(
          'Daha Fazlası',
          style:
              TextStyle(
            color:
                _primaryText,
            fontSize: 19,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const Spacer(),

        if (_loadingMore)
          const SizedBox(
            width: 18,
            height: 18,
            child:
                CircularProgressIndicator(
              color:
                  AppColors.gold,
              strokeWidth: 2,
            ),
          )
        else
          IconButton(
            onPressed:
                _loadMore,
            icon:
                const Icon(
              Icons
                  .arrow_forward_rounded,
              color:
                  AppColors.gold,
            ),
          ),
      ],
    );
  }

  Widget _buildSecondRail(
    List<VideoItem> videos,
  ) {
    final reversed =
        videos.reversed
            .toList();

    return SizedBox(
      height: 165,
      child:
          ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount:
            reversed.length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(
          width: 10,
        ),
        itemBuilder:
            (
          context,
          index,
        ) {
          final video =
              reversed[index];

          return _CompactVideoCard(
            video: video,
            onTap: () {
              _openVideo(
                video,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestButton() {
    return Align(
      alignment:
          Alignment.centerRight,
      child: Material(
        color:
            Colors.transparent,
        child: InkWell(
          onTap:
              _openRequests,
          borderRadius:
              BorderRadius
                  .circular(
            40,
          ),
          child: Ink(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 14,
              vertical: 10,
            ),
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
                40,
              ),
              border:
                  Border.all(
                color:
                    AppColors.gold
                        .withOpacity(
                  0.28,
                ),
              ),
            ),
            child:
                const Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  Icons
                      .music_note_rounded,
                  color:
                      AppColors.gold,
                  size: 18,
                ),
                SizedBox(
                  width: 6,
                ),
                Text(
                  'İstek',
                  style:
                      TextStyle(
                    color:
                        AppColors.gold,
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      height: 190,
      alignment:
          Alignment.center,
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons
                .wifi_off_rounded,
            color:
                _secondaryText,
            size: 42,
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            _error!,
            style:
                TextStyle(
              color:
                  _secondaryText,
            ),
          ),
          TextButton(
            onPressed:
                _loadVideos,
            child:
                const Text(
              'Tekrar Dene',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    String text;

    if (_section ==
        'YouTube') {
      text =
          'YouTube bağlantısını sonraki adımda ekleyeceğiz.';
    } else if (_section ==
        'Sizden Gelenler') {
      text =
          'Topluluk videolarını sonraki adımda buraya bağlayacağız.';
    } else {
      text =
          'Henüz video yok.';
    }

    return Container(
      height: 180,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        color:
            _surface,
        borderRadius:
            BorderRadius
                .circular(
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
      child: Center(
        child: Text(
          text,
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            color:
                _secondaryText,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _HorizontalVideoCard
    extends StatelessWidget {
  const _HorizontalVideoCard({
    required this.video,
    required this.onTap,
  });

  final VideoItem video;
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
      child: SizedBox(
        width: 142,
        child: ClipRRect(
          borderRadius:
              BorderRadius
                  .circular(
            20,
          ),
          child: Stack(
            fit:
                StackFit.expand,
            children: [
              if (thumbnail !=
                      null &&
                  thumbnail
                      .isNotEmpty)
                Image.network(
                  thumbnail,
                  fit:
                      BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return _fallback();
                  },
                )
              else
                _fallback(),

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

              const Center(
                child:
                    CircleAvatar(
                  radius: 23,
                  backgroundColor:
                      Color(
                    0x88000000,
                  ),
                  child: Icon(
                    Icons
                        .play_arrow_rounded,
                    color:
                        Colors.white,
                    size: 30,
                  ),
                ),
              ),

              Positioned(
                right: 8,
                bottom: 8,
                child:
                    Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black
                            .withOpacity(
                      0.72,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                  ),
                  child:
                      const Text(
                    'TikTok',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color:
          const Color(
        0xFF1A1014,
      ),
      child:
          const Center(
        child: Icon(
          Icons
              .music_note_rounded,
          color:
              AppColors.gold,
          size: 45,
        ),
      ),
    );
  }
}

class _CompactVideoCard
    extends StatelessWidget {
  const _CompactVideoCard({
    required this.video,
    required this.onTap,
  });

  final VideoItem video;
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
      child: SizedBox(
        width: 108,
        child: ClipRRect(
          borderRadius:
              BorderRadius
                  .circular(
            17,
          ),
          child: Stack(
            fit:
                StackFit.expand,
            children: [
              if (thumbnail !=
                      null &&
                  thumbnail
                      .isNotEmpty)
                Image.network(
                  thumbnail,
                  fit:
                      BoxFit.cover,
                )
              else
                Container(
                  color:
                      const Color(
                    0xFF171014,
                  ),
                ),

              const Center(
                child:
                    CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      Color(
                    0x77000000,
                  ),
                  child: Icon(
                    Icons
                        .play_arrow_rounded,
                    color:
                        Colors.white,
                    size: 24,
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

class _TopIconButton
    extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Tooltip(
      message:
          tooltip,
      child: Material(
        color:
            Colors.transparent,
        child: InkWell(
          onTap:
              onTap,
          customBorder:
              const CircleBorder(),
          child: Ink(
            width: 44,
            height: 44,
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
                    AppColors.gold
                        .withOpacity(
                  0.18,
                ),
              ),
            ),
            child: Icon(
              icon,
              color:
                  AppColors.gold,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialTile
    extends StatelessWidget {
  const _SocialTile({
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
  Widget build(
    BuildContext context,
  ) {
    final color =
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
            BorderRadius
                .circular(
          18,
        ),
        child: Ink(
          padding:
              const EdgeInsets
                  .all(
            13,
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
              18,
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
                width: 43,
                height: 43,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.gold
                          .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
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
                      title,
                      style:
                          TextStyle(
                        color:
                            color,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      subtitle,
                      style:
                          TextStyle(
                        color:
                            color.withOpacity(
                          0.45,
                        ),
                        fontSize:
                            10,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons
                    .open_in_new_rounded,
                color:
                    color.withOpacity(
                  0.35,
                ),
                size: 18,
              ),
            ],
          ),
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
    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius
                .circular(
          18,
        ),
        child: Ink(
          padding:
              const EdgeInsets
                  .all(
            13,
          ),
          decoration:
              BoxDecoration(
            color:
                selected
                    ? AppColors.gold
                        .withOpacity(
                      0.12,
                    )
                    : Theme.of(
                        context,
                      )
                          .colorScheme
                          .surface,
            borderRadius:
                BorderRadius
                    .circular(
              18,
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
                icon,
                color:
                    AppColors.gold,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Text(
                  title,
                  style:
                      TextStyle(
                    color:
                        Theme.of(
                      context,
                    )
                            .colorScheme
                            .onSurface,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              if (selected)
                const Icon(
                  Icons
                      .check_circle_rounded,
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

class _StoryPreview
    extends StatelessWidget {
  const _StoryPreview({
    required this.onAdvertise,
  });

  final VoidCallback onAdvertise;

  @override
  Widget build(
    BuildContext context,
  ) {
    return SafeArea(
      child: Container(
        margin:
            const EdgeInsets.all(
          10,
        ),
        height:
            MediaQuery.of(context)
                    .size
                    .height *
                0.78,
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius
                  .circular(
            30,
          ),
          gradient:
              const LinearGradient(
            begin:
                Alignment.topCenter,
            end:
                Alignment.bottomCenter,
            colors: [
              Color(
                0xFF481126,
              ),
              Color(
                0xFF160D11,
              ),
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child:
                  ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(
                  20,
                ),
                child:
                    const LinearProgressIndicator(
                  value: 1,
                  minHeight: 3,
                  backgroundColor:
                      Colors.white24,
                  valueColor:
                      AlwaysStoppedAnimation(
                    AppColors.gold,
                  ),
                ),
              ),
            ),

            Center(
              child: Padding(
                padding:
                    const EdgeInsets
                        .all(
                  28,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Container(
                      width: 105,
                      height: 105,
                      padding:
                          const EdgeInsets
                              .all(
                        4,
                      ),
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        border:
                            Border.all(
                          color:
                              AppColors.gold,
                          width: 2,
                        ),
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

                    const SizedBox(
                      height: 22,
                    ),

                    const Text(
                      'B_music02',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 31,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    const Text(
                      'TikTok’ta müziğin yeni adresini keşfet.',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(
                      height: 30,
                    ),

                    GestureDetector(
                      onTap:
                          onAdvertise,
                      child:
                          Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.gold,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            30,
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
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 25,
              right: 18,
              child:
                  IconButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  );
                },
                icon:
                    const Icon(
                  Icons
                      .close_rounded,
                  color:
                      Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
