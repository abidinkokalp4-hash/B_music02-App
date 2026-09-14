import 'package:flutter/material.dart';
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
  // HTTPS Referer. Keep this origin in sync with the working embed setup.
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
    title="B_music02 player"
    allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
    referrerpolicy="strict-origin-when-cross-origin"
    allowfullscreen>
  </iframe>
</body>
</html>
''';

    await _web.loadHtmlString(html, baseUrl: _appOrigin);
  }

  @override
  Widget build(BuildContext context) {
    final player = Stack(
      children: [
        WebViewWidget(controller: _web),
        if (_loading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.neonPurple),
          ),
      ],
    );

    if (widget.compact) return player;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        centerTitle: true,
        title: const Text(
          'Şimdi Çalıyor',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x663D1A78),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    widget.item.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF231646),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.music_note_rounded,
                        size: 72,
                        color: AppColors.neonPurple,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              widget.item.channelTitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF10121D),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF262A3B)),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: player,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
