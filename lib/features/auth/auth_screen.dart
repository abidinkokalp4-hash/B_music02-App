import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  bool _register = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 4 || (_register && _username.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bilgileri eksiksiz doldurun.')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('signedIn', true);
    await prefs.setString('username', _register ? _username.text.trim() : _email.text.split('@').first);
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 36),
            Center(child: ClipOval(child: Image.asset('assets/images/b_music02_logo.png', width: 84, height: 84, fit: BoxFit.cover))),
            const SizedBox(height: 16),
            const Text('B_music02', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Müziğin, taleplerin ve topluluğun tek yerde.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 34),
            GlassCard(
              child: Column(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Giriş Yap')),
                      ButtonSegment(value: true, label: Text('Üye Ol')),
                    ],
                    selected: {_register},
                    onSelectionChanged: (s) => setState(() => _register = s.first),
                  ),
                  const SizedBox(height: 20),
                  if (_register) ...[
                    TextField(controller: _username, decoration: const InputDecoration(labelText: 'Kullanıcı adı', prefixIcon: Icon(Icons.person_outline_rounded))),
                    const SizedBox(height: 12),
                  ],
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre', prefixIcon: Icon(Icons.lock_outline_rounded))),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _submit, child: Text(_register ? 'Hesap Oluştur' : 'Giriş Yap')),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('İlk sürüm yerel demo oturumuyla çalışır. Firebase bağlantısı sonraki aşama için ayrılmıştır.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
