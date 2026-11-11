import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

/// Optional custom wallpaper under the whole app: the user's photo,
/// blurred, behind a veil of the theme background color.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.path,
    required this.opacity,
    required this.blur,
    required this.child,
  });

  final String? path;

  /// How visible the photo is (0.1 = barely, 1.0 = fully).
  final double opacity;

  /// Gaussian blur sigma.
  final double blur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final veil = dark ? Colors.black : const Color(0xFFF4F6F9);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: veil),
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
            tileMode: TileMode.clamp,
          ),
          child: Image.file(
            File(p),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        ColoredBox(color: veil.withValues(alpha: (1 - opacity).clamp(0, .95))),
        child,
      ],
    );
  }
}
