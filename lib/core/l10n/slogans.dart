import 'dart:math';

import 'app_lang.dart';
import 'translit.dart';

/// Seven splash slogans per language; one is picked at random on launch.
class Slogans {
  Slogans._();

  static const _ru = [
    'Nexus Trade — сделка под контролем',
    'Две стороны — один результат',
    'Каждый цент на своём месте',
    'Точный расчёт — уверенная сделка',
    'От завода до клиента — под вашим контролем',
    'Прозрачно для вас, конфиденциально для партнёров',
    'Торгуйте уверенно',
  ];

  static const _en = [
    'Nexus Trade — every deal under control',
    'Two sides, one result',
    'Every cent in its place',
    'Precise numbers, confident deals',
    'From factory to client — under your control',
    'Transparent for you, confidential for partners',
    'Trade with confidence',
  ];

  static const _uz = [
    'Nexus Trade — битим назорат остида',
    'Икки томон — битта натижа',
    'Ҳар бир цент ўз ўрнида',
    'Аниқ ҳисоб — ишончли битим',
    'Заводдан мижозгача — сизнинг назоратингизда',
    'Сиз учун шаффоф, ҳамкорлар учун махфий',
    'Ишонч билан савдо қилинг',
  ];

  static const _sr = [
    'Nexus Trade — posao pod kontrolom',
    'Dve strane — jedan rezultat',
    'Svaki cent na svom mestu',
    'Tačna računica — siguran posao',
    'Od fabrike do kupca — pod vašom kontrolom',
    'Transparentno za vas, poverljivo za partnere',
    'Trgujte sigurno',
  ];

  /// Classic Chinese sayings about trade, balance and trust.
  static const _zh = [
    '和气生财 · Nexus Trade 掌控每一笔交易',
    '诚信为本，交易为桥',
    '买卖不成仁义在',
    '薄利多销，细水长流',
    '货通天下，利达四方',
    '知己知彼，百战不殆',
    '阴阳平衡，买卖有道',
  ];

  static List<String> forLang(AppLang lang) => switch (lang) {
    AppLang.ru => _ru,
    AppLang.en => _en,
    AppLang.uzCyrl => _uz,
    AppLang.uzLatn => [for (final s in _uz) uzCyrlToLatn(s)],
    AppLang.srLatn => _sr,
    AppLang.srCyrl => [for (final s in _sr) srLatnToCyrl(s)],
    AppLang.zh => _zh,
  };

  static String random(AppLang lang, [Random? rnd]) {
    final list = forLang(lang);
    return list[(rnd ?? Random()).nextInt(list.length)];
  }
}
