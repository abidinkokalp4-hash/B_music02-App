import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/session_preferences.dart';
import '../../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onGuest,
  });

  final VoidCallback onGuest;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();
  final _username = TextEditingController();
  final _displayName = TextEditingController();

  bool _loginMode = true;
  bool _loading = false;
  bool _obscure = true;
  bool _keepSignedIn = true;
  Timer? _usernameTimer;
  bool? _usernameAvailable;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    SessionPreferences.keepSignedIn().then((value) {
      if (mounted) setState(() => _keepSignedIn = value);
    });
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _email.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFF9B263D) : const Color(0xFF202234),
      ),
    );
  }

  void _usernameChanged(String value) {
    _usernameTimer?.cancel();
    setState(() => _usernameAvailable = null);
    if (value.trim().length < 3) return;
    _usernameTimer = Timer(const Duration(milliseconds: 450), _checkUsername);
  }

  Future<bool> _checkUsername() async {
    final username = _username.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_][a-z0-9_.]{1,18}[a-z0-9_]$').hasMatch(username)) {
      if (mounted) setState(() => _usernameAvailable = false);
      return false;
    }
    try {
      final result = await _supabase.rpc(
        'is_username_available',
        params: {'requested_username': username},
      );
      final available = result == true;
      if (mounted) setState(() => _usernameAvailable = available);
      return available;
    } catch (_) {
      if (mounted) setState(() => _usernameAvailable = null);
      return false;
    }
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      _message('E-posta ve şifrenizi yazın.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      await SessionPreferences.setKeepSignedIn(_keepSignedIn);
    } on AuthException catch (e) {
      _message(e.message, error: true);
    } catch (_) {
      _message('Giriş yapılamadı.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final username = _username.text.trim().toLowerCase();
    final displayName = _displayName.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _message('Kullanıcı adı, e-posta ve şifre zorunlu.', error: true);
      return;
    }
    if (password.length < 6 || password != _passwordAgain.text) {
      _message(
        password.length < 6 ? 'Şifre en az 6 karakter olmalı.' : 'Şifreler aynı değil.',
        error: true,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (!await _checkUsername()) {
        _message('Bu kullanıcı adı kullanılamıyor.', error: true);
        return;
      }
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'display_name': displayName.isEmpty ? username : displayName,
        },
      );
      if (response.session == null) {
        _message('Hesap oluşturuldu. E-postanızı doğrulayıp giriş yapın.');
        if (mounted) setState(() => _loginMode = true);
      }
    } on AuthException catch (e) {
      _message(e.message, error: true);
    } catch (_) {
      _message('Hesap oluşturulamadı.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _message('Önce e-posta adresinizi yazın.', error: true);
      return;
    }
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      _message('Şifre yenileme bağlantısı e-posta adresinize gönderildi.');
    } on AuthException catch (e) {
      _message(e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            left: -110,
            top: -100,
            child: _Glow(color: AppColors.neonPurple, size: 300),
          ),
          Positioned(
            right: -130,
            bottom: -90,
            child: _Glow(color: AppColors.neonPink, size: 300),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.neonPurple, AppColors.neonPink],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonPurple.withValues(alpha: 0.45),
                              blurRadius: 34,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/b_music02_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'B_music02',
                        style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Müziğini keşfet. Hikâyeni paylaş.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      _modeSelector(),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _loginMode ? _loginForm() : _registerForm(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _loading ? null : (_loginMode ? _login : _register),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_loginMode ? 'Giriş Yap' : 'Hesap Oluştur'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : widget.onGuest,
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('Misafir Devam Et'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF35384C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Misafir olarak müzik dinleyebilir ve arama yapabilirsiniz. Hikâye paylaşmak ve profil fotoğrafı kullanmak için hesap gerekir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          height: 1.35,
                        ),
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

  Widget _modeSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF151724),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _modeButton('Giriş Yap', true),
          _modeButton('Kayıt Ol', false),
        ],
      ),
    );
  }

  Widget _modeButton(String title, bool login) {
    final selected = _loginMode == login;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _loginMode = login),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.neonPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Column(
      key: const ValueKey('login'),
      children: [
        _field(_email, 'E-posta', Icons.mail_outline_rounded),
        const SizedBox(height: 12),
        _field(
          _password,
          'Şifre',
          Icons.lock_outline_rounded,
          obscure: _obscure,
          suffix: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          ),
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _keepSignedIn,
              onChanged: (value) => setState(() => _keepSignedIn = value ?? true),
            ),
            const Expanded(
              child: Text('Oturumumu açık tut', style: TextStyle(fontSize: 11)),
            ),
            TextButton(onPressed: _resetPassword, child: const Text('Şifremi unuttum')),
          ],
        ),
      ],
    );
  }

  Widget _registerForm() {
    return Column(
      key: const ValueKey('register'),
      children: [
        _field(
          _username,
          'Kullanıcı adı',
          Icons.alternate_email_rounded,
          onChanged: _usernameChanged,
          suffix: _usernameAvailable == null
              ? null
              : Icon(
                  _usernameAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: _usernameAvailable! ? Colors.greenAccent : Colors.redAccent,
                ),
        ),
        const SizedBox(height: 12),
        _field(_displayName, 'Görünen ad', Icons.person_outline_rounded),
        const SizedBox(height: 12),
        _field(_email, 'E-posta', Icons.mail_outline_rounded),
        const SizedBox(height: 12),
        _field(_password, 'Şifre', Icons.lock_outline_rounded, obscure: _obscure),
        const SizedBox(height: 12),
        _field(
          _passwordAgain,
          'Şifre tekrar',
          Icons.lock_reset_rounded,
          obscure: _obscure,
          onSubmitted: (_) => _register(),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: hint == 'E-posta' ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.13),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 100,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }
}
