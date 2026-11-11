import 'package:flutter/widgets.dart';

/// The seven interface languages.
enum AppLang {
  uzCyrl('uz', 'Cyrl', 'Ўзбек тили'),
  uzLatn('uz', 'Latn', 'O‘zbek tili'),
  ru('ru', null, 'Русский язык'),
  en('en', null, 'English'),
  srLatn('sr', 'Latn', 'Srpski (latinica)'),
  srCyrl('sr', 'Cyrl', 'Српски (ћирилица)'),
  zh('zh', 'Hans', '中文 (简体)');

  const AppLang(this.code, this.script, this.nativeName);

  final String code;
  final String? script;

  /// Name of the language written in itself (for the language picker).
  final String nativeName;

  Locale get locale =>
      Locale.fromSubtags(languageCode: code, scriptCode: script);

  /// Stored in settings: "uz-Cyrl", "ru", "sr-Latn"…
  String get tag => script == null ? code : '$code-$script';

  bool get isUzbek => code == 'uz';
  bool get isSerbian => code == 'sr';

  static AppLang? fromTag(String? tag) {
    if (tag == null) return null;
    for (final l in values) {
      if (l.tag == tag) return l;
    }
    // Older settings stored only the language code.
    return switch (tag) {
      'ru' => ru,
      'en' => en,
      'uz' => uzLatn,
      'sr' => srCyrl,
      'zh' => zh,
      _ => null,
    };
  }

  /// Best match for a device / resolved locale.
  static AppLang fromLocale(Locale l) => switch (l.languageCode) {
    'ru' => ru,
    'uz' => l.scriptCode == 'Cyrl' ? uzCyrl : uzLatn,
    'sr' => l.scriptCode == 'Latn' ? srLatn : srCyrl,
    'zh' => zh,
    _ => en,
  };
}
