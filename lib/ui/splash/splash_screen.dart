import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/slogans.dart';
import 'animated_logo.dart';

/// Brand splash: the animated NexusTrade logo on AMOLED black, then a
/// random slogan in the interface language. Tap anywhere to skip.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onSkip});

  final VoidCallback? onSkip;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _slogan;
  bool _showSlogan = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 3700), () {
      if (mounted) setState(() => _showSlogan = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slogan ??= Slogans.random(context.s.lang);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSkip,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AnimatedLogo(),
            Positioned(
              left: 32,
              right: 32,
              bottom: 48,
              child: SafeArea(
                top: false,
                child: AnimatedOpacity(
                  opacity: _showSlogan ? 1 : 0,
                  duration: const Duration(milliseconds: 700),
                  child: Text(
                    _slogan ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB8A57A),
                      fontSize: 15,
                      height: 1.4,
                      letterSpacing: .3,
                      fontWeight: FontWeight.w500,
                    ),
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
