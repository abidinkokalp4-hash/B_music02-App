import 'package:flutter/material.dart';

import '../../core/services/tiktok_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/video_item.dart';
import '../../widgets/video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tiktok = const TikTokService();
  final _search = TextEditingController();
  final _scrollController = ScrollController();

  final List<VideoItem> _videos = [];

  String _category = 'Tümü';

  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int? _cursor;
  String? _error;

  static const _categories = [
    'Tümü',
    'TikTok',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.pixels >=
        position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _initialLoading = true;
      _loadingMore = false;
      _error = null;
      _cursor = null;
      _hasMore = true;
    });

    try {
      final page = await _tiktok.fetchVideos();

      if (!mounted) return;

      setState(() {
        _videos
          ..clear()
          ..addAll(page.videos);

        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _initialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _initialLoading = false;
        _error = 'TikTok videoları yüklenemedi.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_initialLoading ||
        _loadingMore ||
        !_hasMore ||
        _cursor == null) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final page = await _tiktok.fetchVideos(
        cursor: _cursor,
      );

      if (!mounted) return;

      setState(() {
        for (final video in page.videos) {
          final exists = _videos.any(
            (item) => item.id == video.id,
          );

          if (!exists) {
            _videos.add(video);
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

  List<VideoItem> get _filtered {
    final q = _search.text.trim().toLowerCase();

    return _videos.where((video) {
      final categoryOk =
          _category == 'Tümü' ||
          video.category == _category;

      final searchOk =
          q.isEmpty ||
          video.title.toLowerCase().contains(q) ||
          video.artist.toLowerCase().contains(q);

      return categoryOk && searchOk;
    }).toList();
  }

  Future<void> _open(VideoItem video) async {
    final ok = await _tiktok.open(
      video.tiktokUrl,
    );

    if (!mounted || ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'TikTok bağlantısı açılamadı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = _filtered;

    final VideoItem? featured =
        _videos.isNotEmpty ? _videos.first : null;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: CustomScrollView(
          controller: _scrollController,
          physics:
              const AlwaysScrollableScrollPhysics(),
          cacheExtent: 700,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                0,
              ),
              sliver: SliverList.list(
                children: [
                  _buildHeader(),

                  const SizedBox(height: 26),

                  const Text(
                    'Müziğin kalbine\nyolculuk',
                    style: TextStyle(
                      fontSize: 40,
                      height: 0.98,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Güneydoğu’nun ezgileri, kültürü ve sesi.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 22),

                  _buildSearch(),

                  const SizedBox(height: 20),

                  if (featured != null)
                    _buildFeatured(featured),

                  if (featured != null)
                    const SizedBox(height: 20),

                  _buildCategorySelector(),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Videolar',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.gold
                                .withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          '${videos.length}',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),

            if (_initialLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 46,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFirstPage,
                        child: const Text(
                          'Tekrar Dene',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (videos.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Video bulunamadı.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  20,
                ),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final video = videos[i];

                      return VideoCard(
                        video: video,
                        onTap: () {
                          _open(video);
                        },
                      );
                    },
                    childCount: videos.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 120,
                  top: 16,
                ),
                child: Center(
                  child: _loadingMore
                      ? const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text(
                              'Yeni videolar yükleniyor...',
                              style: TextStyle(
                                color:
                                    AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : !_hasMore &&
                              _videos.isNotEmpty
                          ? const Text(
                              'Tüm videolar yüklendi.',
                              style: TextStyle(
                                color:
                                    AppColors.textSecondary,
                              ),
                            )
                          : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.burgundy,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.burgundy
                    .withOpacity(0.35),
                blurRadius: 22,
              ),
            ],
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            color: AppColors.gold,
            size: 30,
          ),
        ),

        const SizedBox(width: 13),

        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'B_music02',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Güneydoğu müzik topluluğu',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.textPrimary,
              ),
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.gold.withOpacity(0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _search,
        onChanged: (_) {
          setState(() {});
        },
        decoration: const InputDecoration(
          hintText:
              'Şarkı, sanatçı veya video ara',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.gold,
          ),
          suffixIcon: Icon(
            Icons.tune_rounded,
            color: AppColors.gold,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatured(VideoItem video) {
    final thumbnail = video.thumbnailUrl;

    return GestureDetector(
      onTap: () {
        _open(video);
      },
      child: Container(
        height: 245,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: AppColors.gold.withOpacity(0.55),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  AppColors.gold.withOpacity(0.08),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnail != null &&
                  thumbnail.isNotEmpty)
                Image.network(
                  thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return _featuredFallback();
                  },
                )
              else
                _featuredFallback(),

              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Color(0x15000000),
                      Color(0x99000000),
                      Color(0xEE000000),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 20,
                right: 20,
                top: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EN YENİ VİDEO',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const Spacer(),

                    Text(
                      video.title,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      video.artist,
                      style: const TextStyle(
                        color: Color(0xFFD9D1C8),
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius:
                            BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 22,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Videoyu İzle',
                            style: TextStyle(
                              color: Colors.black,
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
      ),
    );
  }

  Widget _featuredFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.burgundy,
            Color(0xFF160F12),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.gold,
          size: 78,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Row(
        children: _categories.map((item) {
          final selected = _category == item;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _category = item;
                });
              },
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.gold
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(24),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: selected
                        ? Colors.black
                        : AppColors.textSecondary,
                    fontWeight: selected
                        ? FontWeight.w900
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
