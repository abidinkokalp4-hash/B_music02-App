import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/social_service.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_hub_screen.dart';
import '../community/community_hub_screen.dart';
import '../profile/profile_screen.dart';
import 'discover_screen.dart';
import 'global_mini_player.dart';
import 'home_dashboard_screen.dart';
import 'local_music_screen.dart';
import 'music_tools_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.onSignedOut,
  });

  final Future<void> Function()? onSignedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _checkingAccount = true;
  String _accountStatus = 'active';
  DateTime? _suspendedUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SocialService.instance.touchLastSeen();
    _checkAccountStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SocialService.instance.touchLastSeen();
      _checkAccountStatus();
    }
  }

  Future<void> _checkAccountStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _checkingAccount = false);
      return;
    }

    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('account_status, suspended_until')
          .eq('id', user.id)
          .single();
      if (!mounted) return;
      setState(() {
        _accountStatus = row['account_status']?.toString() ?? 'active';
        _suspendedUntil = DateTime.tryParse(row['suspended_until']?.toString() ?? '')?.toLocal();
        _checkingAccount = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingAccount = false);
    }
  }

  bool get _isRestricted {
    if (_accountStatus == 'banned') return true;
    if (_accountStatus != 'suspended') return false;
    final until = _suspendedUntil;
    return until == null || until.isAfter(DateTime.now());
  }

  Future<void> _signOutRestricted() async {
    if (widget.onSignedOut != null) {
      await widget.onSignedOut!();
    } else {
      await Supabase.instance.client.auth.signOut();
    }
  }

  void _select(int index) {
    if (!mounted) return;
    setState(() => _index = index);
  }

  void _openDiscover() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiscoverScreen()),
    );
  }

  void _openInsights() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MusicToolsScreen()),
    );
  }

  List<Widget> get _screens => [
        HomeDashboardScreen(
          onOpenMusic: () => _select(1),
          onOpenCommunity: () => _select(2),
          onOpenChat: () => _select(3),
          onOpenProfile: () => _select(4),
          onOpenDiscover: _openDiscover,
          onOpenInsights: _openInsights,
        ),
        const LocalMusicScreen(),
        const CommunityHubScreen(),
        const ChatHubScreen(),
        const ProfileScreen(),
      ];

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Ana Sayfa'),
    _NavItem(icon: Icons.library_music_rounded, label: 'Müzik'),
    _NavItem(icon: Icons.groups_2_rounded, label: 'Topluluk'),
    _NavItem(icon: Icons.chat_bubble_rounded, label: 'Sohbet'),
    _NavItem(icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_checkingAccount) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (_isRestricted) {
      final banned = _accountStatus == 'banned';
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    banned ? Icons.block_rounded : Icons.timer_off_rounded,
                    size: 66,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    banned ? 'Hesap erişimi durduruldu' : 'Hesabın geçici olarak askıya alındı',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    banned
                        ? 'Topluluk kurallarının ciddi veya tekrarlanan ihlali nedeniyle bu hesap B_music02 özelliklerine erişemiyor.'
                        : _suspendedUntil == null
                            ? 'Moderasyon incelemesi nedeniyle hesabın geçici olarak kısıtlandı.'
                            : 'Kısıtlama bitişi: ${_suspendedUntil!.day}.${_suspendedUntil!.month}.${_suspendedUntil!.year} ${_suspendedUntil!.hour.toString().padLeft(2, '0')}:${_suspendedUntil!.minute.toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: _checkAccountStatus,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Durumu Yenile'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _signOutRestricted,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Oturumu Kapat'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: false,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlobalMiniPlayer(onOpenMusic: () => _select(1)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 72,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xEE111111),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: List.generate(
                        _items.length,
                        (index) => Expanded(
                          child: _NavButton(
                            item: _items[index],
                            selected: index == _index,
                            onTap: () => _select(index),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFDF7E), Color(0xFFD4AF57)],
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.24),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: selected ? 23 : 21,
              color: selected ? Colors.black : Colors.white38,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white38,
                  fontSize: 8,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
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
