import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/local_music_service.dart';
import '../../core/services/video_library.dart';
import '../../core/platform/device_controls.dart';

class MusicPermissionGate extends StatefulWidget {
  const MusicPermissionGate({super.key, required this.child});
  final Widget child;
  @override
  State<MusicPermissionGate> createState() => _Gate();
}

class _Gate extends State<MusicPermissionGate> {
  static const keyName = 'b_music02_music_permissions_onboarding_v3';
  bool? done;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => done = p.getBool(keyName) ?? false);
  }

  Future<void> finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(keyName, true);
    if (mounted) setState(() => done = true);
  }

  @override
  Widget build(BuildContext c) => done == null
      ? const Scaffold(body: Center(child: CircularProgressIndicator()))
      : done!
      ? widget.child
      : MusicPermissionsScreen(firstRun: true, onContinue: finish);
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
  State<MusicPermissionsScreen> createState() => _Permissions();
}

class _Permissions extends State<MusicPermissionsScreen>
    with WidgetsBindingObserver {
  bool audio = false,
      video = false,
      notification = false,
      battery = false,
      busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      final a = await LocalMusicService.instance.audioQuery.permissionsStatus();
      final v = await PhotoManager.getPermissionState(
        requestOption: VideoLibrary.permission,
      );
      final n = await Permission.notification.status;
      final info = await DeviceControls.info();
      if (mounted)
        setState(() {
          audio = a;
          video = v.hasAccess;
          notification = n.isGranted;
          battery = info['batteryUnrestricted'] == true;
        });
    } catch (_) {
      /* Permissions remain off if unavailable. */
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'İzin işlemi tamamlanamadı. Telefon ayarlarını kontrol edin.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> requestAudio() async {
    if (audio) {
      await openAppSettings();
      return;
    }
    await LocalMusicService.instance.requestPermissionAndLoad(request: true);
  }

  Future<void> requestVideo() async {
    if (video) {
      await openAppSettings();
      return;
    }
    final p = await PhotoManager.requestPermissionExtend(
      requestOption: VideoLibrary.permission,
    );
    if (!p.hasAccess) await PhotoManager.openSetting();
  }

  Future<void> requestNotification() async {
    if (notification) {
      await DeviceControls.settings('notification');
      return;
    }
    final p = await Permission.notification.request();
    if (p.isPermanentlyDenied) await DeviceControls.settings('notification');
  }

  Future<void> all() async {
    await LocalMusicService.instance.requestPermissionAndLoad(request: true);
    await PhotoManager.requestPermissionExtend(
      requestOption: VideoLibrary.permission,
    );
    await Permission.notification.request();
    await refresh();
    if (!battery) await DeviceControls.settings('battery');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.firstRun ? null : AppBar(title: const Text('İzinler')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
          children: [
            Image.asset('assets/images/b_music02_logo.png', height: 76),
            const Text(
              'B_music02',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(
              'Müzik ve video her zaman seninle',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            const Text(
              'Müziğin için gereken izinler',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              'B_music02 artık hesap, kamera veya mikrofon istemez. Telefonda bulunan müzikleri ve videoları göstermek için aşağıdaki izinler gereklidir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 18),
            tile(
              Icons.verified_user,
              'Tüm izinleri ver',
              'Gerekli izinleri sırayla aç',
              audio && video && notification && battery,
              all,
              highlight: true,
            ),
            tile(
              Icons.music_note,
              'Telefonundaki müzikler',
              'Şarkıları listelemek ve çalmak için gereklidir.',
              audio,
              requestAudio,
            ),
            tile(
              Icons.play_circle_outline,
              'Telefonundaki videolar',
              'Videoları listelemek ve oynatmak için gereklidir.',
              video,
              requestVideo,
            ),
            tile(
              Icons.notifications_none,
              'Müzik bildirimi',
              'Oynatma kontrolleri için isteğe bağlıdır.',
              notification,
              requestNotification,
            ),
            tile(
              Icons.nightlight_round,
              'Arka planda çalışma',
              'Pil kısıtlamalarını telefon ayarlarından yönet.',
              battery,
              () => DeviceControls.settings('battery'),
            ),
            tile(
              Icons.lock_outline,
              'Kilit ekranı kontrolleri',
              'Bildirim ve kilit ekranı görünürlüğünü yönet.',
              notification,
              () => DeviceControls.settings('lock'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : openAppSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Telefon ayarlarını aç'),
            ),
            if (widget.firstRun) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: busy ? null : widget.onContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Uygulamaya devam et'),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'İzinleri daha sonra Ayarlar bölümünden de değiştirebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget tile(
    IconData icon,
    String title,
    String sub,
    bool enabled,
    Future<void> Function() action, {
    bool highlight = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.primary.withValues(alpha: .12)
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? scheme.primary : scheme.outline),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onTap: busy ? null : () => run(action),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scheme.primary, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Text(
          sub,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        trailing: Switch(
          value: enabled,
          onChanged: busy ? null : (_) => run(action),
        ),
      ),
    );
  }
}
