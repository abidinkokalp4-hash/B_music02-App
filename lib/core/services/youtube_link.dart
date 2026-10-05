/// Accept only recognized YouTube URL shapes. Never interpolate raw user input
/// into embedded HTML or load an arbitrary URL in the player WebView.
String? youtubeVideoId(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || !['https', 'http'].contains(uri.scheme)) return null;
  final host = uri.host.toLowerCase();
  String? id;
  if (host == 'youtu.be') {
    if (uri.pathSegments.length == 1) id = uri.pathSegments.first;
  } else if (['youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com'].contains(host)) {
    if (uri.path == '/watch') id = uri.queryParameters['v'];
    if (uri.pathSegments.length == 2 && ['shorts', 'embed', 'live'].contains(uri.pathSegments.first)) id = uri.pathSegments.last;
  }
  return id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id) ? id : null;
}
