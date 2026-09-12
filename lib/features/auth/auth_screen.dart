import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _gold = Color(0xFFD4AF57);
  static const _burgundy = Color(0xFF7A1F3D);
  static const _background = Color(0xFF090909);
  static const _surface = Color(0xFF151114);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordAgainController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordAgain = true;

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

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? const Color(0xFF9B263D) : const Color(0xFF242124),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Text(message),
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

    if (username.length < 3) {
      return;
    }

    _usernameTimer = Timer(
      const Duration(milliseconds: 500),
      _checkUsername,
    );
  }

  Future<bool> _checkUsername() async {
    final username = _normalizedUsername();

    final validFormat = RegExp(
      r'^[a-z0-9_][a-z0-9_.]{1,18}[a-z0-9_]$',
    ).hasMatch(username);

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
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          const Positioned(
            left: -100,
            top: -80,
            child: _Glow(
              color: _burgundy,
              size: 280,
            ),
          ),

          const Positioned(
            right: -120,
            bottom: -120,
            child: _Glow(
              color: _gold,
              size: 260,
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  24,
                  30,
                  24,
                  30,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 470,
                  ),
                  child: Column(
                    children: [
                      _buildLogo(),

                      const SizedBox(height: 22),

                      const Text(
                        'B_music02',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 35,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),

                      const SizedBox(height: 7),

                      const Text(
                        'Müzik burada yaşar',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Topluluk  •  İstek  •  Sohbet',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),

                      const SizedBox(height: 32),

                      _buildModeSelector(),

                      const SizedBox(height: 24),

                      AnimatedSwitcher(
                        duration:
                            const Duration(milliseconds: 250),
                        child: _isLogin
                            ? _buildLoginForm()
                            : _buildRegisterForm(),
                      ),

                      const SizedBox(height: 22),

                      _buildMainButton(),

                      const SizedBox(height: 20),

                      _buildSwitchText(),

                      const SizedBox(height: 28),

                      const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: Colors.white38,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Gizlilik ve Güvenlik',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _gold,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _burgundy.withOpacity(0.45),
            blurRadius: 36,
            spreadRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _burgundy,
            width: 5,
          ),
        ),
        padding: const EdgeInsets.all(7),
        child: ClipOval(
          child: Image.asset(
            'assets/images/b_music02_logo.png',
            fit: BoxFit.cover,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return const ColoredBox(
                color: Color(0xFF1A0C14),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 52,
                  color: _gold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
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
          const SizedBox(width: 4),
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
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [
            AutofillHints.email,
          ],
          style: const TextStyle(
            color: Colors.white,
          ),
          decoration: _inputDecoration(
            hint: 'E-posta',
            prefixIcon: Icons.mail_outline_rounded,
          ),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [
            AutofillHints.password,
          ],
          onSubmitted: (_) {
            if (!_loading) {
              _login();
            }
          },
          style: const TextStyle(
            color: Colors.white,
          ),
          decoration: _inputDecoration(
            hint: 'Şifre',
            prefixIcon: Icons.lock_outline_rounded,
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword =
                      !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white38,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey('register'),
      children: [
        TextField(
          controller: _usernameController,
          onChanged: _onUsernameChanged,
          textInputAction: TextInputAction.next,
          autofillHints: const [
            AutofillHints.username,
          ],
          style: const TextStyle(
            color: Colors.white,
          ),
          decoration: _inputDecoration(
            hint: 'Kullanıcı adı',
            prefixIcon: Icons.alternate_email_rounded,
            suffix: _usernameChecking
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _gold,
                      ),
                    ),
                  )
                : _usernameAvailable == true
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      )
                    : _usernameAvailable == false
                        ? const Icon(
                            Icons.cancel_rounded,
                            color: Colors.redAccent,
                          )
                        : null,
          ),
        ),

        if (_usernameAvailable != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(
                top: 7,
                left: 4,
              ),
              child: Text(
                _usernameAvailable == true
                    ? 'Kullanıcı adı kullanılabilir ✓'
                    : 'Bu kullanıcı adı kullanılamıyor.',
                style: TextStyle(
                  fontSize: 12,
                  color: _usernameAvailable == true
                      ? Colors.green
                      : Colors.redAccent,
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
            hint: 'Görünen ad',
            prefixIcon: Icons.person_outline_rounded,
          ),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [
            AutofillHints.email,
          ],
          style: const TextStyle(
            color: Colors.white,
          ),
          decoration: _inputDecoration(
            hint: 'E-posta',
            prefixIcon: Icons.mail_outline_rounded,
          ),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            color: Colors.white,
          ),
          decoration: _inputDecoration(
            hint: 'Şifre',
            prefixIcon: Icons.lock_outline_rounded,
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword =
                      !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white38,
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        TextField(
          controller: _passwordAgainController,
          obscureText: _obscurePasswordAgain,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            color: Colors.white,
          ),
          decoration: _inputDecoration(
            hint: 'Şifre tekrar',
            prefixIcon: Icons.lock_reset_rounded,
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePasswordAgain =
                      !_obscurePasswordAgain;
                });
              },
              icon: Icon(
                _obscurePasswordAgain
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white38,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading
            ? null
            : (_isLogin ? _login : _register),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          disabledBackgroundColor:
              _gold.withOpacity(0.55),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black,
                ),
              )
            : Text(
                _isLogin
                    ? 'Giriş Yap'
                    : 'Hesap Oluştur',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  Widget _buildSwitchText() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isLogin = !_isLogin;
        });
      },
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
          ),
          children: [
            TextSpan(
              text: _isLogin
                  ? 'Hesabın yok mu?  '
                  : 'Zaten hesabın var mı?  ',
            ),
            TextSpan(
              text:
                  _isLogin ? 'Kayıt ol' : 'Giriş yap',
              style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 220,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? _gold
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            title,
            style: TextStyle(
              color:
                  selected ? Colors.black : Colors.white60,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Colors.white38,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: _gold,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: _surface.withOpacity(0.94),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _gold,
          width: 1.3,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 100,
              spreadRadius: 55,
            ),
          ],
        ),
      ),
    );
  }
}
