import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween(begin: 0.72, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
    Timer(const Duration(milliseconds: 2600), widget.onFinished);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [Color(0xFF341326), AppColors.background], radius: 1.1),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 122,
                    height: 122,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2),
                      boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .22), blurRadius: 34)],
                    ),
                    child: ClipOval(child: Image.asset('assets/images/b_music02_logo.png', fit: BoxFit.cover)),
                  ),
                  const SizedBox(height: 24),
                  const Text('B_music02', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: .5)),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 34),
                    child: Text(
                      'Güneydoğu’nun En Büyük Müzik Sayfasına Hoş Geldiniz',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5),
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
}
