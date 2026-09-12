import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../community/community_screen.dart';
import '../profile/profile_screen.dart';
import 'discover_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.onSignedOut,
  });

  final VoidCallback onSignedOut;

  @override
  State<HomeShell> createState() =>
      _HomeShellState();
}

class _HomeShellState
    extends State<HomeShell> {
  static const _gold =
      Color(0xFFD4AF57);

  static const _background =
      Color(0xFF080808);

  static const _barColor =
      Color(0xFF101010);

  int _index = 0;

  late final List<Widget> _screens = [
    const HomeScreen(),
    const DiscoverScreen(),
    const CommunityScreen(),
    const ChatScreen(),
    ProfileScreen(
      onSignedOut:
          widget.onSignedOut,
    ),
  ];

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _background,

      body: IndexedStack(
        index: _index,
        children: _screens,
      ),

      bottomNavigationBar:
          Container(
        decoration:
            const BoxDecoration(
          color: _barColor,
          border: Border(
            top: BorderSide(
              color:
                  Color(0xFF242424),
              width: 0.7,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data:
                NavigationBarThemeData(
              backgroundColor:
                  _barColor,

              indicatorColor:
                  _gold.withOpacity(
                0.13,
              ),

              height: 70,

              labelTextStyle:
                  WidgetStateProperty
                      .resolveWith(
                (states) {
                  final selected =
                      states.contains(
                    WidgetState
                        .selected,
                  );

                  return TextStyle(
                    color: selected
                        ? _gold
                        : Colors
                            .white54,
                    fontSize: 10,
                    fontWeight:
                        selected
                            ? FontWeight
                                .w800
                            : FontWeight
                                .w500,
                  );
                },
              ),

              iconTheme:
                  WidgetStateProperty
                      .resolveWith(
                (states) {
                  final selected =
                      states.contains(
                    WidgetState
                        .selected,
                  );

                  return IconThemeData(
                    color: selected
                        ? _gold
                        : Colors
                            .white54,
                    size:
                        selected
                            ? 26
                            : 24,
                  );
                },
              ),
            ),

            child: NavigationBar(
              selectedIndex:
                  _index,

              labelBehavior:
                  NavigationDestinationLabelBehavior
                      .alwaysShow,

              onDestinationSelected:
                  (value) {
                setState(() {
                  _index =
                      value;
                });
              },

              destinations:
                  const [
                NavigationDestination(
                  icon: Icon(
                    Icons
                        .home_outlined,
                  ),
                  selectedIcon:
                      Icon(
                    Icons
                        .home_rounded,
                  ),
                  label:
                      'Ana Sayfa',
                ),

                NavigationDestination(
                  icon: Icon(
                    Icons
                        .explore_outlined,
                  ),
                  selectedIcon:
                      Icon(
                    Icons
                        .explore_rounded,
                  ),
                  label:
                      'Keşfet',
                ),

                NavigationDestination(
                  icon: Icon(
                    Icons
                        .video_library_outlined,
                  ),
                  selectedIcon:
                      Icon(
                    Icons
                        .video_library_rounded,
                  ),
                  label:
                      'Topluluk',
                ),

                NavigationDestination(
                  icon: Icon(
                    Icons
                        .chat_bubble_outline_rounded,
                  ),
                  selectedIcon:
                      Icon(
                    Icons
                        .chat_bubble_rounded,
                  ),
                  label:
                      'Sohbet',
                ),

                NavigationDestination(
                  icon: Icon(
                    Icons
                        .person_outline_rounded,
                  ),
                  selectedIcon:
                      Icon(
                    Icons
                        .person_rounded,
                  ),
                  label:
                      'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
