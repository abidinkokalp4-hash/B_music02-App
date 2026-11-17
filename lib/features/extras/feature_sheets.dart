import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_text.dart';
import '../../core/platform/feature_bridge.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/night_light.dart';
import '../../core/services/player_preferences.dart';
import '../../core/services/playlist_qr.dart';

const _purple = Color(0xFFB65CFF);
const _sheet = Color(0xFF17131F);
const _amber = Color(0xFFFF9F2E);

// ---------------------------------------------------------------- Gece ışığı
Future<void> showNightLightSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: _sheet,
      showDragHandle: true,
      builder: (c) => ListenableBuilder(
        listenable: NightLight.instance,
        builder: (c, _) {
          final n = NightLight.instance;
          final warmLabel = n.warmth < .34
              ? 'Soğuk'
              : n.warmth < .67
                  ? 'Ilık'
                  : 'Sıcak';
          Widget slider(String label, double value, ValueChanged<double> onEnd,
                  String trailing, {double min = 0}) =>
              Row(children: [
                SizedBox(
                    width: 84,
                    child: AppText(label,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600))),
                Expanded(
                    child: SliderTheme(
                  data: SliderTheme.of(c).copyWith(
                      activeTrackColor: _amber,
                      thumbColor: _amber,
                      inactiveTrackColor: Colors.white24),
                  child: Slider(value: value, min: min, max: 1, onChanged: onEnd),
                )),
                SizedBox(
                    width: 44,
                    child: AppText(trailing,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            color: _amber, fontWeight: FontWeight.w800))),
              ]);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.nightlight_round, color: _amber),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: AppText('Gece ışığı',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800))),
                    Switch(
                        value: n.enabled,
                        activeThumbColor: Colors.white,
                        activeTrackColor: _purple,
                        onChanged: n.setEnabled),
                  ]),
                  const SizedBox(height: 4),
                  const AppText(
                      'Müzik çalarken ekran sıcak ve kısık ışık verir. Uyurken göz yormaz.',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  slider('Parlaklık', n.brightness, n.setBrightness,
                      '${(n.brightness * 100).round()}%', min: .1),
                  slider('Sıcaklık', n.warmth, n.setWarmth, tr(warmLabel)),
                  const SizedBox(height: 6),
                  const AppText('Otomatik kapanma',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final (minutes, label) in [
                      (15, '15 dk'),
                      (30, '30 dk'),
                      (45, '45 dk'),
                      (60, '1 saat')
                    ]) ...[
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            if (!n.enabled) n.setEnabled(true);
                            n.setAutoOff(n.autoOffMinutes == minutes ? null : minutes);
                          },
                          child: Container(
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: n.autoOffMinutes == minutes
                                    ? const Color(0xFFC2611A)
                                    : const Color(0xFF1B1C25),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: n.autoOffMinutes == minutes
                                        ? _amber
                                        : const Color(0xFF30253F))),
                            child: AppText(label,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      if (minutes != 60) const SizedBox(width: 8),
                    ],
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );

// ------------------------------------------------------------ Ses yükseltici
class VolumeBoosterCard extends StatelessWidget {
  const VolumeBoosterCard({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: PlayerPreferences.instance,
        builder: (c, _) {
          final percent = FeatureBridge.boostPercent;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.bolt_rounded, color: _purple),
                const SizedBox(width: 10),
                const Expanded(
                    child: AppText('Ses yükseltici',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                Text('$percent%',
                    style: const TextStyle(
                        color: _purple, fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 6),
              const AppText(
                  '100% üzeri sesi güçlendirir. Çok yüksek değerler bozulmaya yol açabilir.',
                  style: TextStyle(fontSize: 11)),
              Slider(
                value: percent.toDouble(),
                min: 100,
                max: 200,
                divisions: 20,
                label: '$percent%',
                activeColor: _purple,
                onChanged: (v) async {
                  await PlayerPreferences.instance.set('volumeBoost', v.round());
                  await FeatureBridge.applyBoost();
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('100%', style: TextStyle(fontSize: 11)),
                  Text('150%', style: TextStyle(fontSize: 11)),
                  Text('200%', style: TextStyle(fontSize: 11)),
                ]),
              ),
            ]),
          );
        },
      );
}

