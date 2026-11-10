import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../state/settings_controller.dart';
import '../common/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _settings = context.read<SettingsController>();
  late final _company = TextEditingController(text: _settings.companyName);
  late final _agency = TextEditingController(
    text: Fmt.editable(_settings.defaultAgencyFee),
  );
  late final _vat = TextEditingController(
    text: Fmt.editable(_settings.defaultVat),
  );

  @override
  void dispose() {
    _company.dispose();
    _agency.dispose();
    _vat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final settings = context.watch<SettingsController>();
    final theme = Theme.of(context);
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(title: Text(s.navSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          SectionCard(
            title: s.appearance,
            child: SegmentedButton<ThemeMode>(
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
                  label: Text(s.themeDark),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (v) => settings.setThemeMode(v.first),
            ),
          ),
          gap,
          SectionCard(
            title: s.language,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'system', label: Text(s.languageSystem)),
                const ButtonSegment(value: 'ru', label: Text('Русский')),
                const ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {settings.languageCode ?? 'system'},
              onSelectionChanged: (v) => settings.setLanguageCode(
                v.first == 'system' ? null : v.first,
              ),
            ),
          ),
          gap,
          SectionCard(
            title: s.defaults,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.defaultsHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                gap,
                TextField(
                  controller: _company,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: s.myCompany,
                    prefixIcon: const Icon(Icons.business_outlined, size: 18),
                  ),
                  onChanged: settings.setCompanyName,
                ),
                gap,
                NumberField(
                  controller: _agency,
                  label: s.agencyFee,
                  suffix: '%',
                  onChanged: settings.setDefaultAgencyFee,
                ),
                gap,
                NumberField(
                  controller: _vat,
                  label: s.vatPercent,
                  suffix: '%',
                  onChanged: settings.setDefaultVat,
                ),
              ],
            ),
          ),
          gap,
          SectionCard(
            title: s.about,
            child: Text(s.aboutText, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
