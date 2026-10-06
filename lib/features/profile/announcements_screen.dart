import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/announcements.dart';

/// "Duyurular": recent announcements from the repository's announcements.json.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, this.service, this.highlight});
  final AnnouncementService? service;
  final String? highlight;
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsState();
}

class _AnnouncementsState extends State<AnnouncementsScreen> {
  late final service = widget.service ?? AnnouncementService.instance;

  @override
  void initState() {
    super.initState();
    service.addListener(changed);
    service.loadCached();
  }

  @override
  void dispose() {
    service.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  String date(DateTime? value) {
    if (value == null) return '';
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final items = service.items;
    return Scaffold(
      appBar: AppBar(title: const Text('Duyurular')),
      body: RefreshIndicator(
        onRefresh: () => service.check(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (!service.enabled || !service.allowed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  !service.enabled
                      ? 'Duyuru bildirimleri kapalı; duyurular yine burada görünür.'
                      : 'Bildirim izni kapalı; duyurular yalnızca burada görünür.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Column(children: [
                  Icon(Icons.campaign_outlined, size: 48),
                  SizedBox(height: 12),
                  Text('Henüz duyuru yok'),
                ]),
              ),
            for (final item in items)
              Card(
                key: ValueKey('announcement-${item.id}'),
                shape: item.id == widget.highlight
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFBB62FF), width: 2))
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      if (item.createdAt != null)
                        Text(date(item.createdAt),
                            style: const TextStyle(fontSize: 11)),
                      if (item.body.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(item.body),
                      ],
                      if (item.url != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => launchUrl(Uri.parse(item.url!),
                                mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Bağlantıyı aç'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
