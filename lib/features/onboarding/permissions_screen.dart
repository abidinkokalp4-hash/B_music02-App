import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/local_music_service.dart';
import '../../core/theme/app_theme.dart';

class PermissionGate extends StatefulWidget {
  const PermissionGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  static const String _doneKey = 'b_music02_permissions_onboarding_v1';
  bool? _done;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _done = prefs.getBool(_doneKey) ?? false;
    });
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
    if (!mounted) return;
    setState(() {
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF080808),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    if (_done == true) {
      return widget.child;
    }

    return PermissionsCenterScreen(
      firstRun: true,
      onContinue: _finish,
    );
  }
}

class PermissionsCenterScreen extends StatefulWidget {
  const PermissionsCenterScreen({
    super.key,
    this.firstRun = false,
    this.onContinue,
  });

  final bool firstRun;
  final Future<void> Function()? onContinue;

  @override
  State<PermissionsCenterScreen> createState() =>
      _PermissionsCenterScreenState();
}

class _PermissionsCenterScreenState extends State<PermissionsCenterScreen>
    with WidgetsBindingObserver {
  final LocalMusicService _music = LocalMusicService.instance;

  bool _loading = true;
  bool _musicAllowed = false;
  PermissionStatus _notification = PermissionStatus.denied;
  PermissionStatus _camera = PermissionStatus.denied;
  PermissionStatus _microphone = PermissionStatus.denied;

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
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });

    try {
      final musicAllowed = await _music.audioQuery.permissionsStatus();
      final notification = await Permission.notification.status;
      final camera = await Permission.camera.status;
      final microphone = await Permission.microphone.status;

      if (!mounted) return;
      setState(() {
        _musicAllowed = musicAllowed;
        _notification = notification;
        _camera = camera;
        _microphone = microphone;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestMusic() async {
    await _music.requestPermissionAndLoad(request: true);
    await _refresh();
  }

  Future<void> _request(Permission permission) async {
    final status = await permission.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
    }
    await _refresh();
  }

  Future<void> _requestMissing() async {
    if (!_musicAllowed) {
      await _requestMusic();
    }
    if (Platform.isAndroid && !_notification.isGranted) {
      await _request(Permission.notification);
    }
    if (!_camera.isGranted) {
      await _request(Permission.camera);
    }
    if (!_microphone.isGranted) {
      await _request(Permission.microphone);
    }
  }

  String _statusText(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return 'Açık';
    if (status.isPermanentlyDenied || status.isRestricted) {
      return 'Ayarlardan aç';
    }
    return 'Kapalı';
  }

  Color _statusColor(bool enabled) {
    return enabled ? const Color(0xFF49D17D) : const Color(0xFFE1A34A);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: widget.firstRun
          ? null
          : AppBar(
              title: const Text('İzinler ve Gizlilik'),
              backgroundColor: const Color(0xFF080808),
              foregroundColor: Colors.white,
            ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                children: [
                  if (widget.firstRun) ...[
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.gold,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'B_music02 İzinleri',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'İzinları sen seçersin. Her izin yalnızca ilgili özelliği kullanmak için istenir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        height: 1.45,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                  _PermissionTile(
                    icon: Icons.library_music_rounded,
                    title: 'Müzik ve ses dosyaları',
                    subtitle: 'Telefondaki şarkıları Müziklerim bölümünde göstermek için.',
                    status: _musicAllowed ? 'Açık' : 'Kapalı',
                    enabled: _musicAllowed,
                    onTap: _musicAllowed ? null : _requestMusic,
                  ),
                  _PermissionTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Bildirimler',
                    subtitle: 'Mesaj, topluluk ve medya kontrollerini göstermek için.',
                    status: _statusText(_notification),
                    enabled: _notification.isGranted,
                    onTap: _notification.isGranted
                        ? null
                        : () => _request(Permission.notification),
                  ),
                  _PermissionTile(
                    icon: Icons.camera_alt_rounded,
                    title: 'Kamera',
                    subtitle: 'Profil ve topluluk içeriklerinde kamera kullanmak için.',
                    status: _statusText(_camera),
                    enabled: _camera.isGranted,
                    onTap: _camera.isGranted
                        ? null
                        : () => _request(Permission.camera),
                  ),
                  _PermissionTile(
                    icon: Icons.mic_rounded,
                    title: 'Mikrofon',
                    subtitle: 'Sesli mesaj ve ileride sesli içerik kaydı için.',
                    status: _statusText(_microphone),
                    enabled: _microphone.isGranted,
                    onTap: _microphone.isGranted
                        ? null
                        : () => _request(Permission.microphone),
                  ),
                  _PermissionTile(
                    icon: Icons.photo_library_rounded,
                    title: 'Fotoğraf ve video seçimi',
                    subtitle:
                        'B_music02 Android sistem seçicisini kullanır; tüm galeriye sürekli erişim istemez.',
                    status: 'Sistem seçicisi',
                    enabled: true,
                    onTap: null,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _requestMissing,
                    icon: const Icon(Icons.fact_check_rounded),
                    label: const Text('Eksik izinları kontrol et'),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: openAppSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Telefon ayarlarını aç'),
                  ),
                  if (widget.firstRun) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: widget.onContinue == null
                            ? null
                            : () async {
                                await widget.onContinue!();
                              },
                        child: const Text(
                          'Devam Et',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Zorunlu olmayan izinları vermeden de uygulamaya devam edebilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 10),
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
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = enabled
        ? const Color(0xFF49D17D)
        : const Color(0xFFE1A34A);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: () async {
                await onTap!();
              },
              child: const Text('İzin Ver'),
            )
          else
            Icon(
              enabled ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: statusColor,
            ),
        ],
      ),
    );
  }
}
