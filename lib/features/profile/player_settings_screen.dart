import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/platform/device_controls.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/services/player_preferences.dart';
import '../../core/services/video_library.dart';
import '../../core/theme/theme_controller.dart';
import '../onboarding/music_permissions_screen.dart';
import 'legal_documents_screen.dart';

class PlayerSettingsScreen extends StatefulWidget {
  const PlayerSettingsScreen({super.key});
  @override
  State<PlayerSettingsScreen> createState() => _Settings();
}

class _Settings extends State<PlayerSettingsScreen> {
  String? page;
  final prefs = PlayerPreferences.instance,
      music = LocalMusicService.instance,
      insights = MusicInsightsService.instance;
  Timer? timer;
  AndroidEqualizerParameters? eq;
  String? eqError;
  bool working = false;
  int minutes = 60;
  String scanType = 'music';
  Map<String, dynamic> info = {};
  double cacheMB = 0;
  @override
  void initState() {
    super.initState();
    prefs.addListener(changed);
    music.addListener(changed);
    VideoLibrary.instance.addListener(changed);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (page == 'Uyku Zamanlayıcısı') changed();
    });
    load();
  }

  Future<void> load() async {
    try {
      info = await DeviceControls.info();
    } catch (_) {}
    await cacheSize();
    changed();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    prefs.removeListener(changed);
    music.removeListener(changed);
    VideoLibrary.instance.removeListener(changed);
    timer?.cancel();
    super.dispose();
  }

  void message(String s) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> act(Future<void> Function() f) async {
    if (working) return;
    setState(() => working = true);
    try {
      await f();
    } catch (_) {
      message('İşlem tamamlanamadı. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void open(String name) {
    setState(() => page = name);
    if (name == 'Ekolayzer') loadEq();
  }

  Future<void> loadEq() async {
    try {
      eq = await music.equalizer.parameters;
      eqError = null;
    } catch (_) {
      eqError = 'Ekolayzer için önce bir şarkı açın. Cihazın ses efektlerini desteklemesi gerekir.';
    }
    changed();
  }

  Future<void> cacheSize() async {
    final root = await getTemporaryDirectory();
    final d = Directory('${root.path}/local_covers');
    var size = 0;
    if (await d.exists()) {
      await for (final f in d.list()) {
        if (f is File) size += await f.length();
      }
    }
    cacheMB = size / 1048576;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: page == null,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) setState(() => page = null);
    },
    child: Scaffold(
      appBar: AppBar(
        leading: page == null
            ? null
            : BackButton(onPressed: () => setState(() => page = null)),
        title: Text(page ?? 'Ayarlar'),
      ),
      body: Column(
        children: [
          if (working) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
              children: content(),
            ),
          ),
        ],
      ),
    ),
  );
  List<Widget> content() => switch (page) {
    'Görünüm ve Tema' => appearance(),
    'Ses Ayarları' => sound(),
    'Ekolayzer' => equalizer(),
    'Uyku Zamanlayıcısı' => sleep(),
    'Medya Tarama' => scan(),
    'Bildirim ve Kilit Ekranı Kontrolleri' => notifications(),
    'Dil' => language(),
    'Gelişmiş Ayarlar' => advanced(),
    'Uygulama Hakkında' => about(),
    _ => home(),
  };
  List<Widget> home() {
    final rows = <(IconData, String, String, Color)>[
      (
        Icons.palette,
        'Görünüm ve Tema',
        'Koyu / Açık tema, renk seçenekleri',
        Colors.pinkAccent,
      ),
      (
        Icons.volume_up,
        'Ses Ayarları',
        'Ses ve oynatma ayarları',
        Colors.purpleAccent,
      ),
      (
        Icons.graphic_eq,
        'Ekolayzer',
        'Müziğini istediğin gibi ayarla',
        Colors.greenAccent,
      ),
      (
        Icons.timer,
        'Uyku Zamanlayıcısı',
        'Belirli sürede otomatik durdur',
        Colors.lightBlueAccent,
      ),
      (
        Icons.video_library,
        'Medya Tarama',
        'Cihazdaki müzik ve videoları tara',
        Colors.pinkAccent,
      ),
      (
        Icons.notifications_active,
        'Bildirim ve Kilit Ekranı Kontrolleri',
        'Oynatma kontrollerini yönet',
        Colors.amber,
      ),
      (Icons.language, 'Dil', 'Uygulama dilini seç', Colors.deepPurpleAccent),
      (Icons.tune, 'Gelişmiş Ayarlar', 'Ek seçenekler', Colors.tealAccent),
      (
        Icons.info,
        'Uygulama Hakkında',
        'B_music02 ${info['version'] ?? ''}',
        Colors.orangeAccent,
      ),
    ];
    return [
      box(
        rows
            .map(
              (r) => ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: r.$4.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(r.$1, color: r.$4, size: 22),
                ),
                title: Text(
                  r.$2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(r.$3, style: const TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(r.$2),
              ),
            )
            .toList(),
      ),
    ];
  }

  Widget box(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  Widget title(String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(
      s,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    ),
  );
  Widget toggle(
    String label,
    String key, {
    bool fallback = true,
    Future<void> Function(bool)? apply,
  }) => SwitchListTile(
    title: Text(label, style: const TextStyle(fontSize: 13)),
    value: prefs.flag(key, fallback: fallback),
    onChanged: working
        ? null
        : (v) => act(() async {
            if (apply != null) await apply(v);
            await prefs.set(key, v);
          }),
  );
  Widget row(
    String label,
    VoidCallback action, {
    String? sub,
    IconData? icon,
  }) => ListTile(
    leading: icon == null ? null : Icon(icon),
    title: Text(label, style: const TextStyle(fontSize: 14)),
    subtitle: sub == null
        ? null
        : Text(sub, style: const TextStyle(fontSize: 11)),
    trailing: const Icon(Icons.chevron_right, size: 20),
    onTap: action,
  );
  List<Widget> appearance() {
    final theme = ThemeControllerScope.of(context);
    return [
      box([
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: ThemeMode.values
                .map(
                  (mode) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: InkWell(
                        onTap: () => theme.setThemeMode(mode),
                        child: Container(
                          height: 112,
                          decoration: BoxDecoration(
                            color: mode == ThemeMode.light
                                ? Colors.white
                                : const Color(0xFF11131F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.themeMode == mode
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                mode == ThemeMode.light
                                    ? Icons.light_mode
                                    : mode == ThemeMode.dark
                                    ? Icons.dark_mode
                                    : Icons.brightness_auto,
                                color: mode == ThemeMode.light
                                    ? Colors.black
                                    : Colors.white,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                mode == ThemeMode.light
                                    ? 'Açık Tema'
                                    : mode == ThemeMode.dark
                                    ? 'Koyu Tema'
                                    : 'Sistem Teması',
                                style: TextStyle(
                                  color: mode == ThemeMode.light
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ]),
      title('Renk Seçenekleri'),
      Wrap(
        spacing: 12,
        children:
            [
                  Colors.purpleAccent,
                  Colors.blue,
                  Colors.pink,
                  Colors.red,
                  Colors.green,
                  Colors.orange,
                ]
                .map(
                  (color) => IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: color),
                    onPressed: () => theme.setAccent(color),
                    icon: Icon(
                      theme.accent.toARGB32() == color.toARGB32()
                          ? Icons.check
                          : Icons.circle,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: 16),
      box([
        toggle(
          'Dinamik Renkler',
          'dynamic',
          fallback: false,
          apply: (v) => theme.setDynamic(v),
        ),
        toggle('Aylık Duvar Kağıdı', 'wallpaper', fallback: false),
      ]),
      row(
        'Uygulama simgesi rengi',
        () => showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Uygulama simgesi rengi'),
            content: const Text(
              'Telefonun başlatıcı ayarlarından temalı simgeleri değiştirebilirsin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Tamam'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> sound() => [
    box([
      const ListTile(
        title: Text('Ses Kalitesi'),
        subtitle: Text(
          'Yerel dosyalar özgün kalitesinde oynatılır. Dosyanın kayıt kalitesi uygulamada yükseltilemez.',
        ),
      ),
    ]),
    title('Çalma Ayarları'),
    box([
      toggle('Hareketlerle ses kontrolü', 'gestures'),
      toggle('Kulaklık takılınca devam et', 'headphones', fallback: false),
      row(
        'Diğer uygulamalarda ses',
        () => DeviceControls.settings('app'),
        sub: 'Ses odağı ve çağrı kesintileri otomatik yönetilir.',
      ),
    ]),
    box([
      const ListTile(title: Text('Varsayılan Ses Seviyesi')),
      StreamBuilder<double>(
        stream: music.player.volumeStream,
        builder: (c, s) => Column(
          children: [
            Slider(
              value: (s.data ?? music.player.volume).clamp(0, 1),
              onChanged: (v) => music.player.setVolume(v),
              onChangeEnd: (v) => prefs.set('volume', v),
            ),
            Text('${((s.data ?? music.player.volume) * 100).round()}%'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ]),
  ];
  List<Widget> equalizer() => [
    if (eq == null)
      box([
        ListTile(title: Text(eqError ?? 'Ekolayzer yükleniyor...')),
        TextButton(onPressed: loadEq, child: const Text('Yeniden dene')),
      ])
    else ...[
      box([
        StreamBuilder<bool>(
          stream: music.equalizer.enabledStream,
          builder: (c, s) => SwitchListTile(
            title: const Text('Ekolayzer'),
            value: s.data ?? music.equalizer.enabled,
            onChanged: (v) => act(() async {
              await music.equalizer.setEnabled(v);
              await prefs.set('eqEnabled', v);
            }),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Normal', 'Pop', 'Rock', 'Klasik', 'Caz']
                .map(
                  (name) => Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: prefs.text('eqPreset', 'Normal') == name,
                      onSelected: (_) => act(() async {
                        final patterns = {
                          'Normal': [0.0, 0.0, 0.0, 0.0, 0.0],
                          'Pop': [1.0, 3.0, 4.0, 1.0, -1.0],
                          'Rock': [4.0, 2.0, -1.0, 2.0, 4.0],
                          'Klasik': [3.0, 1.0, -1.0, 1.0, 3.0],
                          'Caz': [3.0, 2.0, 0.0, 2.0, 3.0],
                        };
                        final gains = patterns[name]!;
                        for (var i = 0; i < eq!.bands.length; i++) {
                          await eq!.bands[i].setGain(
                            gains[(i * 5 ~/ eq!.bands.length).clamp(0, 4)]
                                .clamp(eq!.minDecibels, eq!.maxDecibels),
                          );
                        }
                        await music.equalizer.setEnabled(true);
                        await prefs.set('eqEnabled', true);
                        await prefs.set('eqPreset', name);
                        await saveGains('eqGains');
                      }),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(
          height: 230,
          child: Row(
            children: eq!.bands
                .map(
                  (b) => Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: StreamBuilder<double>(
                              stream: b.gainStream,
                              builder: (c, s) => Slider(
                                min: eq!.minDecibels,
                                max: eq!.maxDecibels,
                                value: (s.data ?? b.gain).clamp(
                                  eq!.minDecibels,
                                  eq!.maxDecibels,
                                ),
                                onChanged: (v) => b.setGain(v),
                                onChangeEnd: (_) => saveGains('eqGains'),
                              ),
                            ),
                          ),
                        ),
                        Text(
                          b.centerFrequency >= 1000
                              ? '${(b.centerFrequency / 1000).toStringAsFixed(1)} kHz'
                              : '${b.centerFrequency.round()} Hz',
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ]),
      title('Ön Ayarlar'),
      box([
        for (var i = 1; i <= 3; i++)
          ListTile(
            leading: const Icon(Icons.music_note),
            title: Text('Özel Ayar $i'),
            onTap: () => act(() async {
              final values = prefs.gains('eqCustom$i');
              if (values.isEmpty) {
                message('Önce Kaydet düğmesiyle ayar oluşturun.');
                return;
              }
              for (var j = 0; j < eq!.bands.length && j < values.length; j++) {
                await eq!.bands[j].setGain(
                  values[j].clamp(eq!.minDecibels, eq!.maxDecibels),
                );
              }
              await music.equalizer.setEnabled(true);
              await saveGains('eqGains');
            }),
            trailing: TextButton(
              onPressed: () => act(() async {
                await saveGains('eqCustom$i');
                message('Özel Ayar $i kaydedildi.');
              }),
              child: const Text('Kaydet'),
            ),
          ),
      ]),
    ],
  ];
  Future<void> saveGains(String key) =>
      prefs.set(key, eq!.bands.map((b) => b.gain).toList());
  List<Widget> sleep() {
    final end = insights.sleepEndsAt;
    return [
      box([
        SwitchListTile(
          title: const Text('Uyku Zamanlayıcısı'),
          value: end != null,
          onChanged: (v) {
            if (v) {
              insights.startSleepTimer(Duration(minutes: minutes));
            } else {
              insights.cancelSleepTimer();
            }
            changed();
          },
        ),
        for (final n in [15, 30, 45, 60, 120, 180])
          RadioListTile<int>(
            title: Text(n < 60 ? '$n dakika' : '${n ~/ 60} saat'),
            value: n,
            groupValue: minutes,
            onChanged: (v) {
              minutes = v!;
              if (end != null)
                insights.startSleepTimer(Duration(minutes: minutes));
              changed();
            },
          ),
        row('Özel süre seç', () => customSleep()),
      ]),
      if (end != null)
        Text(
          'Kalan süre: ${end.difference(DateTime.now()).inMinutes.clamp(0, 10000)} dakika',
        ),
      const Text('Süre dolduğunda müzik otomatik olarak duraklatılır.'),
    ];
  }

  Future<void> customSleep() async {
    final controller = TextEditingController(text: '$minutes');
    final value = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Süre (dakika)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n != null && n > 0 && n <= 1440) Navigator.pop(c, n);
            },
            child: const Text('Başlat'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      minutes = value;
      insights.startSleepTimer(Duration(minutes: minutes));
      changed();
    }
  }

  List<Widget> scan() {
    final video = VideoLibrary.instance;
    final scanning = music.isLoading || video.loading;
    return [
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'music', label: Text('Müzik Tara')),
          ButtonSegment(value: 'video', label: Text('Video Tara')),
        ],
        selected: {scanType},
        onSelectionChanged: (v) => setState(() => scanType = v.first),
      ),
      const SizedBox(height: 30),
      Icon(
        scanType == 'music' ? Icons.music_note : Icons.video_library,
        size: 72,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 20),
      Text(
        scanning
            ? 'Medya taranıyor...'
            : '${scanType == 'music' ? music.songs.length : video.videos.length} dosya bulundu',
        textAlign: TextAlign.center,
      ),
      if (scanning) const LinearProgressIndicator(),
      const SizedBox(height: 24),
      box([
        toggle('Gizli dosyaları da tara', 'hidden', fallback: false),
        const ListTile(
          leading: Icon(Icons.folder),
          title: Text('Tüm medya klasörleri'),
          subtitle: Text(
            'Android medya dizinindeki erişilebilir dosyalar taranır.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.refresh),
          title: Text('Tarama sonrası listeyi güncelle'),
          subtitle: Text('Bulunan dosyalar otomatik olarak listeye eklenir.'),
        ),
      ]),
      FilledButton(
        onPressed: scanning
            ? null
            : () => act(() async {
                if (scanType == 'music') {
                  await music.requestPermissionAndLoad(request: true);
                } else {
                  await video.scan(request: true);
                }
              }),
        child: const Text('Taramayı Başlat'),
      ),
    ];
  }

  List<Widget> notifications() => [
    box([
      row(
        'Medya Bildirimleri',
        () => DeviceControls.settings('notification'),
        icon: Icons.notifications,
        sub: 'Oynatma kontrollerini göster',
      ),
      row(
        'Kilit Ekranı Kontrolleri',
        () => DeviceControls.settings('lock'),
        icon: Icons.lock,
        sub: 'Kilit ekranında müzik kontrolü',
      ),
      row(
        'Tüm Bildirimlere İzin Ver',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MusicPermissionsScreen()),
        ),
        icon: Icons.verified_user,
      ),
      row(
        'Arka planda çalışma',
        () => DeviceControls.settings('battery'),
        icon: Icons.battery_full,
      ),
    ]),
    const Text(
      'Bildirim ve kilit ekranı görünürlüğünü Android ayarları belirler.',
    ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: openAppSettings,
      child: const Text('Telefon ayarlarını aç'),
    ),
  ];
  List<Widget> language() => [
    box([
      for (final entry in {
        'tr': 'Türkçe (Türkiye)',
        'en': 'English (US)',
        'ku': 'Kurdî (Kurmancî)',
        'ckb': 'Kurdî (Soranî)',
        'ar': 'العربية (Arapça)',
      }.entries)
        RadioListTile<String>(
          value: entry.key,
          groupValue: prefs.text('language', 'tr'),
          title: Text(entry.value),
          onChanged: (v) => prefs.set('language', v),
        ),
    ]),
    const Text(
      'Dil tercihi kaydedilir. Çevirisi bulunmayan metinler Türkçe gösterilir.',
    ),
  ];
  List<Widget> advanced() => [
    box([
      row(
        'Başlangıç ekranı',
        () => showDialog<void>(
          context: context,
          builder: (c) => SimpleDialog(
            title: const Text('Başlangıç ekranı'),
            children: [
              for (var i = 0; i < 5; i++)
                SimpleDialogOption(
                  onPressed: () {
                    prefs.set('startTab', i);
                    Navigator.pop(c);
                  },
                  child: Text(
                    ['Ana Sayfa', 'Müzik', 'Video', 'Listeler', 'Ayarlar'][i],
                  ),
                ),
            ],
          ),
        ),
        sub: [
          'Ana Sayfa',
          'Müzik',
          'Video',
          'Listeler',
          'Ayarlar',
        ][prefs.number('startTab', 0).toInt().clamp(0, 4)],
      ),
      row(
        'Önbelleği temizle',
        () => act(() async {
          if (music.player.playing) {
            message('Önbelleği temizlemek için müziği duraklatın.');
            return;
          }
          final root = await getTemporaryDirectory();
          final d = Directory('${root.path}/local_covers');
          if (await d.exists()) await d.delete(recursive: true);
          await cacheSize();
          message('Albüm kapağı önbelleği temizlendi.');
        }),
        sub: '${cacheMB.toStringAsFixed(1)} MB',
      ),
      row(
        'Veritabanını yenile',
        () => act(() async {
          await music.refresh();
          await VideoLibrary.instance.scan();
          message('Medya dizini yenilendi.');
        }),
      ),
      row(
        'İçe / Dışa aktar',
        () => backupMenu(),
        sub: 'Favoriler ve çalma listelerini yedekle',
      ),
      toggle('Arka planda çalıştır', 'background'),
      row(
        'Sıfırla',
        () => reset(),
        sub: 'Oynatma ve görünüm ayarlarını varsayılana döndür',
      ),
    ]),
  ];
  Future<void> backupMenu() => showModalBottomSheet<void>(
    context: context,
    builder: (c) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            title: const Text('Yedeği dışa aktar'),
            leading: const Icon(Icons.upload_file),
            onTap: () {
              Navigator.pop(c);
              act(() async {
                final payload = await insights.createBackupPayload();
                await DeviceControls.exportBackup(
                  jsonEncode({
                    'format': 'b_music02',
                    'version': 1,
                    'data': payload,
                  }),
                );
              });
            },
          ),
          ListTile(
            title: const Text('Yedeği içe aktar'),
            leading: const Icon(Icons.download),
            onTap: () {
              Navigator.pop(c);
              act(() async {
                final raw = await DeviceControls.importBackup();
                if (raw == null) return;
                final parsed = jsonDecode(raw);
                if (parsed is! Map ||
                    parsed['format'] != 'b_music02' ||
                    parsed['data'] is! Map)
                  throw const FormatException();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Yedeği geri yükle?'),
                    content: const Text(
                      'Mevcut favoriler ve çalma listeleri bu yedekteki kayıtlarla değiştirilecek.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Vazgeç'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Geri yükle'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await music.restoreLibraryPreferences(
                    Map<String, dynamic>.from(parsed['data']),
                  );
                  message('Favoriler ve listeler geri yüklendi.');
                }
              });
            },
          ),
        ],
      ),
    ),
  );
  Future<void> reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ayarları sıfırla?'),
        content: const Text(
          'Favoriler, çalma listeleri ve medya dosyaları korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (ok == true && mounted)
      await act(() async {
        await prefs.reset();
        await music.player.setVolume(1);
        await music.player.setLoopMode(LoopMode.off);
        await music.player.setShuffleModeEnabled(false);
        await music.equalizer.setEnabled(false);
        insights.cancelSleepTimer();
        if (mounted) await ThemeControllerScope.of(context).setDark();
      });
  }

  List<Widget> about() => [
    Image.asset('assets/images/b_music02_logo.png', height: 90),
    const Text(
      'B_music02',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
    ),
    const Text('Müzik ve video her zaman seninle', textAlign: TextAlign.center),
    const SizedBox(height: 24),
    box([
      ListTile(
        title: const Text('Sürüm'),
        trailing: Text('${info['version'] ?? '—'} (${info['build'] ?? '—'})'),
      ),
      row(
        'Gizlilik Politikası',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
        ),
      ),
      row(
        'Kullanım Koşulları',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
        ),
      ),
      row(
        'Açık Kaynak Lisansları',
        () => showLicensePage(
          context: context,
          applicationName: 'B_music02',
          applicationVersion: info['version']?.toString(),
        ),
      ),
      row(
        'İletişim',
        () => act(() async {
          if (!await launchUrl(
            Uri(scheme: 'mailto', path: 'abidinkokalp4@gmail.com'),
          ))
            message('abidinkokalp4@gmail.com');
        }),
        sub: 'abidinkokalp4@gmail.com',
      ),
    ]),
  ];
}
