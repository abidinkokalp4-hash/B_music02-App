import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'community_posts_screen.dart';
import 'community_screen.dart';
import 'social_community_screen.dart';

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _HubTab(
                        selected: _index == 0,
                        icon: Icons.video_library_rounded,
                        label: 'Videolar',
                        onTap: () => setState(() => _index = 0),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _HubTab(
                        selected: _index == 1,
                        icon: Icons.dynamic_feed_rounded,
                        label: 'Akış',
                        onTap: () => setState(() => _index = 1),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _HubTab(
                        selected: _index == 2,
                        icon: Icons.groups_2_rounded,
                        label: 'Sosyal',
                        onTap: () => setState(() => _index = 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                CommunityScreen(),
                CommunityPostsScreen(),
                SocialCommunityScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTab extends StatelessWidget {
  const _HubTab({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? AppColors.gold : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.black : Colors.white54,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white54,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
