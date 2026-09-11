import 'package:flutter/material.dart';
import '../../core/services/tiktok_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo_repository.dart';
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
  String _category = 'Tümü';

  static const _categories = ['Tümü', 'Yeni', 'Uzun Hava', 'Duygusal', 'Hareketli', 'İstek Üzerine'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<VideoItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return DemoRepository.videos.where((v) {
      final categoryOk = _category == 'Tümü' || v.category == _category;
      final searchOk = q.isEmpty || v.title.toLowerCase().contains(q) || v.artist.toLowerCase().contains(q);
      return categoryOk && searchOk;
    }).toList();
  }

  Future<void> _open(VideoItem video) async {
    final ok = await _tiktok.open(video.tiktokUrl);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TikTok bağlantısı açılamadı.')));
  }

  @override
  Widget build(BuildContext context) {
    final videos = _filtered;
    final featured = DemoRepository.videos.firstWhere((e) => e.featured);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            sliver: SliverList.list(children: [
              const Row(
                children: [
                  CircleAvatar(backgroundColor: AppColors.burgundy, child: Icon(Icons.graphic_eq_rounded, color: AppColors.gold)),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('B_music02', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                    Text('Güneydoğu müzik topluluğu', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ])),
                  CircleAvatar(backgroundColor: AppColors.surface, child: Icon(Icons.notifications_none_rounded)),
                ],
              ),
              const SizedBox(height: 22),
              const Text('Müziğin kalbine\nyolculuk.', style: TextStyle(fontSize: 34, height: 1.05, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Şarkı, sanatçı veya video ara', prefixIcon: Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [Icon(Icons.auto_awesome_rounded, color: AppColors.gold), SizedBox(width: 8), Text('Öne Çıkan', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800))]),
                  const SizedBox(height: 14),
                  Text(featured.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(featured.artist, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: () => _open(featured), icon: const Icon(Icons.play_arrow_rounded), label: const Text('TikTok’ta İzle')),
                ]),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final item = _categories[i];
                    return ChoiceChip(label: Text(item), selected: _category == item, onSelected: (_) => setState(() => _category = item));
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Videolar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
            ]),
          ),
          if (videos.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('Bu filtrede içerik bulunamadı.')))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, i) => VideoCard(video: videos[i], onTap: () => _open(videos[i])), childCount: videos.length),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .72),
              ),
            ),
        ],
      ),
    );
  }
}
