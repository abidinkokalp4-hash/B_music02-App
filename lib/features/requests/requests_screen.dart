import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/request_item.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _items = <RequestItem>[
    RequestItem(artist: 'B_music02', song: 'Yeni yöresel seçki', note: 'Topluluktan örnek talep', username: 'Müziksever', votes: 12),
  ];

  Future<void> _addRequest() async {
    final artist = TextEditingController();
    final song = TextEditingController();
    final note = TextEditingController();
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Yeni Müzik Talebi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          TextField(controller: artist, decoration: const InputDecoration(labelText: 'Sanatçı')),
          const SizedBox(height: 10),
          TextField(controller: song, decoration: const InputDecoration(labelText: 'Şarkı / türkü')),
          const SizedBox(height: 10),
          TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Açıklama')),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Talebi Gönder')),
        ]),
      ),
    );
    if (added == true && artist.text.trim().isNotEmpty && song.text.trim().isNotEmpty) {
      setState(() => _items.insert(0, RequestItem(artist: artist.text.trim(), song: song.text.trim(), note: note.text.trim(), username: 'Sen')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Talepler', style: TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addRequest, icon: const Icon(Icons.add_rounded), label: const Text('Talep Oluştur')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = _items[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.username, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('${item.votes} oy', style: const TextStyle(color: AppColors.gold)),
                ]),
                const SizedBox(height: 14),
                Text(item.song, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text(item.artist, style: const TextStyle(color: AppColors.textSecondary)),
                if (item.note.isNotEmpty) ...[const SizedBox(height: 8), Text(item.note)],
                const SizedBox(height: 14),
                OutlinedButton.icon(onPressed: () => setState(() => item.votes++), icon: const Icon(Icons.favorite_border_rounded), label: const Text('Ben de istiyorum')),
              ]),
            ),
          );
        },
      ),
    );
  }
}
