import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../requests/requests_screen.dart';

const profileGold = Color(0xFFD4AF57);
const profileBurgundy = Color(0xFF7A1F3D);
const profileBackground = Color(0xFF090909);
const profileSurface = Color(0xFF151114);

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
            profile['username']
                ?.toString()
                .trim();

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
        final metadata =
            user.userMetadata;

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
          prefs.getString(
        'profileImagePath',
      );
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
        await SharedPreferences
            .getInstance();

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
          backgroundColor:
              profileSurface,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
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
          await SharedPreferences
              .getInstance();

      await prefs.setBool(
        'signedIn',
        false,
      );

      widget.onSignedOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Çıkış yapılırken hata oluştu.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  void _showInfo(
    String title,
    String message,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          profileSurface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              22,
              10,
              22,
              30,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  message,
                  style:
                      const TextStyle(
                    color:
                        Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Scaffold(
        backgroundColor:
            profileBackground,
        body: Center(
          child:
              CircularProgressIndicator(
            color: profileGold,
          ),
        ),
      );
    }

    File? imageFile;

    if (_imagePath != null) {
      final file =
          File(_imagePath!);

      if (file.existsSync()) {
        imageFile = file;
      }
    }

    final titleName =
        _displayName.isNotEmpty
            ? _displayName
            : _username;

    return Scaffold(
      backgroundColor:
          profileBackground,
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets
                  .fromLTRB(
            18,
            18,
            18,
            120,
          ),
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Profil',
                    style: TextStyle(
                      color:
                          Colors.white,
                      fontSize: 28,
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),
                ),
                Icon(
                  Icons
                      .music_note_rounded,
                  color:
                      profileGold,
                ),
              ],
            ),

            const SizedBox(
              height: 22,
            ),

            Container(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                20,
                26,
                20,
                24,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius
                        .circular(
                  28,
                ),
                gradient:
                    const LinearGradient(
                  begin:
                      Alignment.topLeft,
                  end: Alignment
                      .bottomRight,
                  colors: [
                    Color(
                      0xFF38101F,
                    ),
                    Color(
                      0xFF171014,
                    ),
                    Color(
                      0xFF111111,
                    ),
                  ],
                ),
                border: Border.all(
                  color: profileGold
                      .withOpacity(
                    0.28,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        profileBurgundy
                            .withOpacity(
                      0.20,
                    ),
                    blurRadius: 30,
                    offset:
                        const Offset(
                      0,
                      14,
                    ),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior:
                        Clip.none,
                    children: [
                      Container(
                        width: 126,
                        height: 126,
                        padding:
                            const EdgeInsets
                                .all(
                          4,
                        ),
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape
                                  .circle,
                          border:
                              Border.all(
                            color:
                                profileGold,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  profileGold
                                      .withOpacity(
                                0.16,
                              ),
                              blurRadius:
                                  26,
                            ),
                          ],
                        ),
                        child:
                            CircleAvatar(
                          backgroundColor:
                              profileSurface,
                          backgroundImage:
                              imageFile !=
                                      null
                                  ? FileImage(
                                      imageFile,
                                    )
                                  : null,
                          child: imageFile ==
                                  null
                              ? const Icon(
                                  Icons
                                      .person_rounded,
                                  size: 60,
                                  color:
                                      profileGold,
                                )
                              : null,
                        ),
                      ),

                      Positioned(
                        right: -3,
                        bottom: 2,
                        child: Material(
                          color:
                              profileGold,
                          shape:
                              const CircleBorder(),
                          child: InkWell(
                            onTap:
                                _pickImage,
                            customBorder:
                                const CircleBorder(),
                            child:
                                const SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(
                                Icons
                                    .photo_camera_outlined,
                                color:
                                    Colors.black,
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 17,
                  ),

                  Text(
                    titleName,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize: 25,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    '@$_username',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color:
                          profileGold,
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  if (_email
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      _email,
                      textAlign:
                          TextAlign.center,
                      style:
                          const TextStyle(
                        color:
                            Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 18,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration:
                        BoxDecoration(
                      color: profileGold
                          .withOpacity(
                        0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        30,
                      ),
                      border:
                          Border.all(
                        color:
                            profileGold
                                .withOpacity(
                          0.18,
                        ),
                      ),
                    ),
                    child:
                        const Row(
                      mainAxisSize:
                          MainAxisSize
                              .min,
                      children: [
                        Icon(
                          Icons
                              .headphones_rounded,
                          color:
                              profileGold,
                          size: 17,
                        ),
                        SizedBox(
                          width: 7,
                        ),
                        Text(
                          'B_music02 Topluluk Üyesi',
                          style:
                              TextStyle(
                            color:
                                profileGold,
                            fontSize:
                                12,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            const Text(
              'Hesabım',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            _ProfileItem(
              icon: Icons
                  .music_note_outlined,
              title: 'Taleplerim',
              subtitle:
                  'Şarkı ve içerik taleplerini yönet',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const RequestsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(
              height: 9,
            ),

            _ProfileItem(
              icon: Icons
                  .notifications_none_rounded,
              title: 'Bildirimler',
              subtitle:
                  'Bildirim tercihlerini yönet',
              onTap: () {
                _showInfo(
                  'Bildirimler',
                  'Bildirim ayarları sonraki aşamada ayrıntılı olarak eklenecek.',
                );
              },
            ),

            const SizedBox(
              height: 9,
            ),

            _ProfileItem(
              icon: Icons
                  .shield_outlined,
              title:
                  'Gizlilik ve Güvenlik',
              subtitle:
                  'Hesap ve güvenlik seçenekleri',
              onTap: () {
                _showInfo(
                  'Gizlilik ve Güvenlik',
                  'Engelleme, şikâyet ve topluluk güvenliği özellikleri B_music02 içerisinde kullanılmaktadır.',
                );
              },
            ),

            const SizedBox(
              height: 9,
            ),

            _ProfileItem(
              icon: Icons
                  .info_outline_rounded,
              title:
                  'B_music02 Hakkında',
              subtitle:
                  'Uygulama bilgileri',
              onTap: () {
                _showInfo(
                  'B_music02',
                  'Müzik içeriklerini, topluluk videolarını, istekleri ve sohbeti tek platformda buluşturan B_music02 mobil uygulaması.\n\nSürüm: 0.1.0',
                );
              },
            ),

            const SizedBox(
              height: 26,
            ),

            SizedBox(
              height: 54,
              child:
                  OutlinedButton.icon(
                onPressed:
                    _signingOut
                        ? null
                        : _signOut,
                style:
                    OutlinedButton
                        .styleFrom(
                  foregroundColor:
                      Colors.redAccent,
                  side: BorderSide(
                    color: Colors
                        .redAccent
                        .withOpacity(
                      0.38,
                    ),
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                  ),
                ),
                icon: _signingOut
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons
                            .logout_rounded,
                      ),
                label: Text(
                  _signingOut
                      ? 'Çıkış yapılıyor...'
                      : 'Çıkış Yap',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileItem
    extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        child: Ink(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          decoration:
              BoxDecoration(
            color: profileSurface,
            borderRadius:
                BorderRadius
                    .circular(
              19,
            ),
            border: Border.all(
              color:
                  Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color: profileGold
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      profileGold,
                  size: 22,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 15,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                    Colors.white30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
