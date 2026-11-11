/// Script conversion used to offer both alphabets of Uzbek and Serbian
/// from a single translation each.
library;

const _uzVowels = 'аеёиоуўэюяАЕЁИОУЎЭЮЯ';

const Map<String, String> _uzMap = {
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'ғ': 'g‘',
  'д': 'd',
  'ё': 'yo',
  'ж': 'j',
  'з': 'z',
  'и': 'i',
  'й': 'y',
  'к': 'k',
  'қ': 'q',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'ў': 'o‘',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'у': 'u',
  'ф': 'f',
  'х': 'x',
  'ҳ': 'h',
  'ц': 'ts',
  'ч': 'ch',
  'ш': 'sh',
  'щ': 'sh',
  'ъ': '’',
  'ь': '',
  'ы': 'i',
  'э': 'e',
  'ю': 'yu',
  'я': 'ya',
};

bool _isLower(String ch) => ch.toLowerCase() == ch && ch.toUpperCase() != ch;

/// Uzbek Cyrillic → official Uzbek Latin alphabet.
String uzCyrlToLatn(String input) {
  final out = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    final lower = ch.toLowerCase();
    final upper = ch != lower;
    String? lat;
    if (lower == 'е') {
      // "ye" at the start of a word and after a vowel or a hard sign.
      final prev = i > 0 ? input[i - 1] : ' ';
      final startOrVowel =
          !RegExp(r'[\p{L}]', unicode: true).hasMatch(prev) ||
          _uzVowels.contains(prev) ||
          prev == 'ъ' ||
          prev == 'Ъ';
      lat = startOrVowel ? 'ye' : 'e';
    } else {
      lat = _uzMap[lower];
    }
    if (lat == null) {
      out.write(ch);
      continue;
    }
    if (!upper || lat.isEmpty) {
      out.write(lat);
      continue;
    }
    // Capital: "Ш" → "Sh" inside a capitalised word, "SH" in an all-caps word.
    final next = i + 1 < input.length ? input[i + 1] : '';
    final allCaps =
        next.isNotEmpty && !_isLower(next) && next.toLowerCase() != next;
    out.write(
      allCaps ? lat.toUpperCase() : lat[0].toUpperCase() + lat.substring(1),
    );
  }
  return out.toString();
}

const Map<String, String> _srMap = {
  'a': 'а',
  'b': 'б',
  'c': 'ц',
  'č': 'ч',
  'ć': 'ћ',
  'd': 'д',
  'đ': 'ђ',
  'e': 'е',
  'f': 'ф',
  'g': 'г',
  'h': 'х',
  'i': 'и',
  'j': 'ј',
  'k': 'к',
  'l': 'л',
  'm': 'м',
  'n': 'н',
  'o': 'о',
  'p': 'п',
  'r': 'р',
  's': 'с',
  'š': 'ш',
  't': 'т',
  'u': 'у',
  'v': 'в',
  'z': 'з',
  'ž': 'ж',
};

/// Brand names, codes and terms that stay in Latin letters.
const _keepLatin = {
  'NexusTrade',
  'Nexus',
  'Trade',
  'Excel',
  'Word',
  'PDF',
  'Back',
  'to',
  'Teal',
  'Amber',
  'Blue',
  'Purple',
  'AMOLED',
  'Galaxy',
  'Payer',
  'Trader',
  'Buyer',
  'Importer',
  'Principal',
  'Commission',
  'Agent',
  'Incoterms',
  'Telegram',
  'WhatsApp',
  'Google',
  'Drive',
  'Play',
  'Store',
  'Remarks',
  'Notes',
  'Online',
  'Offline',
  'Observer',
  'Claude',
  'Ningbo',
  'Qingdao',
  'Tsingtao',
  'Shanghai',
  'Payment',
  'Terms',
  'Ltd',
  'LLC',
  'FZE',
};

/// International codes kept in Latin; Serbian acronyms (PDV…) are converted.
const _keepAcronyms = {
  'USD',
  'EUR',
  'CNY',
  'UZS',
  'RUB',
  'KZT',
  'AED',
  'GBP',
  'JPY',
  'TRY',
  'FOB',
  'EXW',
  'FCA',
  'CFR',
  'CIF',
  'CPT',
  'CIP',
  'DAP',
  'DDP',
  'PIN',
  'PDF',
  'AI',
  'API',
  'CBU',
  'PBOC',
  'AMOLED',
  'JSON',
  'DOCX',
  'XLSX',
  'LCL',
  'FTL',
  'HC',
  'NDS',
  'UZ',
  'OK',
};

final _srToken = RegExp(r'[A-Za-zČčĆćĐđŠšŽž]+');

/// Serbian Latin → Serbian Cyrillic. Codes (USD, FOB, PIN…), brand names
/// and words with q/w/x/y are left untouched.
String srLatnToCyrl(String input) {
  return input.replaceAllMapped(_srToken, (m) {
    final w = m.group(0)!;
    if (_keepLatin.contains(w)) return w;
    if (RegExp(r'[qwxyQWXY]').hasMatch(w)) return w;
    if (_keepAcronyms.contains(w)) return w;
    final out = StringBuffer();
    for (var i = 0; i < w.length; i++) {
      final ch = w[i];
      final lower = ch.toLowerCase();
      final upper = ch != lower;
      final next = i + 1 < w.length ? w[i + 1].toLowerCase() : '';
      String? cyr;
      var skip = 0;
      if (lower == 'l' && next == 'j') {
        cyr = 'љ';
        skip = 1;
      } else if (lower == 'n' && next == 'j') {
        cyr = 'њ';
        skip = 1;
      } else if (lower == 'd' && next == 'ž') {
        cyr = 'џ';
        skip = 1;
      } else {
        cyr = _srMap[lower];
      }
      if (cyr == null) {
        out.write(ch);
        continue;
      }
      out.write(upper ? cyr.toUpperCase() : cyr);
      i += skip;
    }
    return out.toString();
  });
}
