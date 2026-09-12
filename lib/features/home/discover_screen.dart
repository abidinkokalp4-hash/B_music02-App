import 'package:flutter/material.dart';

import '../../core/services/tiktok_service.dart';
import '../../models/video_item.dart';
import '../requests/requests_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() =>
      _DiscoverScreenState();
}

class _DiscoverScreenState
    extends State<DiscoverScreen> {
  static const _gold = Color(0xFFD4AF57);
  static const _burgundy = Color(0xFF7A1F3D);

  final _tiktok = const TikTokService();
  final _pageController = PageController();

  final List<VideoItem> _videos = [];
  final Set<String> _likedVideos = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int? _cursor;
  int _currentIndex = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
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
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Videolar yüklenemedi.';
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

  Future<void> _openVideo(
    VideoItem video,
  ) async {
    final opened = await _tiktok.open(
      video.tiktokUrl,
    );

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'TikTok bağlantısı açılamadı.',
        ),
      ),
    );
  }

  void _toggleLike(VideoItem video) {
    setState(() {
      if (_likedVideos.contains(video.id)) {
        _likedVideos.remove(video.id);
      } else {
        _likedVideos.add(video.id);
      }
    });
  }

  void _showComments() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Yorum sistemi sonraki aşamada eklenecek.',
        ),
      ),
    );
  }

  void _openRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RequestsScreen(),
      ),
    );
  }

  void _followingPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Takip sistemi sonraki aşamada bağlanacak.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: _gold,
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white54,
                  size: 54,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _loadFirstPage,
                  child: const Text(
                    'Tekrar Dene',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Henüz video yok.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });

          if (index >= _videos.length - 3) {
            _loadMore();
          }
        },
        itemBuilder: (context, index) {
          final video = _videos[index];

          return _buildVideoPage(
            video,
            index,
          );
        },
      ),
    );
  }

  Widget _buildVideoPage(
    VideoItem video,
    int index,
  ) {
    final thumbnail = video.thumbnailUrl;
    final liked =
        _likedVideos.contains(video.id);

    return Stack(
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
              return _fallbackBackground();
            },
          )
        else
          _fallbackBackground(),

        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x10000000),
                Color(0x22000000),
                Color(0xE6000000),
              ],
              stops: [
                0,
                0.28,
                0.55,
                1,
              ],
            ),
          ),
        ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 0,
          right: 0,
          child: _buildTopTabs(),
        ),

        Center(
          child: GestureDetector(
            onTap: () {
              _openVideo(video);
            },
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(
                  0.38,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white70,
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
        ),

        Positioned(
          right: 14,
          bottom: 96,
          child: _buildActions(
            video,
            liked,
          ),
        ),

        Positioned(
          left: 18,
          right: 82,
          bottom: 32,
          child: _buildCaption(video),
        ),

        Positioned(
          left: 18,
          right: 18,
          bottom: 10,
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _videos.length <= 1
                  ? 1
                  : (_currentIndex + 1) /
                      _videos.length,
              minHeight: 2,
              backgroundColor:
                  Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation(
                _gold,
              ),
            ),
          ),
        ),

        if (_loadingMore &&
            index == _videos.length - 1)
          const Positioned(
            bottom: 65,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _gold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopTabs() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: _gold,
            borderRadius:
                BorderRadius.circular(24),
          ),
          child: const Text(
            'Keşfet',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(width: 8),

        GestureDetector(
          onTap: _followingPressed,
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color:
                  Colors.black.withOpacity(0.38),
              borderRadius:
                  BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white24,
              ),
            ),
            child: const Text(
              'Takip',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(
    VideoItem video,
    bool liked,
  ) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _gold,
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/b_music02_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return const ColoredBox(
                  color: _burgundy,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: _gold,
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 20),

        _sideButton(
          icon: liked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: liked ? 'Beğendin' : 'Beğen',
          active: liked,
          onTap: () {
            _toggleLike(video);
          },
        ),

        const SizedBox(height: 18),

        _sideButton(
          icon:
              Icons.chat_bubble_outline_rounded,
          label: 'Yorum',
          onTap: _showComments,
        ),

        const SizedBox(height: 18),

        _sideButton(
          icon: Icons.music_note_rounded,
          label: 'İstek',
          onTap: _openRequests,
        ),

        const SizedBox(height: 18),

        _sideButton(
          icon: Icons.open_in_new_rounded,
          label: 'Aç',
          onTap: () {
            _openVideo(video);
          },
        ),
      ],
    );
  }

  Widget _sideButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: active
                ? const Color(0xFFE84A68)
                : Colors.white,
            size: 31,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaption(
    VideoItem video,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          video.artist,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 10),

        GestureDetector(
          onTap: () {
            _openVideo(video);
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note_rounded,
                color: _gold,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'B_music02 • TikTok',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallbackBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _burgundy,
            Color(0xFF130A0F),
            Colors.black,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 100,
          color: _gold,
        ),
      ),
    );
  }
}
