import 'package:flutter/material.dart';

class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _contact = TextEditingController();
  final _note = TextEditingController();
  String _type = 'Video Tanıtımı';

  @override
  void dispose() {
    for (final c in [_name, _brand, _contact, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _contact.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad soyad ve iletişim bilgisi zorunludur.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reklam talebiniz başarıyla gönderildi.')));
    _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reklam Ver', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 110), children: [
        const Text('B_music02 kitlesine markanızı ulaştırın.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('Başvurunuzu oluşturun; iletişim bilgilerinizi eksiksiz bırakın.'),
        const SizedBox(height: 22),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Ad soyad')),
        const SizedBox(height: 12),
        TextField(controller: _brand, decoration: const InputDecoration(labelText: 'Firma / marka')),
        const SizedBox(height: 12),
        TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Telefon veya e-posta')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Reklam türü'),
          items: const ['Video Tanıtımı', 'Sponsorlu İçerik', 'Hikâye Reklamı', 'İşletme Tanıtımı', 'Diğer'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLines: 5, decoration: const InputDecoration(labelText: 'Açıklama / bütçe')),
        const SizedBox(height: 18),
        ElevatedButton.icon(onPressed: _submit, icon: const Icon(Icons.campaign_outlined), label: const Text('Başvuruyu Gönder')),
      ]),
    );
  }
}
