import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/platform/device_controls.dart';
import '../../core/services/app_update_service.dart';

/// "Yeni sürüm var" dialog: download the APK with progress, then install.
class UpdatePrompt {
  static bool _showing = false;

  /// Called once after start-up: checks GitHub (at most every 12 h) unless
  /// Google Play installed the app.
  static Future<void> checkOnStart(BuildContext context) async {
    final service = AppUpdateService.instance;
    final info = await service.info();
    if (info['fromPlay'] == true) {
      debugPrint('[BMusic feature] updater disabled (installer=${info['installer']})');
      return;
    }
    final device = await DeviceControls.info().catchError((Object _) => <String, dynamic>{});
    final build = (device['build'] as num?)?.toInt() ?? 0;
    if (build <= 0) return;
    final release = await service.check(currentBuild: build);
    if (release == null || await service.skipped(release) || !context.mounted) return;
    await show(context, release);
  }

  static Future<void> show(BuildContext context, AppRelease release) async {
    if (_showing) return;
    _showing = true;
    try {
      await showDialog<void>(
          context: context, barrierDismissible: false, builder: (_) => _UpdateDialog(release: release));
    } finally {
      _showing = false;
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.release});
  final AppRelease release;
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> with WidgetsBindingObserver {
  final service = AppUpdateService.instance;
  File? apk;
  bool busy = false, waitingPermission = false;
  String? error;

  @override
  void initState() {
    super.initState();
    service.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    service.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from "Bilinmeyen uygulamaları yükle": continue with the installer.
    if (state == AppLifecycleState.resumed && waitingPermission && apk != null) {
      waitingPermission = false;
      unawaited(install());
    }
  }

  Future<void> download() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      apk = await service.download(widget.release);
      await install();
    } catch (e) {
      error = 'İndirilemedi. İnternet bağlantını kontrol edip tekrar dene.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> install() async {
    try {
      final result = await service.install(apk!);
      if (result == 'permission') {
        waitingPermission = true;
        error = 'B Music\'in uygulama yüklemesine izin ver, sonra geri dön.';
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      error = 'Kurulum başlatılamadı: $e';
    }
    changed();
  }

  @override
  Widget build(BuildContext context) {
    final progress = service.progress;
    final mb = widget.release.size > 0 ? ' · ${(widget.release.size / 1048576).toStringAsFixed(1)} MB' : '';
    return AlertDialog(
      icon: const Icon(Icons.system_update_rounded, size: 34),
      title: const Text('Yeni sürüm var'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('B Music ${widget.release.tag.replaceFirst('v', '')}$mb',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (widget.release.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(widget.release.notes, style: const TextStyle(fontSize: 12, height: 1.35)),
          ],
          if (busy) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(progress == null ? 'Hazırlanıyor…' : 'İndiriliyor %${(progress * 100).round()}',
                style: const TextStyle(fontSize: 12)),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: busy
              ? null
              : () {
                  unawaited(service.skip(widget.release));
                  Navigator.pop(context);
                },
          child: const Text('Sonra'),
        ),
        FilledButton(
          onPressed: busy ? null : (apk != null ? install : download),
          child: Text(apk != null ? 'Kur' : 'İndir ve kur'),
        ),
      ],
    );
  }
}
