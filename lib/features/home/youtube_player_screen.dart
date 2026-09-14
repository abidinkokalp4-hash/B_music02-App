import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/services/youtube_music_service.dart';
import '../../core/theme/app_theme.dart';

class YouTubePlayerScreen extends StatefulWidget {
  const YouTubePlayerScreen({
    super.key,
    required this.item,
    this.startSecond = 0,
    this.endSecond,
    this.compact = false,
  });

  final YouTubeMusicItem item;
  final int startSecond;
  final int? endSecond;
  final bool compact;

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  late final WebViewController _web;
  bool _loading = true;

  // YouTube requires mobile WebView embeds to identify the app with an
  // HTTPS Referer. loadHtmlString(baseUrl: ...) makes the iframe request use
  // this app identity as its Referer.
  static const String _appOrigin = 'https://com.example.b_music02';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    _load();
  }

  Future<void> _load() async {
    final start = widget.startSecond < 0 ? 0 : widget.startSecond;
    final end = widget.endSecond;

    final params = <String, String>{
      'autoplay': '1',
      'playsinline': '1',
      'rel': '0',
      'enablejsapi': '1',
      'origin': _appOrigin,
      'widget_referrer': _appOrigin,
    };
    if (start > 0) params['start'] = '$start';
    if (end != null && end > start) params['end'] = '$end';

    final embedUrl = Uri.https(
      'www.youtube.com',
      '/embed/${widget.item.videoId}',
      params,
    ).toString();

    final html = '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    html,body{margin:0;padding:0;width:100%;height:100%;background:#070812;overflow:hidden}
    iframe{display:block;border:0;width:100%;height:100%;background:#070812}
  </style>
</head>
<body>
  <iframe
    src="$embedUrl"
    title="YouTube video player"
    allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
    referrerpolicy="strict-origin-when-cross-origin"
    allowfullscreen>
  </iframe>
</body>
</html>
''';

    await _web.loadHtmlString(html, baseUrl: _appOrigin);
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.item.youtubeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        WebViewWidget(controller: _web),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.neonPurple),
          ),
      ],
    );

    if (widget.compact) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'YouTube’da aç',
            onPressed: _openExternal,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: body),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.item.channelTitle,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'YouTube’da aç',
                  onPressed: _openExternal,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
