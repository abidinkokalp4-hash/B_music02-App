import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../chat/chat_screen.dart';
import '../community/community_screen.dart';
import '../discover/discover_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
  });

  @override
  State<HomeShell> createState() =>
      _HomeShellState();
}

class _HomeShellState
    extends State<HomeShell> {
  int _currentIndex = 0;

  final List<Widget> _screens =
      const [
    HomeScreen(),
    DiscoverScreen(),
    CommunityScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  static const List<_NavItem>
      _items = [
    _NavItem(
      icon:
          Icons.home_rounded,
      label:
          'Ana Sayfa',
    ),
    _NavItem(
      icon:
          Icons
              .explore_rounded,
      label:
          'Keşfet',
    ),
    _NavItem(
      icon:
          Icons
              .video_library_rounded,
      label:
          'Topluluk',
    ),
    _NavItem(
      icon:
          Icons
              .forum_rounded,
      label:
          'Sohbet',
    ),
    _NavItem(
      icon:
          Icons
              .person_rounded,
      label:
          'Profil',
    ),
  ];

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index:
                  _currentIndex,
              children:
                  _screens,
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: SafeArea(
              top: false,
              child:
                  _GlassBottomNavigation(
                currentIndex:
                    _currentIndex,
                items:
                    _items,
                onTap: (
                  index,
                ) {
                  if (_currentIndex ==
                      index) {
                    return;
                  }

                  setState(() {
                    _currentIndex =
                        index;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBottomNavigation
    extends StatelessWidget {
  const _GlassBottomNavigation({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    final isDark =
        Theme.of(context)
                .brightness ==
            Brightness.dark;

    final textColor =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        30,
      ),
      child: BackdropFilter(
        filter:
            ImageFilter.blur(
          sigmaX: 22,
          sigmaY: 22,
        ),
        child: Container(
          height: 72,
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          decoration:
              BoxDecoration(
            color:
                isDark
                    ? const Color(
                        0xE8171416,
                      )
                    : Colors.white
                        .withOpacity(
                        0.88,
                      ),
            borderRadius:
                BorderRadius
                    .circular(
              30,
            ),
            border:
                Border.all(
              color:
                  isDark
                      ? Colors.white
                          .withOpacity(
                          0.09,
                        )
                      : Colors.black
                          .withOpacity(
                          0.06,
                        ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black
                        .withOpacity(
                  isDark
                      ? 0.42
                      : 0.13,
                ),
                blurRadius: 28,
                offset:
                    const Offset(
                  0,
                  12,
                ),
              ),
              BoxShadow(
                color:
                    AppColors.gold
                        .withOpacity(
                  0.07,
                ),
                blurRadius: 35,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children:
                List.generate(
              items.length,
              (
                index,
              ) {
                final item =
                    items[index];

                final selected =
                    index ==
                        currentIndex;

                return Expanded(
                  child:
                      _BottomNavButton(
                    item:
                        item,
                    selected:
                        selected,
                    textColor:
                        textColor,
                    onTap: () {
                      onTap(
                        index,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton
    extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.textColor,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      behavior:
          HitTestBehavior
              .opaque,
      onTap: onTap,
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 260,
        ),
        curve:
            Curves.easeOutCubic,
        margin:
            const EdgeInsets
                .symmetric(
          horizontal: 2,
        ),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          gradient:
              selected
                  ? const LinearGradient(
                      begin:
                          Alignment
                              .topLeft,
                      end:
                          Alignment
                              .bottomRight,
                      colors: [
                        Color(
                          0xFFF4D77E,
                        ),
                        AppColors.gold,
                        Color(
                          0xFFB98932,
                        ),
                      ],
                    )
                  : null,
          boxShadow:
              selected
                  ? [
                      BoxShadow(
                        color:
                            AppColors.gold
                                .withOpacity(
                          0.32,
                        ),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
        ),
        child: Center(
          child:
              AnimatedSwitcher(
            duration:
                const Duration(
              milliseconds: 220,
            ),
            child:
                selected
                    ? Column(
                        key:
                            const ValueKey(
                          'selected',
                        ),
                        mainAxisSize:
                            MainAxisSize.min,
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            color:
                                Colors.black,
                            size: 23,
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  Colors.black,
                              fontSize: 8,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key:
                            const ValueKey(
                          'normal',
                        ),
                        mainAxisSize:
                            MainAxisSize.min,
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            color:
                                textColor
                                    .withOpacity(
                              0.48,
                            ),
                            size: 22,
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              color:
                                  textColor
                                      .withOpacity(
                                0.45,
                              ),
                              fontSize: 8,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
