import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/youtube_music_service.dart';
import '../../core/theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _youtube = const YouTubeMusicService();
  final _controller = TextEditingController();
  final _music = LocalMusicService.instance;

  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<YouTubeMusicItem> _items = const [];

  static const _categories = <_SearchCategory>[
    _SearchCategory('Pop', 'pop music', [Color(0xFFD13AC8), Color(0xFF8E28DD)]),
    _SearchCategory('Elektronik', 'electronic music', [Color(0xFF2D75EF), Color(0xFF1747A9)]),
    _SearchCategory('Hiphop', 'hip hop music', [Color(0xFF7634EE), Color(0xFF4318B9)]),
    _SearchCategory('Rock', 'rock music', [Color(0xFFE04461), Color(0xFFB32045)]),
    _SearchCategory('R&B', 'r&b music', [Color(0xFFD4319A), Color(0xFF8D1B92)]),
    _SearchCategory('Kürtçe', 'Kürtçe müzik', [Color(0xFF1EAAC3), Color(0xFF0A7188)]),
  ];

  @override
  void initState() {
    super.initState();
    _search('popular music');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _debounce = Timer(const Duration(milliseconds: 350), () => _search('popular music'));
    } else {
      _debounce = Timer(const Duration(milliseconds: 650), () => _search(value));
    }
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _youtube.searchMusic(query, maxResults: 20);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectCategory(_SearchCategory category) async {
    _controller.text = category.label;
    setState(() {});
    await _search(category.query);
  }

  Future<void> _open(YouTubeMusicItem item) async {
    await _music.pause();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _SearchPlayerScreen(item: item)),
    );
  }

  bool get _isBrowsing => _controller.text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 165),
          children: [
            _topBar(),
            const SizedBox(height: 14),
            _searchField(),
            const SizedBox(height: 18),
            if (_isBrowsing) ...[
              const _Heading('Popüler Aramalar'),
              const SizedBox(height: 8),
              _popularSearches(),
              const SizedBox(height: 18),
              const _Heading('Kategoriler'),
              const SizedBox(height: 10),
              _categoryGrid(),
            ] else ...[
              Row(
                children: [
                  const Expanded(child: _Heading('Arama Sonuçları')),
                  TextButton(
                    onPressed: () {
                      _controller.clear();
                      _changed('');
                    },
                    child: const Text('Temizle'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _results(),
            ],
            if (_isBrowsing && _error != null) ...[
              const SizedBox(height: 14),
              Text(
                'Popüler aramalar yüklenemedi. Arama kutusunu yine de kullanabilirsin.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text('Arama', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Positioned(
            right: 4,
            child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 25),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 51,
      decoration: BoxDecoration(
        color: const Color(0xFF151724),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF2A2D40)),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) _search(value);
        },
        decoration: InputDecoration(
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: 'Sanatçı, şarkı veya müzik ara',
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFC8CAD6)),
          suffixIcon: IconButton(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                _controller.clear();
                _changed('');
              }
            },
            icon: Icon(
              _controller.text.isEmpty ? Icons.tune_rounded : Icons.close_rounded,
              color: const Color(0xFFC8CAD6),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _popularSearches() {
    if (_loading && _items.isEmpty) {
      return const SizedBox(
        height: 170,
        child: Center(child: CircularProgressIndicator(color: AppColors.neonPurple)),
      );
    }

    final popular = _items.take(3).toList();
    return Column(
      children: popular.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Material(
            color: const Color(0xFF151724),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _open(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        item.thumbnailUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbFallback(),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _categoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (context, index) {
        final category = _categories[index];
        return InkWell(
          onTap: () => _selectCategory(category),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: category.colors,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category.label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _results() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(child: CircularProgressIndicator(color: AppColors.neonPurple)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Text(_error!, style: const TextStyle(color: Colors.white54)),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: Text('Sonuç bulunamadı')),
      );
    }

    return Column(
      children: _items.map((item) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 3),
          onTap: () => _open(item),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.network(
              item.thumbnailUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _thumbFallback(),
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            item.channelTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          trailing: const Icon(Icons.play_arrow_rounded, color: Colors.white70),
        );
      }).toList(),
    );
  }

  static Widget _thumbFallback() {
    return Container(
      width: 48,
      height: 48,
      color: const Color(0xFF231646),
      child: const Icon(Icons.music_note_rounded, color: AppColors.neonPurple),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800));
  }
}

class _SearchCategory {
  const _SearchCategory(this.label, this.query, this.colors);
  final String label;
  final String query;
  final List<Color> colors;
}

class _SearchPlayerScreen extends StatefulWidget {
  const _SearchPlayerScreen({required this.item});
  final YouTubeMusicItem item;

  @override
  State<_SearchPlayerScreen> createState() => _SearchPlayerScreenState();
}

class _SearchPlayerScreenState extends State<_SearchPlayerScreen> {
  late final WebViewController _web;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..loadRequest(Uri.parse(widget.item.embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: WebViewWidget(controller: _web)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(widget.item.channelTitle, style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
