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

  /// When the slogan starts to fade in, and how long the fade takes.
  static const sloganAt = Duration(milliseconds: 1500);
  static const sloganFade = Duration(milliseconds: 400);

  /// Total time on screen (see NexusTradeApp.splashDuration).
  static const total = Duration(milliseconds: 5000);

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
    // The slogan fades in at 1.5 s (fully visible at 1.9 s) and then stays
    // still until the splash ends at 5.0 s: 3.1 s fully readable.
    _timer = Timer(SplashScreen.sloganAt, () {
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
                  duration: SplashScreen.sloganFade,
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
