import '../models/video_item.dart';

class DemoRepository {
  static const profileUrl = 'https://www.tiktok.com/@B_music02';

  static const videos = <VideoItem>[
    VideoItem(
      id: 'featured',
      title: 'B_music02 TikTok Sayfası',
      artist: 'Güneydoğu müzikleri',
      tiktokUrl: profileUrl,
      category: 'Yeni',
      featured: true,
    ),
    VideoItem(
      id: 'uzun-hava',
      title: 'Uzun Hava Seçkileri',
      artist: 'B_music02',
      tiktokUrl: profileUrl,
      category: 'Uzun Hava',
    ),
    VideoItem(
      id: 'duygusal',
      title: 'Duygusal Ezgiler',
      artist: 'B_music02',
      tiktokUrl: profileUrl,
      category: 'Duygusal',
    ),
    VideoItem(
      id: 'hareketli',
      title: 'Hareketli Yöresel',
      artist: 'B_music02',
      tiktokUrl: profileUrl,
      category: 'Hareketli',
    ),
  ];
}
