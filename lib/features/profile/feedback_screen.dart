import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/device_controls.dart';
import '../../core/services/contact_service.dart';
import '../../core/services/feedback_service.dart';

/// İletişim: opens the mail app; without one, shows the address to copy.
Future<void> contactUs(BuildContext context) async {
  final sent = await ContactService.sendEmail(subject: 'B Music İletişim');
  if (sent || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('İletişim'),
      content: const SelectableText('Bize şu adresten ulaşabilirsin:\n\n${ContactService.email}'),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: ContactService.email));
            Navigator.pop(c);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('E-posta adresi kopyalandı')));
          },
          child: const Text('Kopyala'),
        ),
        FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam')),
      ],
    ),
  );
}

/// Öneri Kutusu: sends a suggestion to Firestore, or by e-mail.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.service});
  final FeedbackService? service;
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final message = TextEditingController(), contact = TextEditingController();
  bool sending = false;
  String? error;
  Map<String, dynamic> info = {};

  @override
  void initState() {
    super.initState();
    DeviceControls.info().then((value) {
      if (mounted) setState(() => info = value);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    message.dispose();
    contact.dispose();
    super.dispose();
  }

  String get version => '${info['version'] ?? ''}';
  String get details =>
      'Sürüm: ${version.isEmpty ? '?' : version} · Android API ${info['sdk'] ?? '?'} · ${info['model'] ?? ''}';

  Future<void> send() async {
    final problem = FeedbackService.validate(message.text);
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await (widget.service ?? FeedbackService.instance).send(
        message: message.text,
        contact: contact.text,
        appVersion: version,
        android: (info['sdk'] as num?)?.toInt() ?? 0,
        device: '${info['model'] ?? ''}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teşekkürler! Önerin bize ulaştı.')));
      Navigator.pop(context);
    } on FeedbackException catch (e) {
      if (mounted) setState(() => error = '${e.message}. E-posta ile de gönderebilirsin.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> email() async {
    final text = message.text.trim();
    final sent = await ContactService.sendEmail(
      subject: 'B Music Öneri',
      body: '${text.isEmpty ? '' : '$text\n\n'}${contact.text.trim().isEmpty ? '' : 'İletişim: ${contact.text.trim()}\n'}$details',
    );
    if (!sent && mounted) await contactUs(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Öneri Kutusu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withValues(alpha: .35)),
            ),
            child: Row(children: [
              Icon(Icons.lightbulb_outline_rounded, color: scheme.primary, size: 30),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Fikrini, önerini veya karşılaştığın bir sorunu yaz. Mesajın doğrudan B Music geliştiricisine ulaşır.',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: message,
            minLines: 5,
            maxLines: 10,
            maxLength: FeedbackService.maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Önerin',
              hintText: 'Örneğin: Şu özellik olsa çok iyi olur…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: contact,
            maxLength: 200,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'İletişim (isteğe bağlı)',
              hintText: 'Yanıt istersen e-posta adresin',
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(error!, style: TextStyle(color: scheme.error, fontSize: 13)),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: sending ? null : send,
            icon: sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: Text(sending ? 'Gönderiliyor…' : 'Gönder'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: email,
            icon: const Icon(Icons.mail_outline),
            label: const Text('E-posta ile gönder'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 14),
          Text(
            'Gönder\'e dokunduğunda mesajın, sürüm ve cihaz modeli (Firebase/Google sunucularında) saklanır. '
            'E-posta ile gönder ise ${ContactService.email} adresine e-posta hazırlar.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
