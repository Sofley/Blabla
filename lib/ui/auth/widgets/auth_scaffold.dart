import 'package:flutter/material.dart';

/// Shared layout of the auth screens: brand mark, title and content.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.appBar,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final PreferredSizeWidget? appBar;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: centered
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: centered
                        ? Alignment.center
                        : Alignment.centerLeft,
                    child: const BrandMark(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      textAlign: centered ? TextAlign.center : TextAlign.start,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(
        Icons.swap_horiz_rounded,
        color: scheme.onPrimary,
        size: size * .58,
      ),
    );
  }
}
