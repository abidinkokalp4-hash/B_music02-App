import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/tiktok_service.dart';
import '../../models/video_item.dart';
import '../requests/requests_screen.dart';

const discoverGold = Color(0xFFD4AF57);
const discoverBurgundy = Color(0xFF7A1F3D);

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
  });

  @override
  State<DiscoverScreen> createState() =>
      _DiscoverScreenState();
}

class _DiscoverScreenState
    extends State<DiscoverScreen> {
  final TikTokService _tiktok =
      const TikTokService();

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

  void _toggleLike(
    VideoItem video,
  ) {
    setState(() {
      if (_likedVideos
          .contains(video.id)) {
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
          'Yorum sistemi sonraki aşamada bağlanacak.',
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
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Scaffold(
        backgroundColor:
            Colors.black,
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
        backgroundColor:
            Colors.black,
        body: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons
                      .wifi_off_rounded,
                  color:
                      Colors.white38,
                  size: 55,
                ),

                const SizedBox(
                  height: 16,
                ),

                Text(
                  _error!,
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                ElevatedButton(
                  onPressed:
                      _loadFirstPage,
                  child:
                      const Text(
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
        backgroundColor:
            Colors.black,
        body: Center(
          child: Text(
            'Henüz video yok.',
            style: TextStyle(
              color:
                  Colors.white60,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          Colors.black,
      body: PageView.builder(
        controller:
            _pageController,
        scrollDirection:
            Axis.vertical,
        itemCount:
            _videos.length,
        onPageChanged: (
          index,
        ) {
          setState(() {
            _currentIndex =
                index;
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
            key:
                ValueKey(
              video.id,
            ),
            video: video,
            active:
                index ==
                    _currentIndex,
            liked:
                _likedVideos
                    .contains(
              video.id,
            ),
            onLike: () {
              _toggleLike(
                video,
              );
            },
            onComments:
                _showComments,
            onRequest:
                _openRequests,
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
  });

  final VideoItem video;
  final bool active;
  final bool liked;

  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onRequest;

  @override
  State<_DiscoverVideoPage>
      createState() =>
          _DiscoverVideoPageState();
}

class _DiscoverVideoPageState
    extends State<
        _DiscoverVideoPage> {
  WebViewController? _controller;

  bool _webReady = false;

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
        _sendPlayerCommand(
          'play',
        );
      }
    }

    if (!widget.active &&
        oldWidget.active) {
      _sendPlayerCommand(
        'pause',
      );
    }
  }

  Future<void>
      _createPlayer() async {
    final controller =
        WebViewController()
          ..setJavaScriptMode(
            JavaScriptMode
                .unrestricted,
          )
          ..setBackgroundColor(
            Colors.black,
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished:
                  (_) async {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _webReady =
                      true;
                });

                await Future
                    .delayed(
                  const Duration(
                    milliseconds:
                        400,
                  ),
                );

                _sendPlayerCommand(
                  'play',
                );
              },
            ),
          );

    _controller =
        controller;

    await controller
        .loadHtmlString(
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
        '&controls=1'
        '&progress_bar=1'
        '&play_button=1'
        '&volume_control=1'
        '&fullscreen_button=1'
        '&timestamp=1'
        '&music_info=0'
        '&description=0'
        '&rel=0'
        '&native_context_menu=0';

    return '''
<!DOCTYPE html>
<html>
<head>

<meta
  name="viewport"
  content="width=device-width,
  initial-scale=1,
  maximum-scale=1,
  user-scalable=no"
/>

<style>

html,
body {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: #000000;
}

iframe {
  position: fixed;
  inset: 0;
  width: 100%;
  height: 100%;
  border: 0;
  background: #000000;
}

</style>

</head>

<body>

<iframe
  id="tiktokPlayer"
  src="$playerUrl"
  allow="autoplay; fullscreen; encrypted-media; picture-in-picture"
  allowfullscreen>
</iframe>

<script>

const player =
  document.getElementById(
    'tiktokPlayer'
  );

function sendPlayerCommand(
  type,
  value = null
) {
  try {
    player.contentWindow
      .postMessage(
        {
          "x-tiktok-player": true,
          "type": type,
          "value": value
        },
        "*"
      );
  } catch (e) {}
}

window.addEventListener(
  "message",
  function(event) {
    const data =
      event.data;

    if (
      data &&
      data["x-tiktok-player"] &&
      data.type ===
        "onPlayerReady"
    ) {
      sendPlayerCommand(
        "play"
      );
    }
  }
);

document.addEventListener(
  "visibilitychange",
  function() {
    if (
      document.hidden
    ) {
      sendPlayerCommand(
        "pause"
      );
    }
  }
);

</script>

</body>
</html>
''';
  }

  void _sendPlayerCommand(
    String command,
  ) {
    final controller =
        _controller;

    if (controller == null) {
      return;
    }

    controller
        .runJavaScript(
      "sendPlayerCommand('$command');",
    );
  }

  @override
  void dispose() {
    _sendPlayerCommand(
      'pause',
    );

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
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
          WebViewWidget(
            controller:
                _controller!,
          ),

        if (!_webReady &&
            widget.active)
          Container(
            color: Colors.black
                .withOpacity(
              0.35,
            ),
            alignment:
                Alignment.center,
            child:
                const SizedBox(
              width: 34,
              height: 34,
              child:
                  CircularProgressIndicator(
                color:
                    discoverGold,
                strokeWidth: 2,
              ),
            ),
          ),

        Positioned(
          top:
              MediaQuery.of(
                        context,
                      )
                      .padding
                      .top +
                  12,
          left: 0,
          right: 0,
          child:
              const IgnorePointer(
            child: Center(
              child: _DiscoverTitle(),
            ),
          ),
        ),

        Positioned(
          right: 14,
          bottom: 155,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                padding:
                    const EdgeInsets
                        .all(
                  3,
                ),
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color: Colors.black
                      .withOpacity(
                    0.50,
                  ),
                  border:
                      Border.all(
                    color:
                        discoverGold,
                    width: 1.6,
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

              const SizedBox(
                height: 18,
              ),

              _SideAction(
                icon:
                    widget.liked
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
                height: 17,
              ),

              _SideAction(
                icon: Icons
                    .chat_bubble_outline_rounded,
                label:
                    'Yorum',
                onTap:
                    widget
                        .onComments,
              ),

              const SizedBox(
                height: 17,
              ),

              _SideAction(
                icon: Icons
                    .music_note_rounded,
                label:
                    'İstek',
                onTap:
                    widget.onRequest,
              ),
            ],
          ),
        ),

        Positioned(
          left: 18,
          right: 92,
          bottom: 105,
          child:
              IgnorePointer(
            child: Container(
              padding:
                  const EdgeInsets
                      .all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.black
                    .withOpacity(
                  0.34,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  18,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Text(
                    '@b_music02',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    widget
                        .video
                        .title,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          13,
                      height:
                          1.30,
                    ),
                  ),
                ],
              ),
            ),
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
              0xFF180B11,
            ),
            Colors.black,
          ],
        ),
      ),
      child:
          const Center(
        child: Icon(
          Icons
              .music_note_rounded,
          color:
              discoverGold,
          size: 90,
        ),
      ),
    );
  }
}

class _DiscoverTitle
    extends StatelessWidget {
  const _DiscoverTitle();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 21,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.black
                .withOpacity(
          0.55,
        ),
        borderRadius:
            BorderRadius
                .circular(
          28,
        ),
        border:
            Border.all(
          color:
              discoverGold
                  .withOpacity(
            0.50,
          ),
        ),
      ),
      child:
          const Text(
        'Keşfet',
        style:
            TextStyle(
          color:
              discoverGold,
          fontSize: 17,
          fontWeight:
              FontWeight.w900,
          letterSpacing:
              0.3,
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
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        customBorder:
            const CircleBorder(),
        child: Column(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    Colors.black
                        .withOpacity(
                  0.53,
                ),
                border:
                    Border.all(
                  color: active
                      ? const Color(
                          0xFFE85672,
                        )
                      : Colors
                          .white24,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(
                      0.30,
                    ),
                    blurRadius:
                        10,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: active
                    ? const Color(
                        0xFFE85672,
                      )
                    : Colors.white,
                size: 27,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              label,
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
                    blurRadius:
                        6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
