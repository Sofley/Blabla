import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart' show ExitCode;
import 'package:path/path.dart' as p;

import 'checks.dart';
import 'parsers.dart';

/// Runs an external tool; replaced by a fake in tests.
typedef Runner =
    Future<ProcessResult> Function(String executable, List<String> args);

Future<ProcessResult> _run(String exe, List<String> args) =>
    Process.run(exe, args);

ArgParser buildParser() => ArgParser()
  ..addOption(
    'project',
    abbr: 'p',
    help: 'Папка проекта NexusTrade.',
    defaultsTo: '.',
  )
  ..addOption(
    'artifact',
    abbr: 'a',
    help: 'Собранный файл для проверки (.aab или .apk).',
  )
  ..addOption(
    'previous-code',
    help: 'Код версии, уже опубликованный в Google Play.',
  )
  ..addOption(
    'build-tools',
    help: 'Папка Android build-tools (по умолчанию — новейшая в ANDROID_HOME).',
  )
  ..addFlag('json', negatable: false, help: 'Вывод в JSON.')
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Справка.');

const _usageTitle =
    'nexus_release — проверка сборки NexusTrade перед публикацией в Google Play.\n'
    'Коды выхода: 0 — всё в порядке, 1 — есть ошибки, 64 — неверные аргументы.\n';

/// Exit code: 0 ok, 1 a check failed, 64 usage error, 70 internal error.
Future<int> runCli(
  List<String> args, {
  Runner run = _run,
  Map<String, String>? env,
  IOSink? out,
  IOSink? err,
}) async {
  final o = out ?? stdout;
  final e = err ?? stderr;
  final parser = buildParser();
  final ArgResults a;
  try {
    a = parser.parse(args);
  } on FormatException catch (x) {
    e
      ..writeln(x.message)
      ..writeln(_usageTitle)
      ..writeln(parser.usage);
    return ExitCode.usage.code;
  }
  if (a.flag('help')) {
    o
      ..writeln(_usageTitle)
      ..writeln(parser.usage);
    return ExitCode.success.code;
  }
  int? previous;
  final prevRaw = a.option('previous-code');
  if (prevRaw != null) {
    previous = int.tryParse(prevRaw);
    if (previous == null) {
      e.writeln('--previous-code должен быть числом');
      return ExitCode.usage.code;
    }
  }
  final project = a.option('project')!;
  final pubspec = File(p.join(project, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    e.writeln('Не найден ${pubspec.path}: укажите --project');
    return ExitCode.usage.code;
  }

  final rules = const ReleaseRules();
  final results = <CheckResult>[];
  final version = parsePubspecVersion(pubspec.readAsStringSync());

  // Secrets.
  final tracked = await run('git', [
    '-C',
    project,
    'ls-files',
    '--',
    '*.jks',
    '*.keystore',
    '*.p12',
    'android/key.properties',
  ]);
  results.addAll(
    checkSecrets(
      keyPropertiesExists: File(
        p.join(project, 'android', 'key.properties'),
      ).existsSync(),
      trackedSecrets: tracked.exitCode == 0
          ? LineSplitter.split(
              tracked.stdout as String,
            ).where((l) => l.trim().isNotEmpty).toList()
          : const [],
    ),
  );

  final artifact = a.option('artifact');
  Badging? badging;
  if (artifact != null) {
    if (!File(artifact).existsSync()) {
      e.writeln('Нет файла $artifact');
      return ExitCode.usage.code;
    }
    results.add(checkFormat(artifact));
    final isAab = p.extension(artifact).toLowerCase() == '.aab';
    if (isAab) {
      final r = await run('keytool', ['-printcert', '-jarfile', artifact]);
      final certs = parseKeytool(r.stdout as String);
      results.addAll(checkSignature(certs, rules, verified: r.exitCode == 0));
    } else {
      final tools = _buildTools(
        a.option('build-tools'),
        env ?? Platform.environment,
      );
      if (tools == null) {
        e.writeln('Не найдены Android build-tools: укажите --build-tools');
        return ExitCode.config.code;
      }
      final sig = await run(p.join(tools, 'apksigner'), [
        'verify',
        '--print-certs',
        '-v',
        artifact,
      ]);
      final parsed = parseApksigner(sig.stdout as String);
      results.addAll(
        checkSignature(
          parsed.certs,
          rules,
          verified: sig.exitCode == 0 && parsed.verified,
          v2: parsed.v2,
        ),
      );
      final dump = await run(p.join(tools, 'aapt2'), [
        'dump',
        'badging',
        artifact,
      ]);
      badging = parseBadging(dump.stdout as String);
      if (badging == null) {
        results.add(
          const CheckResult(
            'manifest',
            Status.fail,
            'Не удалось прочитать манифест',
          ),
        );
      } else {
        results.addAll(checkManifest(badging, rules));
      }
    }
  }
  results.insertAll(0, checkVersion(version, badging, previousCode: previous));

  if (a.flag('json')) {
    o.writeln(
      const JsonEncoder.withIndent(
        '  ',
      ).convert([for (final r in results) r.toJson()]),
    );
  } else {
    final ansi =
        (out == null && stdout.hasTerminal && stdout.supportsAnsiEscapes) &&
        !(env ?? Platform.environment).containsKey('NO_COLOR');
    String mark(Status s) => switch (s) {
      Status.pass => ansi ? '\x1B[32m✔\x1B[0m' : '[OK]  ',
      Status.warn => ansi ? '\x1B[33m!\x1B[0m' : '[WARN]',
      Status.fail => ansi ? '\x1B[31m✘\x1B[0m' : '[FAIL]',
    };
    for (final r in results) {
      o.writeln('${mark(r.status)} ${r.id.padRight(16)} ${r.message}');
    }
    final fails = results.where((r) => r.status == Status.fail).length;
    final warns = results.where((r) => r.status == Status.warn).length;
    o.writeln(
      fails == 0
          ? '\nГотово к публикации (предупреждений: $warns).'
          : '\nНе готово: ошибок $fails, предупреждений $warns.',
    );
  }
  return results.any((r) => r.status == Status.fail)
      ? 1
      : ExitCode.success.code;
}

String? _buildTools(String? explicit, Map<String, String> env) {
  if (explicit != null) return explicit;
  for (final root in [
    env['ANDROID_HOME'],
    env['ANDROID_SDK_ROOT'],
    '/opt/sdk/android',
  ]) {
    if (root == null) continue;
    final dir = Directory(p.join(root, 'build-tools'));
    if (!dir.existsSync()) continue;
    final versions =
        dir.listSync().whereType<Directory>().map((d) => d.path).toList()
          ..sort(_compareVersions);
    if (versions.isNotEmpty) return versions.last;
  }
  return null;
}

int _compareVersions(String a, String b) {
  List<int> parts(String s) => p
      .basename(s)
      .split(RegExp(r'[.-]'))
      .map((x) => int.tryParse(x) ?? 0)
      .toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return x.length.compareTo(y.length);
}
