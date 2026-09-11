import 'package:flutter/material.dart';

import '../../core/services/tiktok_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/video_item.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tiktok = const TikTokService();
  final _search = TextEditingController();

  final List<VideoItem> _videos = [];

  String _category = 'Tümü';
  bool _loading = true;
  String? _error;

  static const _categories = [
    'Tümü',
    'TikTok',
  ];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final videos = await _tiktok.fetchVideos();

      if (!mounted) return;

      setState(() {
        _videos
          ..clear()
          ..addAll(videos);

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'TikTok videoları yüklenemedi.';
      });
    }
  }

  List<VideoItem> get _filtered {
    final q = _search.text.trim().toLowerCase();

    return _videos.where((video) {
      final categoryOk =
          _category == 'Tümü' || video.category == _category;

      final searchOk =
          q.isEmpty ||
          video.title.toLowerCase().contains(q) ||
          video.artist.toLowerCase().contains(q);

      return categoryOk && searchOk;
    }).toList();
  }

  Future<void> _open(VideoItem video) async {
    final ok = await _tiktok.open(video.tiktokUrl);

    if (!mounted || ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('TikTok bağlantısı açılamadı.'),
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
        onRefresh: _loadVideos,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              sliver: SliverList.list(
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.burgundy,
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'B_music02',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              'Güneydoğu müzik topluluğu',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor: AppColors.surface,
                        child: Icon(
                          Icons.notifications_none_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Müziğin kalbine\nyolculuk.',
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Şarkı, sanatçı veya video ara',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (featured != null)
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: AppColors.gold,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'En Yeni TikTok Videosu',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            featured.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            featured.artist,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _open(featured),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('TikTok’ta İzle'),
                          ),
                        ],
                      ),
                    ),

                  if (featured != null)
                    const SizedBox(height: 18),

                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final item = _categories[i];

                        return ChoiceChip(
                          label: Text(item),
                          selected: _category == item,
                          onSelected: (_) {
                            setState(() {
                              _category = item;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'TikTok Videoları',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!_loading)
                        IconButton(
                          onPressed: _loadVideos,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            if (_loading)
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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadVideos,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (videos.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Gösterilecek TikTok videosu bulunamadı.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  120,
                ),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => VideoCard(
                      video: videos[i],
                      onTap: () => _open(videos[i]),
                    ),
                    childCount: videos.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: .72,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
