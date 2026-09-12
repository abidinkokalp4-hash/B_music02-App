import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/tiktok_service.dart';
import '../../models/video_item.dart';
import '../requests/requests_screen.dart';

const discoverGold = Color(0xFFD4AF57);
const discoverBurgundy = Color(0xFF7A1F3D);

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() =>
      _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TikTokService _tiktok = const TikTokService();

  final PageController _pageController =
      PageController();

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
        for (final video in page.videos) {
          final exists =
              _videos.any(
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

  Future<void> _openVideo(
    VideoItem video,
  ) async {
    final opened =
        await _tiktok.open(
      video.tiktokUrl,
    );

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'TikTok bağlantısı açılamadı.',
        ),
      ),
    );
  }

  Future<void> _openTikTokProfile() async {
    final opened =
        await _tiktok.open(
      'https://www.tiktok.com/@b_music02',
    );

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'TikTok profili açılamadı.',
        ),
      ),
    );
  }

  void _toggleLike(
    VideoItem video,
  ) {
    setState(() {
      if (_likedVideos.contains(
        video.id,
      )) {
        _likedVideos.remove(
          video.id,
        );
      } else {
        _likedVideos.add(
          video.id,
        );
      }
    });
  }

  void _showComments() {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Yorum sistemi daha sonra bağlanacak.',
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child:
              CircularProgressIndicator(
            color: discoverGold,
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Colors.white38,
                size: 55,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
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
      );
    }

    if (_videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Henüz video yok.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection:
            Axis.vertical,
        itemCount: _videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });

          if (index >=
              _videos.length - 3) {
            _loadMore();
          }
        },
        itemBuilder: (
          context,
          index,
        ) {
          final video =
              _videos[index];

          return _DiscoverVideoPage(
            key: ValueKey(
              video.id,
            ),
            video: video,
            active:
                index ==
                    _currentIndex,
            liked:
                _likedVideos.contains(
              video.id,
            ),
            onLike: () {
              _toggleLike(video);
            },
            onComments:
                _showComments,
            onRequest:
                _openRequests,
            onOpen: () {
              _openVideo(video);
            },
            onProfile:
                _openTikTokProfile,
          );
        },
      ),
    );
  }
}

class _DiscoverVideoPage
    extends StatefulWidget {
  const _DiscoverVideoPage({
    super.key,
    required this.video,
    required this.active,
    required this.liked,
    required this.onLike,
    required this.onComments,
    required this.onRequest,
    required this.onOpen,
    required this.onProfile,
  });

  final VideoItem video;
  final bool active;
  final bool liked;

  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onRequest;
  final VoidCallback onOpen;
  final VoidCallback onProfile;

  @override
  State<_DiscoverVideoPage>
      createState() =>
          _DiscoverVideoPageState();
}

