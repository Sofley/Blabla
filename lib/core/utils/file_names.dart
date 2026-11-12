import 'package:path/path.dart' as p;

/// A file name that is safe to place inside one of the app's folders.
///
/// Names come from users, from picked files and from backups made on other
/// phones, so they may carry folders ("../../x", "A/B", "C:\\x"). Only the
/// last segment is kept — separators of both styles count — and characters
/// that file systems reject are replaced. Never returns an empty name, "."
/// or "..".
String safeFileName(String name, {String fallback = 'file'}) {
  final last = p.windows.split(name.trim()).lastOrNull ?? '';
  final base = p.posix.basename(last);
  final clean = base.replaceAll(RegExp(r'[\x00-\x1f<>:"|?*\\/]'), '_').trim();
  if (clean.isEmpty || clean == '.' || clean == '..') return fallback;
  return clean;
}

/// Lower-case extension without the dot ("pdf", "docx"…), or "".
String fileFormat(String fileName) {
  final ext = p.extension(safeFileName(fileName, fallback: ''));
  return ext.isEmpty ? '' : ext.substring(1).toLowerCase();
}
