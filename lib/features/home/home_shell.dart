import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../chat/chat_screen.dart';
import '../community/community_screen.dart';
import '../profile/profile_screen.dart';
import 'discover_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.onSignedOut,
  });

  final Future<void> Function()?
      onSignedOut;

  @override
  State<HomeShell> createState() =>
      _HomeShellState();
}

class _HomeShellState
    extends State<HomeShell> {
  int _index = 0;

  final List<Widget> _screens =
      const [
    HomeScreen(),
    DiscoverScreen(),
    CommunityScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  final List<_NavItem> _items =
      const [
    _NavItem(
      icon:
          Icons.home_rounded,
      label:
          'Ana Sayfa',
    ),
    _NavItem(
      icon:
          Icons.download_rounded,
      label:
          'İndir',
    ),
    _NavItem(
      icon:
          Icons.video_library_rounded,
      label:
          'Topluluk',
    ),
    _NavItem(
      icon:
          Icons.chat_bubble_rounded,
      label:
          'Sohbet',
    ),
    _NavItem(
      icon:
          Icons.person_rounded,
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
      body: IndexedStack(
        index:
            _index,
        children:
            _screens,
      ),
      bottomNavigationBar:
          SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            18,
            0,
            18,
            12,
          ),
          child:
              ClipRRect(
            borderRadius:
                BorderRadius.circular(
              34,
            ),
            child:
                BackdropFilter(
              filter:
                  ImageFilter.blur(
                sigmaX: 18,
                sigmaY: 18,
              ),
              child:
                  Container(
                height: 76,
                padding:
                    const EdgeInsets
                        .all(
                  7,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xEE111111,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    34,
                  ),
                  border:
                      Border.all(
                    color:
                        AppColors.gold
                            .withOpacity(
                      0.18,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black
                              .withOpacity(
                        0.45,
                      ),
                      blurRadius:
                          28,
                      offset:
                          const Offset(
                        0,
                        8,
                      ),
                    ),
                  ],
                ),
                child:
                    Row(
                  children:
                      List.generate(
                    _items.length,
                    (
                      index,
                    ) {
                      return Expanded(
                        child:
                            _NavButton(
                          item:
                              _items[
                                  index],
                          selected:
                              index ==
                                  _index,
                          onTap:
                              () {
                            setState(() {
                              _index =
                                  index;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton
    extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap:
          onTap,
      behavior:
          HitTestBehavior.opaque,
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 220,
        ),
        curve:
            Curves.easeOut,
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(
            27,
          ),
          gradient:
              selected
                  ? const LinearGradient(
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment.bottomRight,
                      colors: [
                        Color(
                          0xFFFFDF7E,
                        ),
                        Color(
                          0xFFD4AF57,
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
                          0.24,
                        ),
                        blurRadius:
                            20,
                      ),
                    ]
                  : null,
        ),
        child:
            Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size:
                  selected
                      ? 25
                      : 23,
              color:
                  selected
                      ? Colors.black
                      : Colors.white38,
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              item.label,
              style:
                  TextStyle(
                color:
                    selected
                        ? Colors.black
                        : Colors.white38,
                fontSize:
                    9,
                fontWeight:
                    selected
                        ? FontWeight.w900
                        : FontWeight.w600,
              ),
            ),
          ],
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
