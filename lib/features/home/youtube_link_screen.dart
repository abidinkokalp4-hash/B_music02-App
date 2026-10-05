import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/youtube_link.dart';

class YouTubeLinkScreen extends StatefulWidget {
  const YouTubeLinkScreen({super.key, this.active = true});
  final bool active;
  @override
  State<YouTubeLinkScreen> createState() => _YouTubeLinkState();
}

class _YouTubeLinkState extends State<YouTubeLinkScreen> with WidgetsBindingObserver {
  final input = TextEditingController();
  WebViewController? web;
  String? error, videoId;
  bool loading = false;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  void pauseVideo() {
    web?.runJavaScript("document.querySelector('iframe')?.contentWindow.postMessage(JSON.stringify({event:'command',func:'pauseVideo',args:[]}), '*');").catchError((Object _) {});
  }
  @override
  void didUpdateWidget(covariant YouTubeLinkScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) pauseVideo();
  }
  @override
  void dispose() { pauseVideo(); WidgetsBinding.instance.removeObserver(this); input.dispose(); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      pauseVideo();
    }
  }
  Future<void> open() async {
    final id = youtubeVideoId(input.text);
    if (id == null) { setState(() => error = 'Geçerli bir YouTube video bağlantısı yapıştırın.'); return; }
    await LocalMusicService.instance.pause();
    if (!mounted) return;
    const origin = 'https://com.example.b_music02';
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('PlayerStatus', onMessageReceived: (message) {
        if (!mounted) return;
        setState(() { loading = false; if (message.message.startsWith('error')) error = 'Video burada oynatılamıyor. YouTube’da açabilirsiniz.'; });
      })
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri?.scheme == 'https' && (uri!.host == 'www.youtube.com' || uri.host == 'www.youtube-nocookie.com' || uri.host == 'com.example.b_music02')) return NavigationDecision.navigate;
          return request.isMainFrame ? NavigationDecision.prevent : NavigationDecision.navigate;
        },
        onWebResourceError: (e) { if (mounted && e.isForMainFrame == true) setState(() { loading = false; error = 'Bağlantı kurulamadı. İnternet erişimini kontrol edin.'; }); },
      ));
    setState(() { web = controller; videoId = id; error = null; loading = true; });
    await controller.loadHtmlString('''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="strict-origin-when-cross-origin"><style>html,body,#player{margin:0;width:100%;height:100%;background:black}</style></head><body><div id="player"></div><script src="https://www.youtube.com/iframe_api"></script><script>function onYouTubeIframeAPIReady(){new YT.Player('player',{videoId:'$id',playerVars:{playsinline:1,origin:'$origin'},events:{onReady:function(){PlayerStatus.postMessage('ready')},onError:function(e){PlayerStatus.postMessage('error:'+e.data)}}})}</script></body></html>''', baseUrl: origin);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bağlantı • YouTube')),
    body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 160), children: [
      const Text('YouTube bağlantısını yapıştırın, videoyu burada izleyin.'),
      const SizedBox(height: 16),
      TextField(controller: input, keyboardType: TextInputType.url, onSubmitted: (_) => open(), decoration: const InputDecoration(hintText: 'https://youtu.be/...', labelText: 'YouTube bağlantısı', prefixIcon: Icon(Icons.link))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: open, icon: const Icon(Icons.play_arrow), label: const Text('İzle')),
      if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!)),
      if (web != null) ...[
        const SizedBox(height: 20),
        SizedBox(height: 240, child: Stack(children: [Positioned.fill(child: WebViewWidget(controller: web!)), if (loading) const Center(child: CircularProgressIndicator())])),
        TextButton.icon(onPressed: () => launchUrl(Uri.https('www.youtube.com', '/watch', {'v': videoId!}), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new), label: const Text('YouTube’da aç')),
      ],
    ]),
  );
}