// ----------------------------------------------------- Mini müzik baloncuğu
/// Turns the floating bubble on/off; asks for "display over other apps".
Future<void> setMusicBubble(BuildContext context, bool on) async {
  await PlayerPreferences.instance.set('musicBubble', on);
  if (on && !await FeatureBridge.canDrawOverlays() && context.mounted) {
    final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const AppText('Mini müzik baloncuğu'),
              content: const AppText(
                  'Baloncuğun başka uygulamaların üstünde görünmesi için “Diğer uygulamaların üzerinde göster” iznini aç.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const AppText('İptal')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const AppText('İzni aç')),
              ],
            ));
    if (go == true) await FeatureBridge.requestOverlay();
  }
  await FeatureBridge.pushBubble();
}

// ------------------------------------------------------------- QR listeler
Future<void> showPlaylistQr(BuildContext context, String name) async {
  final music = LocalMusicService.instance;
  final songs = music.playlistSongs(name);
  if (songs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Önce listeye şarkı ekle')));
    return;
  }
  final link = PlaylistQr.encode(name, songs);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: _sheet,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppText('QR ile paylaş',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: QrImageView(
              data: link,
              size: 210,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.L,
            ),
          ),
          const SizedBox(height: 14),
          Text(name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const AppText('Bu kodu okutan kişi listeyi B Music’te açabilir.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          if (songs.length > PlaylistQr.maxSongs)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AppText(tf('İlk {0} şarkı paylaşılır', [PlaylistQr.maxSongs]),
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: () {
                    Navigator.pop(c);
                    scanPlaylistQr(context);
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const AppText('QR okut')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _shareQr(name, link),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const AppText('Paylaş')),
            ),
          ]),
        ]),
      ),
    ),
  );
}

Future<void> _shareQr(String name, String link) async {
  File? file;
  try {
    final painter = QrPainter(
        data: link,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square, color: Colors.black));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 900.0, pad = 60.0;
    canvas.drawRect(const Rect.fromLTWH(0, 0, size + pad * 2, size + pad * 2),
        Paint()..color = Colors.white);
    canvas.translate(pad, pad);
    painter.paint(canvas, const Size(size, size));
    final image = await recorder
        .endRecording()
        .toImage((size + pad * 2).toInt(), (size + pad * 2).toInt());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    file = File('${dir.path}/b_music_liste_qr.png');
    await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
  } catch (_) {}
  await SharePlus.instance.share(ShareParams(
      text: '🎶 $name · B Music\n$link',
      files: file == null ? null : [XFile(file.path, mimeType: 'image/png')]));
}

Future<void> scanPlaylistQr(BuildContext context) async {
  String? raw;
  try {
    raw = await FeatureBridge.scanQr();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: AppText('QR okuyucu açılamadı. Google Play hizmetlerini güncelleyin.')));
    }
    return;
  }
  if (raw == null || !context.mounted) return;
  final shared = PlaylistQr.decode(raw);
  if (shared == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Bu QR kod bir B Music listesi değil')));
    return;
  }
  await importSharedPlaylist(context, shared);
}

Future<void> importSharedPlaylist(BuildContext context, SharedPlaylist shared) async {
  final music = LocalMusicService.instance;
  if (music.songs.isEmpty) await music.requestPermissionAndLoad();
  final found = PlaylistQr.match(shared, music.songs);
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
            title: Text(shared.name),
            content: AppText(found.isEmpty
                ? 'Bu listedeki şarkılar telefonunda bulunamadı.'
                : tf('{0} / {1} şarkı telefonunda bulundu. Liste eklensin mi?',
                    [found.length, shared.songs.length])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const AppText('İptal')),
              if (found.isNotEmpty)
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const AppText('Listeyi ekle')),
            ],
          ));
  if (ok != true) return;
  final name = PlaylistQr.uniqueName(shared.name, music.playlists.keys);
  await music.createPlaylist(name);
  await music.addSongsToPlaylist(name, found);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(tf('{0} listesi eklendi', [name]))));
  }
}
