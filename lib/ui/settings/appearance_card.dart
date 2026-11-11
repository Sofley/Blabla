import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../state/auth_controller.dart';
import '../../state/settings_controller.dart';
import '../common/widgets.dart';

/// Theme engine: Light / AMOLED dark, accent color, custom wallpaper.
class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key});

  Future<void> _pickBackground(BuildContext context) async {
    final s = context.s;
    final settings = context.read<SettingsController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
      );
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
      final target = File(
        '${dir.path}/background_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await target.writeAsBytes(await picked.readAsBytes(), flush: true);
      await _deleteOld(settings.backgroundPath);
      await settings.setBackgroundPath(target.path);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${s.backgroundFailed}: $e')),
      );
    }
  }

  static Future<void> _deleteOld(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _removeBackground(SettingsController settings) async {
    final old = settings.backgroundPath;
    await settings.setBackgroundPath(null);
    await _deleteOld(old);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    final hasBg = settings.backgroundPath != null;

    return SectionCard(
      title: s.appearance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_outlined, size: 18),
                label: Text(s.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_outlined, size: 18),
                label: Text(s.themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_outlined, size: 18),
                label: Text(s.themeAmoled),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (v) => settings.setThemeMode(v.first),
          ),
          const SizedBox(height: 16),
          Text(s.accentColor, style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final a in AccentColor.values)
                _AccentDot(
                  accent: a,
                  selected: settings.accent == a,
                  label: s.accentName(a),
                  onTap: () => settings.setAccent(a),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(s.backgroundImage, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 96,
                  color: theme.colorScheme.outlineVariant,
                  child: hasBg
                      ? Image.file(
                          File(settings.backgroundPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        )
                      : Icon(
                          Icons.wallpaper_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickBackground(context),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        hasBg ? s.changeBackground : s.chooseFromGallery,
                      ),
                    ),
                    if (hasBg)
                      TextButton.icon(
                        onPressed: () => _removeBackground(settings),
                        icon: const Icon(Icons.hide_image_outlined),
                        label: Text(s.removeBackground),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (hasBg) ...[
            const SizedBox(height: 8),
            _SliderRow(
              icon: Icons.opacity,
              label: s.backgroundVisibility,
              value: settings.backgroundOpacity,
              min: .1,
              max: 1,
              display: '${(settings.backgroundOpacity * 100).round()}%',
              onChanged: settings.setBackgroundOpacity,
            ),
            _SliderRow(
              icon: Icons.blur_on,
              label: s.backgroundBlur,
              value: settings.backgroundBlur,
              min: 0,
              max: 25,
              display: settings.backgroundBlur.round().toString(),
              onChanged: settings.setBackgroundBlur,
            ),
          ],
        ],
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.accent,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final AccentColor accent;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? accent.dark
        : accent.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check,
                      color:
                          ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Observer mode: read-only view for partners / supervisors.
class ObserverCard extends StatelessWidget {
  const ObserverCard({super.key, required this.account});

  final bool account;

  Future<void> _toggle(BuildContext context, bool on) async {
    final s = context.s;
    final settings = context.read<SettingsController>();
    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      await settings.setObserverMode(true);
      return;
    }
    if (!account) {
      await settings.setObserverMode(false);
      return;
    }
    // Leaving Observer requires the owner's password.
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.observerExitTitle),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: s.password),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null) return;
    if (await auth.checkPassword(password)) {
      await settings.setObserverMode(false);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(s.wrongCurrentPassword)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final observer = context.watch<SettingsController>().observerMode;
    return SectionCard(
      title: s.observerMode,
      accent: const Color(0xFFE0A000),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(
          observer ? Icons.visibility : Icons.visibility_outlined,
          color: const Color(0xFFE0A000),
        ),
        title: Text(s.observerToggle),
        subtitle: Text(s.observerExplain),
        value: observer,
        onChanged: (v) => _toggle(context, v),
      ),
    );
  }
}
