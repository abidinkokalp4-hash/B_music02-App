import 'dart:async';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/platform/device_controls.dart';
import '../../core/services/alarm_store.dart';
import '../../core/services/local_music_service.dart';

/// Daha Fazla → Alarm: wake up with a song from the library.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, this.store});
  final AlarmStore? store;
  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with WidgetsBindingObserver {
  late final store = widget.store ?? AlarmStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(changed);
    unawaited(store.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(changed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(store.refreshPermissions());
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> edit([AlarmEntry? alarm]) async {
    final result = await Navigator.push<_EditResult>(
        context,
        MaterialPageRoute(
            builder: (_) => AlarmEditor(
                alarm: alarm ?? AlarmEntry(id: store.nextId, hour: 7, minute: 0, days: const {1, 2, 3, 4, 5}),
                isNew: alarm == null)));
    if (result == null) return;
    if (result.delete) {
      await store.remove(result.alarm.id);
      return;
    }
    try {
      if ((await Permission.notification.status).isDenied) await Permission.notification.request();
    } catch (_) {/* Not available in tests / old Android. */}
    await store.save(result.alarm.copyWith(enabled: true));
    if (!mounted) return;
    final now = DateTime.now();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Alarm ${AlarmEntry.untilLabel(now, result.alarm.nextRing(now))}')));
  }

  Widget banner(String text, String button, VoidCallback onTap) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
            color: const Color(0x33FFB74D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x66FFB74D))),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: onTap, child: Text(button)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = store.permissions;
    return Scaffold(
      appBar: AppBar(title: const Text('Alarm')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
            onPressed: () => edit(),
            icon: const Icon(Icons.add_alarm_rounded),
            label: const Text('Alarm ekle')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 180),
        children: [
          if (p['notifications'] == false)
            banner('Alarmın görünmesi için bildirim izni gerekli.', 'İzin ver',
                () => DeviceControls.alarmPermission('notifications')),
          if (p['exact'] == false)
            banner('Alarmın tam zamanında çalması için "Alarmlar ve hatırlatıcılar" iznini aç.', 'İzin ver',
                () => DeviceControls.alarmPermission('exact')),
          if (p['fullScreen'] == false)
            banner('Kilit ekranında tam ekran alarm için "Tam ekran bildirimleri" iznini aç.', 'Aç',
                () => DeviceControls.alarmPermission('fullScreen')),
          if (store.loaded && store.alarms.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
              child: Column(children: [
                Icon(Icons.alarm_rounded, size: 72, color: scheme.primary.withValues(alpha: .7)),
                const SizedBox(height: 16),
                const Text('Henüz alarm yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Sevdiğin bir şarkıyla uyanmak için alarm ekle.',
                    textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              ]),
            ),
          for (final alarm in store.alarms)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => edit(alarm),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(alarm.time,
                              style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w300,
                                  color: alarm.enabled ? null : scheme.onSurfaceVariant)),
                          Text(
                              [alarm.daysLabel, if (alarm.label.isNotEmpty) alarm.label].join(' · '),
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.music_note_rounded, size: 15, color: scheme.primary),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(alarm.songTitle.isEmpty ? 'Varsayılan alarm sesi' : alarm.songTitle,
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                          ]),
                        ]),
                      ),
                      Switch(
                        value: alarm.enabled,
                        onChanged: (v) => store.save(alarm.copyWith(enabled: v)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditResult {
  const _EditResult(this.alarm, {this.delete = false});
  final AlarmEntry alarm;
  final bool delete;
}

class AlarmEditor extends StatefulWidget {
  const AlarmEditor({super.key, required this.alarm, this.isNew = false});
  final AlarmEntry alarm;
  final bool isNew;
  @override
  State<AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<AlarmEditor> {
  late AlarmEntry alarm = widget.alarm;
  late final label = TextEditingController(text: widget.alarm.label);

  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: alarm.hour, minute: alarm.minute),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) setState(() => alarm = alarm.copyWith(hour: picked.hour, minute: picked.minute));
  }

  Future<void> pickSong() async {
    final song = await showModalBottomSheet<SongModel?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => const _SongPicker(),
    );
    if (song == null) return;
    setState(() => alarm = song.id < 0
        ? alarm.copyWith(songPath: '', songTitle: '')
        : alarm.copyWith(songPath: song.data, songTitle: '${song.title}${(song.artist ?? '').isEmpty || song.artist == '<unknown>' ? '' : ' – ${song.artist}'}'));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Yeni alarm' : 'Alarmı düzenle'),
        actions: [
          if (!widget.isNew)
            IconButton(
                tooltip: 'Alarmı sil',
                onPressed: () => Navigator.pop(context, _EditResult(alarm, delete: true)),
                icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 40), children: [
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: pickTime,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Text(alarm.time, style: TextStyle(fontSize: 72, fontWeight: FontWeight.w300, color: scheme.primary)),
            ),
          ),
        ),
        Center(child: Text(AlarmEntry.untilLabel(DateTime.now(), alarm.nextRing(DateTime.now())),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
        const SizedBox(height: 22),
        const Text('Tekrarla', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              label: Text(AlarmEntry.dayNames[d - 1]),
              selected: alarm.days.contains(d),
              showCheckmark: false,
              onSelected: (on) => setState(() => alarm = alarm.copyWith(
                  days: on ? {...alarm.days, d} : ({...alarm.days}..remove(d)))),
            ),
        ]),
        const SizedBox(height: 4),
        Text(alarm.daysLabel, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 18),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
              backgroundColor: scheme.primary.withValues(alpha: .15),
              child: Icon(Icons.music_note_rounded, color: scheme.primary)),
          title: const Text('Alarm şarkısı'),
          subtitle: Text(alarm.songTitle.isEmpty ? 'Varsayılan alarm sesi' : alarm.songTitle,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: pickSong,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: label,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Etiket (isteğe bağlı)', hintText: 'Örneğin: İşe git'),
          onChanged: (v) => alarm = alarm.copyWith(label: v.trim()),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => Navigator.pop(context, _EditResult(alarm.copyWith(label: label.text.trim()))),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Kaydet'),
        ),
        const SizedBox(height: 10),
        Text('Ertele 10 dakika sonra tekrar çalar. Alarm, telefon yeniden başlasa da kurulu kalır.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _SongPicker extends StatefulWidget {
  const _SongPicker();
  @override
  State<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends State<_SongPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final songs = LocalMusicService.instance.songs
        .where((s) => query.isEmpty ||
            '${s.title} ${s.artist ?? ''}'.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: false,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Şarkı ara'),
            onChanged: (v) => setState(() => query = v.trim()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Varsayılan alarm sesi'),
          onTap: () => Navigator.pop(context, SongModel({'_id': -1, 'title': '', '_data': ''})),
        ),
        const Divider(height: 1),
        Expanded(
          child: songs.isEmpty
              ? const Center(child: Text('Kitaplıkta şarkı bulunamadı'))
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (c, i) => ListTile(
                    leading: const Icon(Icons.music_note_rounded),
                    title: Text(songs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(songs[i].artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(context, songs[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}
