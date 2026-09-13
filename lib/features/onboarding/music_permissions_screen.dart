import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';

class MusicPermissionGate extends StatefulWidget {
  const MusicPermissionGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<MusicPermissionGate> createState() => _MusicPermissionGateState();
}

class _MusicPermissionGateState extends State<MusicPermissionGate> {
  static const String _doneKey = 'b_music02_music_permissions_onboarding_v2';
  bool? _done;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _done = prefs.getBool(_doneKey) ?? false);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_done == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    if (_done == true) return widget.child;

    return MusicPermissionsScreen(
      firstRun: true,
      onContinue: _finish,
    );
  }
}

class MusicPermissionsScreen extends StatefulWidget {
  const MusicPermissionsScreen({
    super.key,
    this.firstRun = false,
    this.onContinue,
  });

  final bool firstRun;
  final Future<void> Function()? onContinue;

  @override
  State<MusicPermissionsScreen> createState() => _MusicPermissionsScreenState();
}

class _MusicPermissionsScreenState extends State<MusicPermissionsScreen>
    with WidgetsBindingObserver {
  final LocalMusicService _music = LocalMusicService.instance;

  bool _loading = true;
  bool _musicAllowed = false;
  PermissionStatus _notification = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final musicAllowed = await _music.audioQuery.permissionsStatus();
      final notification = await Permission.notification.status;
      if (!mounted) return;
      setState(() {
        _musicAllowed = musicAllowed;
        _notification = notification;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestMusic() async {
    await _music.requestPermissionAndLoad(request: true);
    await _refresh();
  }

  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
    }
    await _refresh();
  }

  String _notificationStatus() {
    if (_notification.isGranted || _notification.isLimited) return 'Açık';
    if (_notification.isPermanentlyDenied || _notification.isRestricted) {
      return 'Ayarlardan aç';
    }
    return 'Kapalı';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.firstRun ? null : AppBar(title: const Text('İzinler')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  if (widget.firstRun) ...[
                    const Icon(
                      Icons.library_music_rounded,
                      size: 58,
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Müziğin için gereken izinler',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'B_music02 artık hesap, kamera veya mikrofon istemez. Telefonda bulunan müzikleri göstermek için müzik erişimi yeterlidir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  _PermissionTile(
                    icon: Icons.library_music_rounded,
                    title: 'Telefondaki müzikler',
                    subtitle: 'Şarkıları listelemek ve çalmak için gereklidir.',
                    status: _musicAllowed ? 'Açık' : 'Kapalı',
                    enabled: _musicAllowed,
                    onTap: _requestMusic,
                  ),
                  const SizedBox(height: 12),
                  _PermissionTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Müzik bildirimi',
                    subtitle: 'Oynatma kontrolleri için isteğe bağlıdır.',
                    status: _notificationStatus(),
                    enabled: _notification.isGranted || _notification.isLimited,
                    onTap: _requestNotifications,
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Telefon ayarlarını aç'),
                  ),
                  if (widget.firstRun) ...[
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: widget.onContinue,
                      child: const Text('Uygulamaya devam et'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bildirim izni isteğe bağlıdır. Müzik erişimini daha sonra Ayarlar bölümünden de açabilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.gold.withValues(alpha: 0.12),
          child: Icon(icon, color: AppColors.gold),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: enabled ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
