import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../requests/requests_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onSignedOut,
  });

  final VoidCallback onSignedOut;

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  static const _gold = Color(0xFFD4AF57);
  static const _burgundy = Color(0xFF7A1F3D);
  static const _background = Color(0xFF090909);
  static const _surface = Color(0xFF151114);

  final SupabaseClient _supabase =
      Supabase.instance.client;

  String _username = 'B_music02 Üyesi';
  String _displayName = '';
  String _email = '';
  String? _imagePath;

  bool _loading = true;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs =
        await SharedPreferences.getInstance();

    String username =
        prefs.getString('username') ??
            'B_music02 Üyesi';

    String displayName = '';

    final user = _supabase.auth.currentUser;

    if (user != null) {
      _email = user.email ?? '';

      try {
        final profile = await _supabase
            .from('profiles')
            .select(
              'username,display_name,avatar_url',
            )
            .eq('id', user.id)
            .single();

        final remoteUsername =
            profile['username']?.toString().trim();

        final remoteDisplayName =
            profile['display_name']
                ?.toString()
                .trim();

        if (remoteUsername != null &&
            remoteUsername.isNotEmpty) {
          username = remoteUsername;
        }

        if (remoteDisplayName != null &&
            remoteDisplayName.isNotEmpty) {
          displayName = remoteDisplayName;
        }
      } catch (_) {
        final metadata = user.userMetadata;

        final metadataUsername =
            metadata?['username']
                ?.toString()
                .trim();

        final metadataDisplay =
            metadata?['display_name']
                ?.toString()
                .trim();

        if (metadataUsername != null &&
            metadataUsername.isNotEmpty) {
          username = metadataUsername;
        }

        if (metadataDisplay != null &&
            metadataDisplay.isNotEmpty) {
          displayName = metadataDisplay;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _username = username;
      _displayName = displayName;
      _imagePath =
          prefs.getString('profileImagePath');

      _loading = false;
    });
  }

  Future<void> _pickImage() async {
    final result =
        await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );

    if (result == null) return;

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'profileImagePath',
      result.path,
    );

    if (!mounted) return;

    setState(() {
      _imagePath = result.path;
    });
  }

  Future<void> _signOut() async {
    if (_signingOut) return;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title: const Text(
            'Çıkış Yap',
          ),
          content: const Text(
            'B_music02 hesabınızdan çıkış yapmak istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Vazgeç',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Çıkış Yap',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _signingOut = true;
    });

    try {
      await _supabase.auth.signOut();

      final prefs =
          await SharedPreferences.getInstance();

      await prefs.setBool(
        'signedIn',
        false,
      );

      widget.onSignedOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
       
