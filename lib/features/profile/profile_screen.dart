import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = 'B_music02 Üyesi';
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _username = prefs.getString('username') ?? _username;
      _imagePath = prefs.getString('profileImagePath');
    });
  }

  Future<void> _pickImage() async {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1200);
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImagePath', result.path);
    if (mounted) setState(() => _imagePath = result.path);
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('signedIn', false);
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = _imagePath == null ? null : File(_imagePath!);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 110), children: [
        Center(
          child: Stack(children: [
            CircleAvatar(
              radius: 58,
              backgroundColor: AppColors.surfaceAlt,
              backgroundImage: imageFile != null && imageFile.existsSync() ? FileImage(imageFile) : null,
              child: imageFile == null || !imageFile.existsSync() ? const Icon(Icons.person_rounded, size: 56, color: AppColors.gold) : null,
            ),
            Positioned(right: 0, bottom: 0, child: IconButton.filled(onPressed: _pickImage, icon: const Icon(Icons.photo_camera_outlined))),
          ]),
        ),
        const SizedBox(height: 16),
        Text(_username, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('B_music02 topluluk üyesi', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 30),
        const ListTile(leading: Icon(Icons.favorite_outline_rounded), title: Text('Taleplerim'), trailing: Icon(Icons.chevron_right_rounded)),
        const ListTile(leading: Icon(Icons.notifications_none_rounded), title: Text('Bildirimler'), trailing: Icon(Icons.chevron_right_rounded)),
        const ListTile(leading: Icon(Icons.shield_outlined), title: Text('Gizlilik ve güvenlik'), trailing: Icon(Icons.chevron_right_rounded)),
        const ListTile(leading: Icon(Icons.info_outline_rounded), title: Text('Hakkında'), subtitle: Text('B_music02 v0.1.0')),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: _signOut, icon: const Icon(Icons.logout_rounded), label: const Text('Çıkış Yap')),
      ]),
    );
  }
}
