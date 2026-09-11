import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/video_item.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, required this.onTap});

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF231725), Color(0xFF14141C)],
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [AppColors.burgundy, Color(0xFF2D1634)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, size: 54, color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(video.artist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.open_in_new_rounded, size: 15, color: AppColors.gold),
                  SizedBox(width: 5),
                  Text('TikTok’ta izle', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
