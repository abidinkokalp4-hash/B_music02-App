import 'package:flutter/material.dart';

import '../../core/services/tiktok_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/video_item.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  final _tiktok = const TikTokService();
  final _search = TextEditingController();
  final _scrollController =
      ScrollController();

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

    _scrollController.addListener(
      _onScroll,
    );

    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _search.dispose();

    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position =
        _scrollController.position;

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
      final page =
          await _tiktok.fetchVideos();

      if (!mounted) return;

      setState(() {
        _videos
          ..clear()
          ..addAll(page.videos);

        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initialLoading = false;
        _error =
            'TikTok videoları yüklenemedi.';
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
      final page =
          await _tiktok.fetchVideos(
        cursor: _cursor,
      );

      if (!mounted) return;

      setState(() {
        for (final video in page.videos) {
          final exists = _videos.any(
            (item) =>
                item.id == video.id,
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
    final q =
        _search.text.trim().toLowerCase();

    return _videos.where((video) {
      final categoryOk =
          _category == 'Tümü' ||
              video.category == _category;

      final searchOk =
          q.isEmpty ||
              video.title
                  .toLowerCase()
                  .contains(q) ||
              video.artist
                  .toLowerCase()
                  .contains(q);

      return categoryOk && searchOk;
    }).toList();
  }

  Future<void> _open(
    VideoItem video,
  ) async {
    final ok =
        await _tiktok.open(
      video.tiktokUrl,
    );

    if (!mounted || ok) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
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
        _videos.isNotEmpty
            ? _videos.first
            : null;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: CustomScrollView(
          controller: _scrollController,
          physics:
              const AlwaysScrollableScrollPhysics(),
          cacheExtent: 600,
          slivers: [
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                0,
              ),
              sliver: SliverList.list(
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            AppColors.burgundy,
                        child: Icon(
                          Icons
                              .graphic_eq_rounded,
                          color:
                              AppColors.gold,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'B_music02',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w900,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              'Güneydoğu müzik topluluğu',
                              style: TextStyle(
                                color: AppColors
                                    .textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor:
                            AppColors.surface,
                        child: Icon(
                          Icons
                              .notifications_none_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  const Text(
                    'Müziğin kalbine\nyolculuk.',
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.05,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  TextField(
                    controller: _search,
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Şarkı, sanatçı veya video ara',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  if (featured != null)
                    GlassCard(
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
                                    AppColors.gold,
                              ),
                              SizedBox(
                                width: 8,
                              ),
                              Text(
                                'En Yeni TikTok Videosu',
                                style:
                                    TextStyle(
                                  color:
                                      AppColors.gold,
                                  fontWeight:
                                      FontWeight
                                          .w800,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          Text(
                            featured.title,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            featured.artist,
                            style:
                                const TextStyle(
                              color: AppColors
                                  .textSecondary,
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          ElevatedButton.icon(
                            onPressed: () {
                              _open(featured);
                            },
                            icon: const Icon(
                              Icons
                                  .play_arrow_rounded,
                            ),
                            label: const Text(
                              'TikTok’ta İzle',
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (featured != null)
                    const SizedBox(
                      height: 18,
                    ),

                  SizedBox(
                    height: 42,
                    child:
                        ListView.separated(
                      scrollDirection:
                          Axis.horizontal,
                      itemCount:
                          _categories.length,
                      separatorBuilder:
                          (_, __) =>
                              const SizedBox(
                        width: 8,
                      ),
                      itemBuilder:
                          (context, i) {
                        final item =
                            _categories[i];

                        return ChoiceChip(
                          label:
                              Text(item),
                          selected:
                              _category ==
                                  item,
                          onSelected: (_) {
                            setState(() {
                              _category =
                                  item;
                            });
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'TikTok Videoları',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ),
                      Text(
                        '${_videos.length}',
                        style:
                            const TextStyle(
                          color: AppColors
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 12,
                  ),
                ],
              ),
            ),

            if (_initialLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(
                        height: 16,
                      ),
                      ElevatedButton(
                        onPressed:
                            _loadFirstPage,
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
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  20,
                ),
                sliver: SliverGrid(
                  delegate:
                      SliverChildBuilderDelegate(
                    (context, i) =>
                        VideoCard(
                      video:
                          videos[i],
                      onTap: () {
                        _open(
                          videos[i],
                        );
                      },
                    ),
                    childCount:
                        videos.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio:
                        .72,
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 120,
                  top: 12,
                ),
                child: Center(
                  child: _loadingMore
                      ? const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(
                              height: 10,
                            ),
                            Text(
                              '20 video daha yükleniyor...',
                            ),
                          ],
                        )
                      : !_hasMore &&
                              _videos
                                  .isNotEmpty
                          ? const Text(
                              'Tüm videolar yüklendi.',
                              style:
                                  TextStyle(
                                color: AppColors
                                    .textSecondary,
                              ),
                            )
                          : const SizedBox
                              .shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
