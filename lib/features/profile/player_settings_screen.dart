import '../../core/l10n/app_text.dart';
import '../home/widgets/reference_design.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/platform/device_controls.dart';
import '../../core/services/announcements.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/contact_service.dart';
import '../../core/services/local_music_service.dart';
import '../../core/services/music_insights_service.dart';
import '../../core/services/player_preferences.dart';
import '../../core/services/telemetry.dart';
import '../../core/services/thumbnail_cache.dart';
import '../../core/services/video_library.dart';
import '../../core/services/video_preferences.dart';
import '../../core/theme/theme_controller.dart';
import '../onboarding/music_permissions_screen.dart';
import '../onboarding/app_tour.dart';
import '../home/update_prompt.dart';
import 'announcements_screen.dart';
import 'feedback_screen.dart';
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

  static const parents = {
    'Görünüm': 'Genel',
    'Dil': 'Genel',
    'Ekolayzer': 'Oynatma',
    'Uyku Zamanlayıcısı': 'Oynatma',
  };
  void back() => setState(() => page = parents[page]);

  void open(String name) {
    setState(() => page = name);
    if (name == 'Ekolayzer') loadEq();
  }

  Future<void> loadEq() async {
    try {
      eq = await music.equalizer.parameters;
      eqError = eq!.bands.isEmpty
          ? 'Bu cihaz ekolayzeri desteklemiyor. Müzik çalmaya devam edebilirsin.'
          : null;
    } catch (_) {
      eqError =
          'Ekolayzer için önce bir şarkı açın. Cihazın ses efektlerini desteklemesi gerekir.';
    }
    changed();
  }

  Future<void> cacheSize() async {
    final root = await getTemporaryDirectory();
    var size = 0;
    for (final name in ['local_covers', 'video_thumbs']) {
      final d = Directory('${root.path}/$name');
      if (!await d.exists()) continue;
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
          if (!didPop) back();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: page == null
                ? null
                : BackButton(onPressed: back),
            title: AppText(page ?? 'Ayarlar'),
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
        'Genel' => general(),
        'Görünüm' => appearance(),
        'Dil' => language(),
        'Oynatma' => playback(),
        'Ekolayzer' => equalizer(),
        'Uyku Zamanlayıcısı' => sleep(),
        'Bildirimler' => notifications(),
        'Dosya Taraması' => scan(),
        'Gizlilik' => privacy(),
        'Hakkında' => about(),
        _ => home(),
      };

  /// "1.0.<build>" – the same number as the GitHub release tag.
  String get versionLabel {
    final version = info['version']?.toString();
    if (version != null && version.isNotEmpty && version != '1.0.0') return version;
    final build = info['build'];
    return build == null ? '—' : '1.0.$build';
  }

  List<Widget> home() {
    final rows = <(IconData, String, String)>[
      (Icons.tune_rounded, 'Genel', 'Dil, görünüm, başlangıç ekranı'),
      (Icons.play_circle_outline_rounded, 'Oynatma', 'Hareketler, ses, ekolayzer, uyku zamanlayıcısı'),
      (Icons.notifications_none_rounded, 'Bildirimler', 'Duyurular, medya ve kilit ekranı'),
      (Icons.folder_copy_outlined, 'Dosya Taraması', 'Medyayı tara, önbellek'),
      (Icons.lock_outline_rounded, 'Gizlilik', 'İzinler, yedek, sıfırlama'),
      (Icons.info_outline_rounded, 'Hakkında', 'Sürüm $versionLabel'),
    ];
    return [
      box(
        rows
            .map(
              (r) => ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(r.$1, color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                title: AppText(
                  r.$2,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

  static const startTabs = ['Ana Sayfa', 'Müzik', 'Video', 'Listeler', 'Ayarlar'];

  List<Widget> general() => [
        box([
          row('Dil', () => open('Dil'), icon: Icons.language_rounded,
              sub: const {'tr': 'Türkçe', 'en': 'English', 'ku': 'Kurdî', 'ckb': 'Soranî', 'ar': 'العربية'}[prefs.text('language', 'tr')]),
          row('Görünüm', () => open('Görünüm'), icon: Icons.palette_outlined,
              sub: 'Tema, renkler, uygulama simgesi ve ana sayfa'),
          row(
            'Başlangıç ekranı',
            () => showDialog<void>(
              context: context,
              builder: (c) => SimpleDialog(
                title: const AppText('Başlangıç ekranı'),
                children: [
                  for (var i = 0; i < startTabs.length; i++)
                    SimpleDialogOption(
                      onPressed: () {
                        prefs.set('startTab', i);
                        Navigator.pop(c);
                      },
                      child: Text(startTabs[i]),
                    ),
                ],
              ),
            ),
            icon: Icons.home_outlined,
            sub: startTabs[prefs.number('startTab', 0).toInt().clamp(0, 4)],
          ),
          row('Uygulama tanıtımı',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppTour())),
              icon: Icons.school_outlined),
        ]),
      ];

  List<Widget> playback() => [
        box([
          row('Hareket kontrolleri',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GestureGuideScreen())),
              icon: Icons.touch_app_outlined,
              sub: 'Video yatayken: sağ ses, sol parlaklık, yatay sarma'),
          row('Ekolayzer', () => open('Ekolayzer'), icon: Icons.graphic_eq),
          row('Uyku zamanlayıcısı', () => open('Uyku Zamanlayıcısı'), icon: Icons.timer_outlined,
              sub: music.hasPlayer && insights.sleepEndsAt != null ? 'Açık' : 'Kapalı'),
        ]),
        ...sound(),
        title('Video'),
        box([
          const ListTile(
            leading: Icon(Icons.memory),
            title: AppText('Kalite ve kod çözücü', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              'Videolar özgün kalitede, donanım kod çözücüsüyle açılır. Desteklenmeyen ses/görüntü biçimlerinde otomatik olarak yazılım (FFmpeg) kod çözücüsüne geçilir.',
              style: TextStyle(fontSize: 11)),
          ),
        ]),
        title('Arka plan'),
        box([
          toggle('Arka planda çalıştır', 'background',
              sub: 'Uygulamadan çıkınca müzik çalmaya devam etsin'),
          toggle('Kaldığım yeri hatırla', 'resumePlayback',
              sub: 'Şarkı ve videolar kaldığı yerden başlasın'),
        ]),
      ];

  List<Widget> privacy() => [
        box([
          const ListTile(
            leading: Icon(Icons.phone_android),
            title: AppText('Yerel medya arşivi', style: TextStyle(fontSize: 14)),
            subtitle: Text('Müzik ve videoların bu cihazdan okunur. Yerel dosyaların sunucuya yüklenmez.',
                style: TextStyle(fontSize: 11)),
          ),
          row('Medya izinlerini yönet', openAppSettings, icon: Icons.security),
          SwitchListTile(
            secondary: const Icon(Icons.analytics_outlined),
            title: const AppText('Kullanım ve hata raporları', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Anonim kullanım istatistikleri ve çökme raporları (Firebase). Uygulamayı geliştirmemize yardım eder.',
                style: TextStyle(fontSize: 11)),
            value: Telemetry.instance.enabled,
            onChanged: (v) => act(() async {
              await Telemetry.instance.setEnabled(v);
            }),
          ),
        ]),
        title('Veriler'),
        box([
          row('İçe / Dışa aktar', () => backupMenu(), icon: Icons.import_export_rounded,
              sub: 'Favoriler ve çalma listelerini yedekle'),
          row('Ayarları sıfırla', () => reset(), icon: Icons.restart_alt_rounded,
              sub: 'Oynatma ve görünüm ayarlarını varsayılana döndür'),
        ]),
      ];

  // A Material (not a coloured DecoratedBox) so list tiles show their ripples.
  Widget box(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
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
    String? sub,
  }) =>
      SwitchListTile(
        title: AppText(label, style: const TextStyle(fontSize: 13)),
        subtitle: sub == null ? null : Text(sub, style: const TextStyle(fontSize: 11)),
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
  }) =>
      ListTile(
        leading: icon == null ? null : Icon(icon),
        title: AppText(label, style: const TextStyle(fontSize: 14)),
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
        children: [
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
          sub: 'Android 12+ duvar kağıdı renklerini kullan',
        ),
      ]),
      title('Uygulama Simgesi'),
      box([
        ListTile(
          leading: Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: iconColors[prefs.text('icon', 'Purple')] ?? iconColors['Purple'],
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/b_music02_logo.png'),
            ),
          ),
          title: const AppText('Uygulama simgesi rengi', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            '${iconNames[prefs.text('icon', 'Purple')] ?? 'Mor'} · B Music (BM) logosu',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => showDialog<void>(
            context: context,
            builder: (c) => SimpleDialog(
              title: const AppText('Uygulama simgesi rengi'),
              children: [
                for (final entry in iconNames.entries)
                  SimpleDialogOption(
                    onPressed: () {
                      Navigator.pop(c);
                      act(() async {
                        await DeviceControls.icon(entry.key);
                        await prefs.set('icon', entry.key);
                      });
                    },
                    child: Row(children: [
                      CircleAvatar(radius: 9, backgroundColor: iconColors[entry.key]),
                      const SizedBox(width: 12),
                      AppText(entry.value),
                      if (prefs.text('icon', 'Purple') == entry.key) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.check, size: 18),
                      ],
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ]),
      title('Ana Sayfa'),
      box([
        toggle('Son İzlenenler', 'homeRecent',
            sub: 'Yarım kalan videoları ana sayfada göster'),
        toggle('Video listesi görünümü', 'videoListView',
            fallback: false, sub: 'Video arşivi kart yerine liste olarak açılsın'),
      ]),
    ];
  }

  static const iconNames = {'Purple': 'Mor', 'Blue': 'Mavi', 'Pink': 'Pembe'};
  static const iconColors = {
    'Purple': Color(0xFFA53CFF),
    'Blue': Color(0xFF3C7CFF),
    'Pink': Color(0xFFFF4FA3),
  };

  List<Widget> sound() => [
        box([
          const ListTile(
            title: AppText('Ses Kalitesi'),
            subtitle: AppText(
              'Yerel dosyalar özgün kalitesinde oynatılır. Dosyanın kayıt kalitesi uygulamada yükseltilemez.',
            ),
          ),
        ]),
        title('Çalma Ayarları'),
        box([
          toggle('Hareketlerle ses kontrolü', 'gestures'),
          toggle('Kulaklık takılınca devam et', 'headphones', fallback: false),
          toggle(
            'Diğer uygulamalarda sesi kıs',
            'duck',
            apply: music.configureDucking,
          ),
        ]),
        if (music.hasPlayer) box([
          const ListTile(title: AppText('Varsayılan Ses Seviyesi')),
          StreamBuilder<double>(
            stream: music.player.volumeStream,
            builder: (c, s) => Column(
              children: [
                Slider(
                  value: (s.data ?? music.player.volume).clamp(0, 1),
                  onChanged: (v) => music.player.setVolume(v),
                  onChangeEnd: (v) => prefs.set('volume', v),
                ),
                AppText('${((s.data ?? music.player.volume) * 100).round()}%'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ]),
      ];
  List<Widget> equalizer() => [
        if (eq == null || eqError != null)
          box([
            ListTile(title: Text(eqError ?? 'Ekolayzer yükleniyor...')),
            TextButton(onPressed: loadEq, child: const AppText('Yeniden dene')),
          ])
        else ...[
          box([
            StreamBuilder<bool>(
              stream: music.equalizer.enabledStream,
              builder: (c, s) => SwitchListTile(
                title: const AppText('Ekolayzer'),
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
                          label: AppText(name),
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
                title: AppText('Özel Ayar $i'),
                onTap: () => act(() async {
                  final values = prefs.gains('eqCustom$i');
                  if (values.isEmpty) {
                    message('Önce Kaydet düğmesiyle ayar oluşturun.');
                    return;
                  }
                  for (var j = 0;
                      j < eq!.bands.length && j < values.length;
                      j++) {
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
                  child: const AppText('Kaydet'),
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
          title: const AppText('Uyku Zamanlayıcısı'),
          value: insights.sleepTimer.isActive,
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
        AppText(
          'Kalan süre: ${end.difference(DateTime.now()).inMinutes.clamp(0, 10000)} dakika',
        ),
      if (insights.stopsAfterTrack)
        const AppText('Bu şarkının sonunda duraklayacak.'),
      box([
        ListTile(
          leading: const Icon(Icons.music_note_rounded),
          title: const Text('Bu şarkı bitince durdur'),
          onTap: () {
            insights.stopAfterCurrentTrack();
            changed();
          },
        )
      ]),
      const AppText('Süre dolduğunda müzik otomatik olarak duraklatılır.'),
    ];
  }

  Future<void> customSleep() async {
    final controller = TextEditingController(text: '$minutes');
    final value = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const AppText('Süre (dakika)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const AppText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              if (n != null && n > 0 && n <= 1440) Navigator.pop(c, n);
            },
            child: const AppText('Başlat'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
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
          ButtonSegment(value: 'music', label: AppText('Müzik Tara')),
          ButtonSegment(value: 'video', label: AppText('Video Tara')),
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
          title: AppText('Tüm medya klasörleri'),
          subtitle: AppText(
            'Android medya dizinindeki erişilebilir dosyalar taranır.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.refresh),
          title: AppText('Tarama sonrası listeyi güncelle'),
          subtitle: AppText(
            'Bulunan dosyalar otomatik olarak listeye eklenir.',
          ),
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
        child: const AppText('Taramayı Başlat'),
      ),
      const SizedBox(height: 18),
      box([
        row(
          'Önbelleği temizle',
          () => act(() async {
            if (music.player.playing) {
              message('Önbelleği temizlemek için müziği duraklatın.');
              return;
            }
            final root = await getTemporaryDirectory();
            for (final name in ['local_covers', 'video_thumbs']) {
              final d = Directory('${root.path}/$name');
              if (await d.exists()) await d.delete(recursive: true);
            }
            ThumbnailCache.instance.clearMemory();
            await cacheSize();
            message('Kapak ve küçük resim önbelleği temizlendi.');
          }),
          icon: Icons.cleaning_services_outlined,
          sub: '${cacheMB.toStringAsFixed(1)} MB',
        ),
        row(
          'Veritabanını yenile',
          () => act(() async {
            await music.refresh();
            await VideoLibrary.instance.scan(force: true);
            message('Medya dizini yenilendi.');
          }),
          icon: Icons.refresh,
          sub: 'Tüm müzik ve videoları baştan tara',
        ),
      ]),
    ];
  }

  Future<PermissionStatus?> notificationStatus() async {
    try {
      return await Permission.notification.status;
    } catch (_) {
      return null;
    }
  }

  List<Widget> notifications() {
    final battery = info['batteryUnrestricted'];
    return [
        box([
          row('Ana ekran oynatıcısı', () async {
            final supported = await DeviceControls.pinWidget();
            if (!supported && mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ana ekrana basılı tutup Widget’lar bölümünden B Music’i seç.')));
          }, icon: Icons.widgets_outlined, sub: 'Şarkını uygulamayı açmadan kontrol et'),
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
        ]),
        title('Durum'),
        box([
          FutureBuilder<PermissionStatus?>(
            future: notificationStatus(),
            builder: (c, s) {
              final granted = s.data?.isGranted == true;
              return ListTile(
                leading: Icon(granted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined),
                title: const AppText('Bildirim izni', style: TextStyle(fontSize: 14)),
                subtitle: Text(
                  s.connectionState != ConnectionState.done
                      ? 'Kontrol ediliyor…'
                      : s.data == null
                          ? 'Durum okunamadı'
                          : granted
                              ? 'Açık · oynatma kontrolleri bildirimde görünür'
                              : 'Kapalı · izin vermek için dokun',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Icon(
                  granted ? Icons.check_circle : Icons.error_outline,
                  color: granted ? Colors.greenAccent : Colors.orangeAccent,
                ),
                onTap: () => act(() async {
                  final result = await Permission.notification.request();
                  if (result.isPermanentlyDenied) await openAppSettings();
                  changed();
                }),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.battery_full),
            title: const AppText('Arka planda çalışma', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              battery == true
                  ? 'Kısıtlama yok · müzik arka planda kesilmez'
                  : battery == false
                      ? 'Pil optimizasyonu açık · müzik arka planda durabilir'
                      : 'Pil ayarlarını aç',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => DeviceControls.settings('battery'),
          ),
          row(
            'Tüm Bildirimlere İzin Ver',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MusicPermissionsScreen()),
            ),
            icon: Icons.verified_user,
            sub: 'Müzik, video ve bildirim izinleri',
          ),
        ]),
        title('Uygulama İçi'),
        box([
          toggle('Duyuru bildirimleri', 'announcements',
              apply: AnnouncementService.instance.setEnabled,
              sub: 'Anlık bildirimler ve B Music duyuruları'),
          row(
            'Duyurular',
            () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const AnnouncementsScreen())),
            icon: Icons.campaign_outlined,
            sub: 'Son duyuruları gör',
          ),
        ]),
        const AppText(
          'Bildirim ve kilit ekranı görünürlüğünü Android ayarları belirler.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: openAppSettings,
          child: const AppText('Telefon ayarlarını aç'),
        ),
      ];
  }

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
              title: AppText(entry.value),
              onChanged: (v) => prefs.set('language', v),
            ),
        ]),
        const AppText(
          'Dil tercihi kaydedilir. Çevirisi bulunmayan metinler Türkçe gösterilir.',
        ),
      ];
  Future<void> backupMenu() => showModalBottomSheet<void>(
        context: context,
        builder: (c) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                title: const AppText('Yedeği dışa aktar'),
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
                title: const AppText('Yedeği içe aktar'),
                leading: const Icon(Icons.download),
                onTap: () {
                  Navigator.pop(c);
                  act(() async {
                    final raw = await DeviceControls.importBackup();
                    if (raw == null) return;
                    final parsed = jsonDecode(raw);
                    if (parsed is! Map ||
                        parsed['format'] != 'b_music02' ||
                        parsed['data'] is! Map) throw const FormatException();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const AppText('Yedeği geri yükle?'),
                        content: const AppText(
                          'Mevcut favoriler ve çalma listeleri bu yedekteki kayıtlarla değiştirilecek.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const AppText('Vazgeç'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const AppText('Geri yükle'),
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
        title: const AppText('Ayarları sıfırla?'),
        content: const AppText(
          'Favoriler, çalma listeleri ve medya dosyaları korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const AppText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const AppText('Sıfırla'),
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
        if (mounted) {
          final theme = ThemeControllerScope.of(context);
          await theme.setDark();
          await theme.setDynamic(false);
          await theme.setAccent(const Color(0xFFA53CFF));
        }
        await music.configureDucking(true);
        await DeviceControls.icon('Purple');
      });
  }

  static const whatsNew = [
    'Yeni oynatıcı: sade üst çubuk, tek satır kontroller ve ⋮ menüsünde tüm araçlar',
    'Videoya çift dokun: favorilere ekle / çıkar',
    'İlerleme çubuğunda sürüklerken sahne önizlemesi',
    'Hareketler (ses, parlaklık, sarma) yatay modda; dikeyde kaydırınca sonraki video',
    'Alarm: kitaplığından bir şarkıyla uyan',
    'Öneri Kutusu, uygulama içi güncelleme ve daha hızlı video listesi',
  ];

  List<Widget> about() {
    final videoPrefs = VideoPreferences.instance;
    final version = versionLabel;
    final update = AppUpdateService.instance.available;
    Widget stat(IconData icon, String label, int value) => ListTile(
          dense: true,
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: AppText(label, style: const TextStyle(fontSize: 14)),
          trailing: Text('$value',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        );
    return [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset('assets/images/b_music02_logo.png', height: 90),
          ),
        ),
        const SizedBox(height: 10),
        const AppText(
          'B Music',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const AppText(
          'Müzik & Video · her zaman seninle',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Center(child: Chip(label: Text('Sürüm $version'))),
        title('Arşivin'),
        box([
          stat(Icons.music_note, 'Şarkılar', music.songs.length),
          stat(Icons.favorite_outline, 'Favori şarkılar', music.favoriteSongs.length),
          stat(Icons.smart_display_outlined, 'Videolar', VideoLibrary.instance.videos.length),
          stat(Icons.trending_up_rounded, 'İzlenen videolar', videoPrefs.mostWatched.length),
        ]),
        title('Uygulama'),
        box([
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: const AppText('Sürüm'),
            trailing: AppText(version),
          ),
          if (info['sdk'] != null)
            ListTile(
              leading: const Icon(Icons.android),
              title: const AppText('Android'),
              trailing: Text('API ${info['sdk']}'),
            ),
          row(
            'Yenilikler',
            () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const AppText('Yenilikler'),
                content: SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in whatsNew)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  '),
                            Expanded(child: Text(item)),
                          ],
                        ),
                      ),
                  ],
                )),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const AppText('Tamam'),
                  ),
                ],
              ),
            ),
            icon: Icons.new_releases_outlined,
          ),
          if (update != null)
            row('Yeni sürüm var', () => UpdatePrompt.show(context, update),
                icon: Icons.system_update_outlined, sub: '${update.tag} indirilebilir'),
          row('Uygulamayı paylaş', () => act(ContactService.shareApp),
              icon: Icons.share_outlined, sub: 'İndirme bağlantısını arkadaşlarına gönder'),
        ]),
        title('Yasal'),
        box([
          row(
            'Gizlilik Politikası',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
            icon: Icons.privacy_tip_outlined,
          ),
          row(
            'Kullanım Koşulları',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
            ),
            icon: Icons.description_outlined,
          ),
          row(
            'Açık Kaynak Lisansları',
            () => showLicensePage(
              context: context,
              applicationName: 'B Music',
              applicationVersion: info['version']?.toString(),
            ),
            icon: Icons.code,
          ),
        ]),
        title('Destek'),
        box([
          row('Öneri Kutusu',
              () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const FeedbackScreen())),
              icon: Icons.lightbulb_outline_rounded, sub: 'Fikrini veya önerini doğrudan bize ilet'),
          row('İletişim', () => contactUs(context), icon: Icons.mail_outline, sub: ContactService.email),
          row(
            'Sorun bildir',
            () => act(() async {
              final sent = await ContactService.sendEmail(
                subject: 'B Music $version sorun bildirimi',
                body: 'Sürüm: $version\nAndroid API ${info['sdk'] ?? '?'}\nCihaz: ${info['model'] ?? '?'}\n\nSorun: ',
              );
              if (!sent) message(ContactService.email);
            }),
            icon: Icons.bug_report_outlined,
            sub: 'Sürüm ve cihaz bilgisiyle e-posta hazırla',
          ),
        ]),
        const SizedBox(height: 8),
        const AppText(
          '© 2026 B Music · Yerel müzik ve video oynatıcı',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11),
        ),
      ];
  }
}
