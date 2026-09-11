import 'package:flutter/material.dart';

import '../ads/ads_screen.dart';
import '../chat/chat_screen.dart';
import '../community/community_screen.dart';
import '../profile/profile_screen.dart';
import '../requests/requests_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.onSignedOut,
  });

  final VoidCallback onSignedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _screens = [
    const HomeScreen(),
    const _DiscoverScreen(),
    const CommunityScreen(),
    const ChatScreen(),
    ProfileScreen(
      onSignedOut: widget.onSignedOut,
    ),
  ];

  void _openMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'B_music02',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _menuItem(
                  icon: Icons.upload_file_outlined,
                  title: 'Bana Gönder',
                  subtitle:
                      'B_music02 yönetimine özel video gönder',
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const _PrivateSendScreen(),
                      ),
                    );
                  },
                ),
                _menuItem(
                  icon: Icons.music_note_outlined,
                  title: 'Talepler',
                  subtitle:
                      'Şarkı ve içerik talebi gönder',
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const RequestsScreen(),
                      ),
                    );
                  },
                ),
                _menuItem(
                  icon: Icons.campaign_outlined,
                  title: 'Reklam Ver',
                  subtitle:
                      'Reklam başvurusu oluştur',
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AdsScreen(),
                      ),
                    );
                  },
                ),
                _menuItem(
                  icon: Icons.settings_outlined,
                  title: 'Ayarlar',
                  subtitle:
                      'Uygulama tercihlerini yönet',
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const _SettingsScreen(),
                      ),
                    );
                  },
                ),
                _menuItem(
                  icon: Icons.info_outline,
                  title: 'Hakkımızda',
                  subtitle:
                      'B_music02 hakkında bilgi',
                  onTap: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const _AboutScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            const Color(0xFFD4AF37).withOpacity(0.12),
        child: Icon(
          icon,
          color: const Color(0xFFD4AF37),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(subtitle),
      trailing:
          const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: _screens,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Material(
              color: Colors.black.withOpacity(0.55),
              borderRadius:
                  BorderRadius.circular(16),
              child: IconButton(
                tooltip: 'Daha Fazla',
                onPressed: _openMoreMenu,
                icon: const Icon(
                  Icons.more_horiz,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        backgroundColor:
            const Color(0xFF111111),
        indicatorColor:
            const Color(0xFFD4AF37)
                .withOpacity(0.18),
        labelBehavior:
            NavigationDestinationLabelBehavior
                .onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home,
              color: Color(0xFFD4AF37),
            ),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.explore_outlined,
            ),
            selectedIcon: Icon(
              Icons.explore,
              color: Color(0xFFD4AF37),
            ),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.video_collection_outlined,
            ),
            selectedIcon: Icon(
              Icons.video_collection,
              color: Color(0xFFD4AF37),
            ),
            label: 'Sizden Gelenler',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.chat_bubble_outline,
            ),
            selectedIcon: Icon(
              Icons.chat_bubble,
              color: Color(0xFFD4AF37),
            ),
            label: 'Sohbet',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon: Icon(
              Icons.person,
              color: Color(0xFFD4AF37),
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _DiscoverScreen extends StatelessWidget {
  const _DiscoverScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.explore,
                  size: 86,
                  color: Color(0xFFD4AF37),
                ),
                SizedBox(height: 20),
                Text(
                  'Keşfet',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'B_music02 videolarının tam ekran kaydırmalı keşfet akışı burada olacak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
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

class _PrivateSendScreen
    extends StatelessWidget {
  const _PrivateSendScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bana Gönder',
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 76,
                color: Color(0xFFD4AF37),
              ),
              SizedBox(height: 20),
              Text(
                'Özel Video Gönderimi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Buradan gönderilecek videolar yalnızca B_music02 yöneticisi tarafından görülecek.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsScreen
    extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(
              Icons.notifications_outlined,
            ),
            title: Text(
              'Bildirimler',
            ),
            subtitle: Text(
              'Bildirim tercihleri',
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(
              Icons.security_outlined,
            ),
            title: Text(
              'Gizlilik ve Güvenlik',
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hakkımızda',
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/b_music02_logo.png',
                width: 130,
                height: 130,
              ),
              const SizedBox(height: 22),
              const Text(
                'B_music02',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Müziğin Kalbinde',
                style: TextStyle(
                  color:
                      Color(0xFFD4AF37),
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Müzik içeriklerini ve topluluğu bir araya getiren B_music02 mobil uygulaması.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