class _DiscoverVideoPageState
    extends State<_DiscoverVideoPage> {
  WebViewController? _controller;

  bool _webReady = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();

    if (widget.active) {
      _createPlayer();
    }
  }

  @override
  void didUpdateWidget(
    covariant _DiscoverVideoPage
        oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (widget.active &&
        !oldWidget.active) {
      if (_controller == null) {
        _createPlayer();
      } else {
        _send('mute');
        _send('play');

        if (mounted) {
          setState(() {
            _muted = true;
          });
        }
      }
    }

    if (!widget.active &&
        oldWidget.active) {
      _send('pause');
    }
  }

  Future<void> _createPlayer() async {
    final controller =
        WebViewController()
          ..setJavaScriptMode(
            JavaScriptMode.unrestricted,
          )
          ..setBackgroundColor(
            Colors.black,
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) async {
                if (!mounted) return;

                setState(() {
                  _webReady = true;
                });

                await Future.delayed(
                  const Duration(
                    milliseconds: 300,
                  ),
                );

                _send('mute');
                _send('play');
              },
            ),
          );

    _controller = controller;

    await controller.loadHtmlString(
      _playerHtml(
        widget.video.id,
      ),
      baseUrl:
          'https://www.tiktok.com',
    );

    if (mounted) {
      setState(() {});
    }
  }

  String _playerHtml(
    String videoId,
  ) {
    final playerUrl =
        'https://www.tiktok.com/player/v1/$videoId'
        '?autoplay=1'
        '&loop=1'
        '&controls=0'
        '&progress_bar=0'
        '&play_button=0'
        '&volume_control=0'
        '&fullscreen_button=0'
        '&timestamp=0'
        '&music_info=0'
        '&description=0'
        '&rel=0'
        '&native_context_menu=0';

    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport"
content="width=device-width,
initial-scale=1,
maximum-scale=1,
user-scalable=no">

<style>
html, body {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: #000;
}

iframe {
  position: fixed;
  inset: 0;
  width: 100%;
  height: 100%;
  border: 0;
  background: #000;
}
</style>
</head>

<body>

<iframe
  id="tt"
  src="$playerUrl"
  allow="autoplay; fullscreen; encrypted-media; picture-in-picture"
  allowfullscreen>
</iframe>

<script>
const player =
  document.getElementById('tt');

function send(type) {
  try {
    player.contentWindow.postMessage(
      {
        "x-tiktok-player": true,
        "type": type,
        "value": null
      },
      "*"
    );
  } catch (e) {}
}

window.addEventListener(
  "message",
  function(event) {
    const data = event.data;

    if (
      data &&
      data["x-tiktok-player"] &&
      data.type === "onPlayerReady"
    ) {
      send("mute");
      send("play");
    }
  }
);

document.addEventListener(
  "visibilitychange",
  function() {
    if (document.hidden) {
      send("pause");
    }
  }
);
</script>

</body>
</html>
''';
  }

  void _send(
    String command,
  ) {
    final controller =
        _controller;

    if (controller == null) {
      return;
    }

    controller.runJavaScript(
      "send('$command');",
    );
  }

  void _toggleSound() {
    if (_muted) {
      _send('unMute');

      setState(() {
        _muted = false;
      });
    } else {
      _send('mute');

      setState(() {
        _muted = true;
      });
    }
  }

  void _retryPlay() {
    _send('play');
  }

  @override
  void dispose() {
    _send('pause');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail =
        widget.video.thumbnailUrl;

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
              return _fallback();
            },
          )
        else
          _fallback(),

        if (widget.active &&
            _controller != null)
          IgnorePointer(
            ignoring: true,
            child: WebViewWidget(
              controller:
                  _controller!,
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
                  0x33000000,
                ),
                Color(
                  0x00000000,
                ),
                Color(
                  0x15000000,
                ),
                Color(
                  0xC9000000,
                ),
              ],
              stops: [
                0,
                0.30,
                0.62,
                1,
              ],
            ),
          ),
        ),

        Positioned(
          top:
              MediaQuery.of(context)
                      .padding
                      .top +
                  12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 19,
                  vertical: 9,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      discoverGold,
                  borderRadius:
                      BorderRadius
                          .circular(
                    24,
                  ),
                ),
                child: const Text(
                  'Keşfet',
                  style: TextStyle(
                    color:
                        Colors.black,
                    fontWeight:
                        FontWeight
                            .w900,
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              GestureDetector(
                onTap:
                    widget.onProfile,
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 19,
                    vertical: 9,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.black
                        .withOpacity(
                      0.42,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      24,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors.white30,
                    ),
                  ),
                  child: const Text(
                    'Takip',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (!_webReady &&
            widget.active)
          const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child:
                  CircularProgressIndicator(
                color:
                    discoverGold,
                strokeWidth: 2,
              ),
            ),
          ),

        Positioned(
          right: 14,
          bottom: 78,
          child: Column(
            children: [
              GestureDetector(
                onTap:
                    widget.onProfile,
                child: Container(
                  width: 54,
                  height: 54,
                  padding:
                      const EdgeInsets
                          .all(3),
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color:
                          discoverGold,
                      width: 1.7,
                    ),
                  ),
                  child: ClipOval(
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
                height: 16,
              ),

              _SideAction(
                icon: widget.liked
                    ? Icons
                        .favorite_rounded
                    : Icons
                        .favorite_border_rounded,
                label:
                    widget.liked
                        ? 'Beğendin'
                        : 'Beğen',
                active:
                    widget.liked,
                onTap:
                    widget.onLike,
              ),

              const SizedBox(
                height: 14,
              ),

              _SideAction(
                icon: Icons
                    .chat_bubble_outline_rounded,
                label: 'Yorum',
                onTap:
                    widget.onComments,
              ),

              const SizedBox(
                height: 14,
              ),

              _SideAction(
                icon: Icons
                    .music_note_rounded,
                label: 'İstek',
                onTap:
                    widget.onRequest,
              ),

              const SizedBox(
                height: 14,
              ),

              _SideAction(
                icon: _muted
                    ? Icons
                        .volume_off_rounded
                    : Icons
                        .volume_up_rounded,
                label: 'Ses',
                onTap:
                    _toggleSound,
              ),

              const SizedBox(
                height: 14,
              ),

              _SideAction(
                icon: Icons
                    .open_in_new_rounded,
                label: 'Aç',
                onTap:
                    widget.onOpen,
              ),
            ],
          ),
        ),

        Positioned(
          left: 18,
          right: 86,
          bottom: 28,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                '@b_music02',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              Text(
                widget.video.title,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),

              const SizedBox(
                height: 9,
              ),

              const Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .music_note_rounded,
                    color:
                        discoverGold,
                    size: 16,
                  ),
                  SizedBox(
                    width: 6,
                  ),
                  Text(
                    'B_music02 • TikTok',
                    style:
                        TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 12,
                      fontWeight:
                          FontWeight
                              .w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 7,
              ),

              GestureDetector(
                onTap:
                    _retryPlay,
                child: const Text(
                  'Video durursa oynatmak için dokun',
                  style:
                      TextStyle(
                    color:
                        Colors.white38,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallback() {
    return Container(
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            discoverBurgundy,
            Color(
              0xFF170B10,
            ),
            Colors.black,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons
              .music_note_rounded,
          size: 90,
          color: discoverGold,
        ),
      ),
    );
  }
}

class _SideAction
    extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: active
                ? const Color(
                    0xFFE8506D,
                  )
                : Colors.white,
            size: 30,
            shadows: const [
              Shadow(
                color:
                    Colors.black54,
                blurRadius: 7,
              ),
            ],
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            label,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight:
                  FontWeight.w700,
              shadows: [
                Shadow(
                  color:
                      Colors.black,
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
