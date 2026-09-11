import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordAgainController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _usernameChecking = false;
  bool? _usernameAvailable;

  Timer? _usernameTimer;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordAgainController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  String _normalizedUsername() {
    return _usernameController.text.trim().toLowerCase();
  }

  void _onUsernameChanged(String value) {
    _usernameTimer?.cancel();

    setState(() {
      _usernameAvailable = null;
    });

    final username = value.trim().toLowerCase();

    if (username.length < 3) return;

    _usernameTimer = Timer(
      const Duration(milliseconds: 500),
      _checkUsername,
    );
  }

  Future<bool> _checkUsername() async {
    final username = _normalizedUsername();

    final validFormat =
        RegExp(r'^[a-z0-9_][a-z0-9_.]{1,18}[a-z0-9_]$')
            .hasMatch(username);

    if (username.length < 3 ||
        username.length > 20 ||
        !validFormat) {
      if (mounted) {
        setState(() {
          _usernameAvailable = false;
          _usernameChecking = false;
        });
      }
      return false;
    }

    if (mounted) {
      setState(() {
        _usernameChecking = true;
      });
    }

    try {
      final result = await _supabase.rpc(
        'is_username_available',
        params: {
          'requested_username': username,
        },
      );

      final available = result == true;

      if (mounted) {
        setState(() {
          _usernameAvailable = available;
        });
      }

      return available;
    } catch (_) {
      if (mounted) {
        setState(() {
          _usernameAvailable = null;
        });
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _usernameChecking = false;
        });
      }
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        'E-posta ve şifre alanlarını doldurun.',
        error: true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      _showMessage(
        e.message,
        error: true,
      );
    } catch (_) {
      _showMessage(
        'Giriş yapılırken bir hata oluştu.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    final username = _normalizedUsername();
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordAgain = _passwordAgainController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      _showMessage(
        'Zorunlu alanları doldurun.',
        error: true,
      );
      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Şifre en az 6 karakter olmalı.',
        error: true,
      );
      return;
    }

    if (password != passwordAgain) {
      _showMessage(
        'Şifreler aynı değil.',
        error: true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final available = await _checkUsername();

      if (!available) {
        _showMessage(
          'Bu kullanıcı adı kullanılamıyor.',
          error: true,
        );
        return;
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'display_name':
              displayName.isEmpty ? username : displayName,
        },
      );

      if (response.session == null) {
        _showMessage(
          'Hesap oluşturuldu. E-posta adresinizi doğrulayın.',
        );

        if (mounted) {
          setState(() {
            _isLogin = true;
          });
        }
      } else {
        _showMessage(
          'Hesabınız başarıyla oluşturuldu.',
        );
      }
    } on AuthException catch (e) {
      var message = e.message;

      if (message.contains('username_taken')) {
        message = 'Bu kullanıcı adı daha önce alınmış.';
      } else if (message.contains('username_reserved')) {
        message = 'Bu kullanıcı adı kullanılamaz.';
      }

      _showMessage(
        message,
        error: true,
      );
    } catch (_) {
      _showMessage(
        'Kayıt sırasında bir hata oluştu.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    const background = Color(0xFF0B0B0B);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480,
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/b_music02_logo.png',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'B_music02',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'Hesabınıza giriş yapın'
                        : 'B_music02 topluluğuna katılın',
                    style: const TextStyle(
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    children: [
                      Expanded(
                        child: _tabButton(
                          title: 'Giriş Yap',
                          selected: _isLogin,
                          onTap: () {
                            setState(() {
                              _isLogin = true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _tabButton(
                          title: 'Kayıt Ol',
                          selected: !_isLogin,
                          onTap: () {
                            setState(() {
                              _isLogin = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (!_isLogin) ...[
                    TextField(
                      controller: _usernameController,
                      onChanged: _onUsernameChanged,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: _inputDecoration(
                        label: 'Kullanıcı adı',
                        hint: '@abidin02',
                        prefixIcon: Icons.alternate_email,
                        suffix: _usernameChecking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : _usernameAvailable == true
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : _usernameAvailable == false
                                    ? const Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                      )
                                    : null,
                      ),
                    ),
                    if (_usernameAvailable != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                          ),
                          child: Text(
                            _usernameAvailable == true
                                ? 'Kullanılabilir ✓'
                                : 'Bu kullanıcı adı kullanılamıyor.',
                            style: TextStyle(
                              color: _usernameAvailable == true
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _displayNameController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: _inputDecoration(
                        label: 'Görünen ad',
                        hint: 'Abidin',
                        prefixIcon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _inputDecoration(
                      label: 'E-posta',
                      hint: 'ornek@email.com',
                      prefixIcon: Icons.email_outlined,
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    decoration: _inputDecoration(
                      label: 'Şifre',
                      hint: 'En az 6 karakter',
                      prefixIcon: Icons.lock_outline,
                      suffix: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ),

                  if (!_isLogin) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordAgainController,
                      obscureText: true,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: _inputDecoration(
                        label: 'Şifre tekrar',
                        hint: 'Şifrenizi yeniden girin',
                        prefixIcon: Icons.lock_reset,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : (_isLogin ? _login : _register),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isLogin
                                  ? 'Giriş Yap'
                                  : 'Hesap Oluştur',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (!_isLogin)
                    const Text(
                      'Kayıt olarak B_music02 topluluk kurallarını kabul etmiş olursunuz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFD4AF37)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected
                ? Colors.black
                : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: Colors.white60,
      ),
      hintStyle: const TextStyle(
        color: Colors.white30,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: const Color(0xFFD4AF37),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFD4AF37),
        ),
      ),
    );
  }
}
