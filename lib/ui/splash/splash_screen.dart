import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/slogans.dart';

/// Brand splash: logo in the centre, a random slogan at the bottom.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  String? _slogan;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slogan ??= Slogans.random(context.s.lang);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0C2445);
    final fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: navy,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF13325E), Color(0xFF07152B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              ScaleTransition(
                scale: Tween(begin: .85, end: 1.0).animate(fade),
                child: FadeTransition(
                  opacity: fade,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x6626D0F0),
                          blurRadius: 48,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/brand/logo.png',
                      width: 132,
                      height: 132,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: fade,
                child: const Text(
                  'NexusTrade',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
              ),
              const Spacer(flex: 4),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _anim,
                  curve: const Interval(.4, 1, curve: Curves.easeOut),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
                  child: Text(
                    _slogan ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9FD9F0),
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
