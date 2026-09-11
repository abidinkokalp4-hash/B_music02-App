class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.tiktokUrl,
    required this.category,
    this.thumbnailUrl,
    this.featured = false,
  });

  final String id;
  final String title;
  final String artist;
  final String tiktokUrl;
  final String category;
  final String? thumbnailUrl;
  final bool featured;
}
