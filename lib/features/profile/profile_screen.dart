import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;

  String? _username;
  String? _displayName;
  String? _avatarUrl;
  String? _bio;
  String? _appRole;

  User? get _user =>
      _supabase.auth.currentUser;

  Color get _background =>
      Theme.of(context)
          .scaffoldBackgroundColor;

  Color get _surface =>
      Theme.of(context)
          .colorScheme
          .surface;

  Color get _text =>
      Theme.of(context)
          .colorScheme
          .onSurface;

  Color get _muted =>
      _text.withOpacity(
        0.46,
      );

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _user;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final data =
          await _supabase
              .from(
                'profiles',
              )
              .select(
                'id, username, display_name, avatar_url, bio, app_role',
              )
              .eq(
                'id',
                user.id,
              )
              .maybeSingle();

      if (!mounted) return;

      if (data == null) {
        setState(() {
          _username = null;
          _displayName = null;
          _avatarUrl = null;
          _bio = null;
          _appRole = 'user';
          _loading = false;
        });

        return;
      }

      setState(() {
        _username =
            data['username']
                ?.toString();

        _displayName =
            data['display_name']
                ?.toString();

        _avatarUrl =
            data['avatar_url']
                ?.toString();

        _bio =
            data['bio']
                ?.toString();

        _appRole =
            data['app_role']
                ?.toString();

        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Profil bilgileri yüklenemedi.',
          ),
        ),
      );
    }
  }

  String get _profileName {
    final display =
        _displayName?.trim();

    if (display != null &&
        display.isNotEmpty) {
      return display;
    }

    final username =
        _username?.trim();

    if (username != null &&
        username.isNotEmpty) {
      return username;
    }

    return 'B_music02 Kullanıcısı';
  }

  String get _usernameText {
    final username =
        _username?.trim();

    if (username == null ||
        username.isEmpty) {
      return '@kullanici';
    }

    return '@$username';
  }

  String get _roleText {
    switch (_appRole) {
      case 'admin':
        return 'Yönetici';

      case 'moderator':
        return 'Moderatör';

      default:
        return 'Üye';
    }
  }

  IconData get _roleIcon {
    switch (_appRole) {
      case 'admin':
        return Icons
            .verified_user_rounded;

      case 'moderator':
        return Icons
            .shield_rounded;

      default:
        return Icons
            .person_rounded;
    }
  }

  String get _profileLetter {
    final name =
        _profileName.trim();

    if (name.isEmpty) {
      return 'B';
    }

    return name
        .substring(
          0,
          1,
        )
        .toUpperCase();
  }

  bool get _hasValidAvatar {
    final avatar =
        _avatarUrl?.trim();

    return avatar != null &&
        avatar.isNotEmpty &&
        (avatar.startsWith(
              'http://',
            ) ||
            avatar.startsWith(
              'https://',
            ));
  }

  Future<void>
      _openEditProfile() async {
    final displayController =
        TextEditingController(
      text: _displayName ?? '',
    );

    final usernameController =
        TextEditingController(
      text: _username ?? '',
    );

    final bioController =
        TextEditingController(
      text: _bio ?? '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (
        sheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setSheetState,
          ) {
            Future<void> save() async {
              final user =
                  _user;

              if (user == null ||
                  _saving) {
                return;
              }

              final username =
                  usernameController
                      .text
                      .trim();

              final displayName =
                  displayController
                      .text
                      .trim();

              final bio =
                  bioController
                      .text
                      .trim();

              if (username
                  .contains(
                    ' ',
                  )) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Kullanıcı adında boşluk kullanılamaz.',
                    ),
                  ),
                );

                return;
              }

              setSheetState(() {
                _saving = true;
              });

              try {
                await _supabase
                    .from(
                      'profiles',
                    )
                    .update(
                  {
                    'username':
                        username.isEmpty
                            ? null
                            : username,
                    'display_name':
                        displayName.isEmpty
                            ? null
                            : displayName,
                    'bio':
                        bio.isEmpty
                            ? null
                            : bio,
                  },
                ).eq(
                  'id',
                  user.id,
                );

                if (!mounted) {
                  return;
                }

                setState(() {
                  _username =
                      username.isEmpty
                          ? null
                          : username;

                  _displayName =
                      displayName.isEmpty
                          ? null
                          : displayName;

                  _bio =
                      bio.isEmpty
                          ? null
                          : bio;
                });

                if (sheetContext
                    .mounted) {
                  Navigator.pop(
                    sheetContext,
                  );
                }

                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Profil güncellendi.',
                    ),
                  ),
                );
              } catch (_) {
                if (!mounted) return;

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Profil güncellenemedi.',
                    ),
                  ),
                );
              } finally {
                if (sheetContext
                    .mounted) {
                  setSheetState(() {
                    _saving = false;
                  });
                }
              }
            }

            return Padding(
              padding:
                  EdgeInsets.only(
                bottom:
                    MediaQuery.of(
                  context,
                ).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  margin:
                      const EdgeInsets
                          .all(
                    12,
                  ),
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    20,
                    14,
                    20,
                    20,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Theme.of(
                      context,
                    )
                            .colorScheme
                            .surface,
                    borderRadius:
                        BorderRadius
                            .circular(
                      30,
                    ),
                    border:
                        Border.all(
                      color:
                          AppColors.gold
                              .withOpacity(
                        0.20,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 4,
                          decoration:
                              BoxDecoration(
                            color:
                                Theme.of(
                              context,
                            )
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(
                                  0.15,
                                ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        Row(
                          children: [
                            const Icon(
                              Icons
                                  .edit_rounded,
                              color:
                                  AppColors.gold,
                            ),

                            const SizedBox(
                              width: 9,
                            ),

                            Expanded(
                              child: Text(
                                'Profili Düzenle',
                                style:
                                    TextStyle(
                                  color:
                                      Theme.of(
                                    context,
                                  )
                                          .colorScheme
                                          .onSurface,
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        TextField(
                          controller:
                              displayController,
                          textCapitalization:
                              TextCapitalization
                                  .words,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Görünen ad',
                            prefixIcon:
                                Icon(
                              Icons
                                  .badge_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        TextField(
                          controller:
                              usernameController,
                          autocorrect:
                              false,
                          textCapitalization:
                              TextCapitalization
                                  .none,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Kullanıcı adı',
                            prefixIcon:
                                Icon(
                              Icons
                                  .alternate_email_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        TextField(
                          controller:
                              bioController,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 250,
                          textCapitalization:
                              TextCapitalization
                                  .sentences,
                          decoration:
                              const InputDecoration(
                            labelText:
                                'Hakkında',
                            alignLabelWithHint:
                                true,
                            prefixIcon:
                                Icon(
                              Icons
                                  .description_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        SizedBox(
                          width:
                              double.infinity,
                          height: 52,
                          child:
                              FilledButton.icon(
                            onPressed:
                                _saving
                                    ? null
                                    : save,
                            icon:
                                _saving
                                    ? const SizedBox(
                                        width:
                                            19,
                                        height:
                                            19,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                          color:
                                              Colors.black,
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .check_rounded,
                                      ),
                            label:
                                Text(
                              _saving
                                  ? 'Kaydediliyor...'
                                  : 'Kaydet',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    displayController.dispose();
    usernameController.dispose();
    bioController.dispose();
  }

  Future<void> _signOut() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title:
              const Text(
            'Çıkış yapılsın mı?',
          ),
          content:
              const Text(
            'B_music02 hesabından çıkış yapacaksınız.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'Vazgeç',
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text(
                'Çıkış Yap',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _supabase.auth
          .signOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Çıkış yapılamadı.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _background,
      body: SafeArea(
        child:
            _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(
                      color:
                          AppColors.gold,
                    ),
                  )
                : RefreshIndicator(
                    color:
                        AppColors.gold,
                    onRefresh:
                        _loadProfile,
                    child:
                        ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        18,
                        16,
                        18,
                        130,
                      ),
                      children: [
                        _buildHeader(),

                        const SizedBox(
                          height: 22,
                        ),

                        _buildProfileHero(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildBioCard(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildAccountSection(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildBMusicCard(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildSignOutButton(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                'Profil',
                style:
                    TextStyle(
                  color:
                      _text,
                  fontSize: 27,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing:
                      -0.8,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                'B_music02 hesabın',
                style:
                    TextStyle(
                  color:
                      _muted,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        Material(
          color:
              Colors.transparent,
          child: InkWell(
            onTap:
                _openEditProfile,
            customBorder:
                const CircleBorder(),
            child: Ink(
              width: 45,
              height: 45,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    _surface,
                border:
                    Border.all(
                  color:
                      AppColors.gold
                          .withOpacity(
                    0.20,
                  ),
                ),
              ),
              child:
                  const Icon(
                Icons
                    .edit_rounded,
                color:
                    AppColors.gold,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHero() {
    return Container(
      padding:
          const EdgeInsets
              .fromLTRB(
        18,
        22,
        18,
        20,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          30,
        ),
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            AppColors.burgundy
                .withOpacity(
              0.92,
            ),
            const Color(
              0xFF201318,
            ),
            const Color(
              0xFF0D0D0D,
            ),
          ],
        ),
        border:
            Border.all(
          color:
              AppColors.gold
                  .withOpacity(
            0.28,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppColors.burgundy
                    .withOpacity(
              0.16,
            ),
            blurRadius:
                30,
            offset:
                const Offset(
              0,
              15,
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
                width: 116,
                height: 116,
                padding:
                    const EdgeInsets.all(
                  3,
                ),
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      AppColors.gold,
                      Color(
                        0xFFF3D889,
                      ),
                      AppColors.burgundy,
                    ],
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.all(
                    4,
                  ),
                  decoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        Color(
                      0xFF111111,
                    ),
                  ),
                  child:
                      ClipOval(
                    child:
                        _hasValidAvatar
                            ? Image.network(
                                _avatarUrl!,
                                fit:
                                    BoxFit.cover,
                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return _avatarFallback();
                                },
                              )
                            : _avatarFallback(),
                  ),
                ),
              ),

              Positioned(
                right: -3,
                bottom: 5,
                child:
                    Container(
                  width: 34,
                  height: 34,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        AppColors.gold,
                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFF111111,
                      ),
                      width: 3,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .music_note_rounded,
                    color:
                        Colors.black,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          Text(
            _profileName,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize: 23,
              fontWeight:
                  FontWeight.w900,
              letterSpacing:
                  -0.5,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            _usernameText,
            style:
                const TextStyle(
              color:
                  AppColors.gold,
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withOpacity(
                0.07,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                30,
              ),
              border:
                  Border.all(
                color:
                    Colors.white
                        .withOpacity(
                  0.10,
                ),
              ),
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  _roleIcon,
                  color:
                      AppColors.gold,
                  size: 15,
                ),

                const SizedBox(
                  width: 6,
                ),

                Text(
                  _roleText,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          SizedBox(
            width:
                double.infinity,
            height: 46,
            child:
                OutlinedButton.icon(
              onPressed:
                  _openEditProfile,
              style:
                  OutlinedButton
                      .styleFrom(
                foregroundColor:
                    Colors.black,
                backgroundColor:
                    AppColors.gold,
                side:
                    BorderSide.none,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
              ),
              icon:
                  const Icon(
                Icons.edit_rounded,
                size: 18,
              ),
              label:
                  const Text(
                'Profili Düzenle',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color:
          const Color(
        0xFF171214,
      ),
      alignment:
          Alignment.center,
      child: Text(
        _profileLetter,
        style:
            const TextStyle(
          color:
              AppColors.gold,
          fontSize: 42,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildBioCard() {
    final bio =
        _bio?.trim();

    return _ProfileCard(
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(
              color:
                  AppColors.gold
                      .withOpacity(
                0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child:
                const Icon(
              Icons
                  .format_quote_rounded,
              color:
                  AppColors.gold,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Hakkında',
                  style:
                      TextStyle(
                    color:
                        _text,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  bio != null &&
                          bio.isNotEmpty
                      ? bio
                      : 'Henüz bir biyografi eklenmedi.',
                  style:
                      TextStyle(
                    color:
                        _muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets
                  .only(
            left: 4,
            bottom: 10,
          ),
          child: Text(
            'Hesap',
            style:
                TextStyle(
              color:
                  _text,
              fontSize: 18,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),

        _ProfileCard(
          padding:
              EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileTile(
                icon:
                    Icons
                        .mail_outline_rounded,
                title:
                    'E-posta',
                value:
                    _user?.email ??
                        'E-posta bulunamadı',
              ),

              _divider(),

              _ProfileTile(
                icon:
                    _roleIcon,
                title:
                    'Hesap türü',
                value:
                    _roleText,
              ),

              _divider(),

              _ProfileTile(
                icon:
                    Icons
                        .verified_rounded,
                title:
                    'Oturum',
                value:
                    'Aktif',
                valueColor:
                    AppColors.gold,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBMusicCard() {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            AppColors.gold
                .withOpacity(
              0.13,
            ),
            AppColors.burgundy
                .withOpacity(
              0.10,
            ),
          ],
        ),
        border:
            Border.all(
          color:
              AppColors.gold
                  .withOpacity(
            0.20,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            padding:
                const EdgeInsets.all(
              5,
            ),
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              border:
                  Border.all(
                color:
                    AppColors.gold,
              ),
            ),
            child:
                ClipOval(
              child:
                  Image.asset(
                'assets/images/b_music02_logo.png',
                fit:
                    BoxFit.cover,
              ),
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
                  'B_music02',
                  style:
                      TextStyle(
                    color:
                        _text,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  'Müzik, topluluk ve keşif tek yerde.',
                  style:
                      TextStyle(
                    color:
                        _muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons
                .music_note_rounded,
            color:
                AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width:
          double.infinity,
      height: 52,
      child:
          OutlinedButton.icon(
        onPressed:
            _signOut,
        style:
            OutlinedButton
                .styleFrom(
          foregroundColor:
              const Color(
            0xFFE46767,
          ),
          side:
              BorderSide(
            color:
                const Color(
                  0xFFE46767,
                ).withOpacity(
              0.35,
            ),
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
        ),
        icon:
            const Icon(
          Icons
              .logout_rounded,
        ),
        label:
            const Text(
          'Çıkış Yap',
          style:
              TextStyle(
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 62,
      color:
          Theme.of(context)
              .dividerColor,
    );
  }
}

class _ProfileCard
    extends StatelessWidget {
  const _ProfileCard({
    required this.child,
    this.padding =
        const EdgeInsets.all(
      16,
    ),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          padding,
      decoration:
          BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .surface,
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        border:
            Border.all(
          color:
              Theme.of(context)
                  .dividerColor,
        ),
      ),
      child:
          child,
    );
  }
}

class _ProfileTile
    extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(
    BuildContext context,
  ) {
    final text =
        Theme.of(context)
            .colorScheme
            .onSurface;

    return Padding(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 15,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration:
                BoxDecoration(
              color:
                  AppColors.gold
                      .withOpacity(
                0.09,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child:
                Icon(
              icon,
              color:
                  AppColors.gold,
              size: 19,
            ),
          ),

          const SizedBox(
            width: 11,
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
                      TextStyle(
                    color:
                        text.withOpacity(
                      0.42,
                    ),
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      TextStyle(
                    color:
                        valueColor ??
                            text,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
