import 'dart:convert';

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
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color:
                    Colors.white38,
                size: 55,
              ),
              const SizedBox(
                height: 15,
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
                ValueKey(video.id),
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
    extends State<_DiscoverVideoPage> {
  WebViewController? _controller;

  bool _webReady = false;
  bool _isPlaying = false;

  double _currentTime = 0;
  double _duration = 0;

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
          ..addJavaScriptChannel(
            'PlayerBridge',
            onMessageReceived:
                _handleBridgeMessage,
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
                        350,
                  ),
                );

                _sendPlayerCommand(
                  'unMute',
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

  void _handleBridgeMessage(
    JavaScriptMessage message,
  ) {
    try {
      final decoded =
          jsonDecode(
        message.message,
      );

      if (decoded
          is! Map<String, dynamic>) {
        return;
      }

      final type =
          decoded['type']
              ?.toString();

      final value =
          decoded['value'];

      if (type ==
              'onStateChange' &&
          value is num) {
        if (!mounted) return;

        setState(() {
          _isPlaying =
              value.toInt() == 1;
        });

        return;
      }

      if (type ==
              'onCurrentTime' &&
          value is Map) {
        final current =
            value['currentTime'];

        final duration =
            value['duration'];

        if (!mounted) return;

        setState(() {
          if (current is num) {
            _currentTime =
                current.toDouble();
          }

          if (duration is num) {
            _duration =
                duration.toDouble();
          }
        });
      }
    } catch (_) {
      // Oynatıcı mesajı okunamazsa
      // uygulama çalışmaya devam eder.
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
      !data ||
      !data["x-tiktok-player"]
    ) {
      return;
    }

    try {
      PlayerBridge.postMessage(
        JSON.stringify({
          type: data.type,
          value: data.value
        })
      );
    } catch (e) {}

    if (
      data.type ===
      "onPlayerReady"
    ) {
      sendPlayerCommand(
        "unMute"
      );

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
    String command, [
    dynamic value,
  ]) {
    final controller =
        _controller;

    if (controller == null) {
      return;
    }

    final commandJson =
        jsonEncode(command);

    final valueJson =
        jsonEncode(value);

    controller
        .runJavaScript(
      'sendPlayerCommand($commandJson, $valueJson);',
    );
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _sendPlayerCommand(
        'pause',
      );
    } else {
      _sendPlayerCommand(
        'unMute',
      );

      _sendPlayerCommand(
        'play',
      );
    }
  }

  void _seekBy(
    double seconds,
  ) {
    if (_duration <= 0) {
      return;
    }

    var target =
        _currentTime +
            seconds;

    if (target < 0) {
      target = 0;
    }

    if (target >
        _duration) {
      target = _duration;
    }

    _sendPlayerCommand(
      'seekTo',
      target,
    );
  }

  void _seekTo(
    double value,
  ) {
    if (_duration <= 0) {
      return;
    }

    _sendPlayerCommand(
      'seekTo',
      value,
    );

    setState(() {
      _currentTime =
          value;
    });
  }

  String _formatTime(
    double seconds,
  ) {
    if (!seconds.isFinite ||
        seconds < 0) {
      return '0:00';
    }

    final total =
        seconds.floor();

    final minutes =
        total ~/ 60;

    final secs =
        total % 60;

    return '$minutes:${secs.toString().padLeft(2, '0')}';
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
        widget.video
            .thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnail != null &&
            thumbnail.isNotEmpty)
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
              0.30,
            ),
            alignment:
                Alignment.center,
            child:
                const CircularProgressIndicator(
              color:
                  discoverGold,
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
              child:
                  _DiscoverTitle(),
            ),
          ),
        ),

        Positioned(
          right: 14,
          bottom: 190,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                padding:
                    const EdgeInsets
                        .all(3),
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color: Colors.black
                      .withOpacity(
                    0.52,
                  ),
                  border:
                      Border.all(
                    color:
                        discoverGold,
                    width: 1.5,
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
                height: 17,
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
                height: 15,
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
                height: 15,
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
          left: 16,
          right: 82,
          bottom: 135,
          child:
              IgnorePointer(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Text(
                  '@b_music02',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight
                            .w900,
                    shadows: [
                      Shadow(
                        color:
                            Colors.black,
                        blurRadius:
                            8,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  widget
                      .video.title,
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 13,
                    shadows: [
                      Shadow(
                        color:
                            Colors.black,
                        blurRadius:
                            8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          left: 14,
          right: 14,
          bottom: 13,
          child:
              _PlaybackControls(
            isPlaying:
                _isPlaying,
            currentTime:
                _currentTime,
            duration:
                _duration,
            currentText:
                _formatTime(
              _currentTime,
            ),
            durationText:
                _formatTime(
              _duration,
            ),
            onPlayPause:
                _togglePlayback,
            onBack: () {
              _seekBy(
                -10,
              );
            },
            onForward: () {
              _seekBy(
                10,
              );
            },
            onSeek:
                _seekTo,
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

class _PlaybackControls
    extends StatelessWidget {
  const _PlaybackControls({
    required this.isPlaying,
    required this.currentTime,
    required this.duration,
    required this.currentText,
    required this.durationText,
    required this.onPlayPause,
    required this.onBack,
    required this.onForward,
    required this.onSeek,
  });

  final bool isPlaying;

  final double currentTime;
  final double duration;

  final String currentText;
  final String durationText;

  final VoidCallback onPlayPause;
  final VoidCallback onBack;
  final VoidCallback onForward;

  final ValueChanged<double>
      onSeek;

  @override
  Widget build(
    BuildContext context,
  ) {
    final max =
        duration > 0
            ? duration
            : 1.0;

    final safeValue =
        currentTime
            .clamp(
              0.0,
              max,
            )
            .toDouble();

    return Container(
      padding:
          const EdgeInsets
              .fromLTRB(
        12,
        8,
        12,
        10,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.black
                .withOpacity(
          0.68,
        ),
        borderRadius:
            BorderRadius
                .circular(
          22,
        ),
        border:
            Border.all(
          color:
              Colors.white12,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.28,
            ),
            blurRadius:
                15,
          ),
        ],
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                currentText,
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                  fontSize: 10,
                ),
              ),

              Expanded(
                child:
                    SliderTheme(
                  data:
                      SliderTheme.of(
                    context,
                  ).copyWith(
                    activeTrackColor:
                        discoverGold,
                    inactiveTrackColor:
                        Colors.white24,
                    thumbColor:
                        discoverGold,
                    overlayColor:
                        discoverGold
                            .withOpacity(
                      0.15,
                    ),
                    trackHeight:
                        2.5,
                    thumbShape:
                        const RoundSliderThumbShape(
                      enabledThumbRadius:
                          5,
                    ),
                  ),
                  child:
                      Slider(
                    min: 0,
                    max: max,
                    value:
                        safeValue,
                    onChanged:
                        duration > 0
                            ? onSeek
                            : null,
                  ),
                ),
              ),

              Text(
                durationText,
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .center,
            children: [
              _ControlButton(
                icon: Icons
                    .replay_10_rounded,
                onTap:
                    onBack,
              ),

              const SizedBox(
                width: 18,
              ),

              _ControlButton(
                icon: isPlaying
                    ? Icons
                        .pause_rounded
                    : Icons
                        .play_arrow_rounded,
                large: true,
                onTap:
                    onPlayPause,
              ),

              const SizedBox(
                width: 18,
              ),

              _ControlButton(
                icon: Icons
                    .forward_10_rounded,
                onTap:
                    onForward,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton
    extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.large = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(
    BuildContext context,
  ) {
    final size =
        large ? 48.0 : 39.0;

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        customBorder:
            const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,
            color: large
                ? discoverGold
                : Colors.white
                    .withOpacity(
                  0.10,
                ),
            border:
                Border.all(
              color: large
                  ? discoverGold
                  : Colors.white24,
            ),
          ),
          child: Icon(
            icon,
            color: large
                ? Colors.black
                : Colors.white,
            size:
                large
                    ? 30
                    : 23,
          ),
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
        vertical: 9,
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
          fontSize: 16,
          fontWeight:
              FontWeight.w900,
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
    return GestureDetector(
      onTap:
          onTap,
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
                0.54,
              ),
              border:
                  Border.all(
                color: active
                    ? const Color(
                        0xFFE85672,
                      )
                    : Colors.white24,
              ),
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
            height: 4,
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
    );
  }
}
