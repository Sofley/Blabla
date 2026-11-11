import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_lang.dart';
import '../../core/l10n/app_strings.dart';
import '../../state/settings_controller.dart';

/// Bottom sheet with the seven languages (+ system default).
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final settings = ctx.watch<SettingsController>();
      final current = settings.lang;
      Widget tile(AppLang? lang, String title) =>
          RadioListTile<String>(value: lang?.tag ?? 'auto', title: Text(title));
      return SafeArea(
        child: RadioGroup<String>(
          groupValue: current?.tag ?? 'auto',
          onChanged: (tag) {
            settings.setLanguageCode(tag == 'auto' ? null : tag);
            Navigator.pop(ctx);
          },
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  ctx.s.language,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              tile(null, ctx.s.languageAuto),
              for (final l in AppLang.values) tile(l, l.nativeName),
            ],
          ),
        ),
      );
    },
  );
}

/// Compact language button (globe + current language).
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.s.lang;
    return TextButton.icon(
      onPressed: () => showLanguagePicker(context),
      icon: const Icon(Icons.language, size: 18),
      label: Text(lang.nativeName),
    );
  }
}
