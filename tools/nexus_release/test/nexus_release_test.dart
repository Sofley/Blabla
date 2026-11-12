import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nexus_release/src/checks.dart';
import 'package:nexus_release/src/cli.dart';
import 'package:nexus_release/src/parsers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const goodSha =
    '83e0aae3ca5474b0128af75725f628e0835fed90f52ba2004541bba6c28d928f';

String badging({
  int code = 7,
  String name = '3.0.1',
  int target = 36,
  List<String> perms = const ['android.permission.INTERNET'],
  bool debuggable = false,
}) => [
  "package: name='com.b2bledger.b2b_contracts' versionCode='$code' "
      "versionName='$name' platformBuildVersionName='16'",
  "minSdkVersion:'24'",
  "targetSdkVersion:'$target'",
  for (final x in perms) "uses-permission: name='$x'",
  "application-label:'NexusTrade'",
  if (debuggable) 'application-debuggable',
].join('\n');

String apksigner({String sha = goodSha, String dn = 'CN=NexusTrade, C=UZ'}) =>
    '''
Verifies
Verified using v1 scheme (JAR signing): false
Verified using v2 scheme (APK Signature Scheme v2): true
Number of signers: 1
Signer #1 certificate DN: $dn
Signer #1 certificate SHA-256 digest: $sha
''';

void main() {
  group('parsers', () {
    test('pubspec version', () {
      final v = parsePubspecVersion('name: x\nversion: 3.0.1+7\n')!;
      expect(v.name, '3.0.1');
      expect(v.code, 7);
      expect(parsePubspecVersion('version: 3.0.1\n'), isNull);
    });

    test('aapt2 badging', () {
      final b = parseBadging(badging(perms: ['a.B', 'c.D']))!;
      expect(b.packageName, 'com.b2bledger.b2b_contracts');
      expect(b.versionCode, 7);
      expect(b.versionName, '3.0.1');
      expect(b.targetSdk, 36);
      expect(b.minSdk, 24);
      expect(b.permissions, ['a.B', 'c.D']);
      expect(b.debuggable, isFalse);
      expect(parseBadging(badging(debuggable: true))!.debuggable, isTrue);
      expect(parseBadging('garbage'), isNull);
    });

    test('apksigner and keytool give the same fingerprint', () {
      final a = parseApksigner(apksigner());
      expect(a.verified, isTrue);
      expect(a.v2, isTrue);
      expect(a.certs.single.sha256, goodSha);
      final k = parseKeytool('''
Signer #1:
Certificate #1:
Owner: CN=NexusTrade, OU=Mobile, O=NexusTrade, C=UZ
Certificate fingerprints:
	 SHA1: EE:71:37
	 SHA256: 83:E0:AA:E3:CA:54:74:B0:12:8A:F7:57:25:F6:28:E0:83:5F:ED:90:F5:2B:A2:00:45:41:BB:A6:C2:8D:92:8F
''');
      expect(k.single.sha256, goodSha);
      expect(k.single.subject, startsWith('CN=NexusTrade'));
    });

    test('split APK codes map back to the base code', () {
      expect(baseVersionCode(7), 7);
      expect(baseVersionCode(2007), 7);
    });
  });

  group('checks', () {
    const rules = ReleaseRules();

    test('version must match the build and grow', () {
      final v = parsePubspecVersion('version: 3.0.1+7')!;
      final ok = checkVersion(
        v,
        parseBadging(badging(code: 2007)),
        previousCode: 6,
      );
      expect(ok.map((r) => r.status), everyElement(Status.pass));
      final stale = checkVersion(
        v,
        parseBadging(badging(name: '3.0.0', code: 6)),
      );
      expect(stale.single.status, Status.fail);
      final same = checkVersion(v, null, previousCode: 7);
      expect(same.last.status, Status.fail);
    });

    test('debug key and foreign key are rejected', () {
      expect(
        checkSignature(
          [
            const SignerCert(
              subject: 'CN=Android Debug,O=Android',
              sha256: 'aa',
            ),
          ],
          rules,
          verified: true,
        ).first.status,
        Status.fail,
      );
      expect(
        checkSignature(
          [const SignerCert(subject: 'CN=Other', sha256: 'bb')],
          rules,
          verified: true,
        ).first.status,
        Status.fail,
      );
      expect(
        checkSignature(
          [const SignerCert(subject: 'CN=NexusTrade', sha256: goodSha)],
          rules,
          verified: true,
          v2: true,
        ).single.status,
        Status.pass,
      );
      expect(
        checkSignature(const [], rules, verified: false).single.status,
        Status.fail,
      );
    });

    test('manifest rules', () {
      Status of(String id, Badging b) =>
          checkManifest(b, rules).firstWhere((r) => r.id == id).status;
      expect(of('target-sdk', parseBadging(badging(target: 34))!), Status.fail);
      expect(of('target-sdk', parseBadging(badging())!), Status.pass);
      expect(
        of('debuggable', parseBadging(badging(debuggable: true))!),
        Status.fail,
      );
      expect(
        of(
          'permissions',
          parseBadging(
            badging(perms: ['android.permission.READ_MEDIA_IMAGES']),
          )!,
        ),
        Status.warn,
      );
    });

    test('secrets in git fail the release', () {
      final r = checkSecrets(
        keyPropertiesExists: true,
        trackedSecrets: ['release/signing/k.jks'],
      );
      expect(r.last.status, Status.fail);
    });
  });

  group('runCli', () {
    late Directory project;
    late File apk;

    setUp(() {
      project = Directory.systemTemp.createTempSync('nexus_release');
      File(
        p.join(project.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: app\nversion: 3.0.1+7\n');
      Directory(p.join(project.path, 'android')).createSync();
      File(
        p.join(project.path, 'android', 'key.properties'),
      ).writeAsStringSync('storeFile=x');
      apk = File(p.join(project.path, 'app.apk'))..writeAsStringSync('x');
      addTearDown(() => project.deleteSync(recursive: true));
    });

    Runner fake({String sig = '', String dump = '', String git = ''}) =>
        (exe, args) async {
          final name = p.basename(exe);
          final out = switch (name) {
            'apksigner' => sig,
            'aapt2' => dump,
            'git' => git,
            _ => '',
          };
          return ProcessResult(0, 0, out, '');
        };

    Future<(int, String, String)> cli(List<String> args, Runner run) async {
      final out = _Sink(), err = _Sink();
      final code = await runCli(
        args,
        run: run,
        env: const {'NO_COLOR': '1'},
        out: out.sink,
        err: err.sink,
      );
      return (code, await out.collect(), await err.collect());
    }

    test('a good release passes with exit code 0', () async {
      final (code, out, _) = await cli([
        '-p',
        project.path,
        '-a',
        apk.path,
        '--build-tools',
        '/bt',
        '--json',
      ], fake(sig: apksigner(), dump: badging()));
      expect(code, 0);
      final list = (jsonDecode(out) as List).cast<Map>();
      expect(list.where((r) => r['status'] == 'fail'), isEmpty);
    });

    test('a debug-signed build fails with exit code 1', () async {
      final (code, out, _) = await cli(
        ['-p', project.path, '-a', apk.path, '--build-tools', '/bt'],
        fake(
          sig: apksigner(sha: 'ab' * 32, dn: 'CN=Android Debug, O=Android'),
          dump: badging(),
        ),
      );
      expect(code, 1);
      expect(out, contains('[FAIL] signature'));
      expect(out, contains('Не готово'));
    });

    test('usage errors go to stderr with code 64', () async {
      final (code, out, err) = await cli(['--nope'], fake());
      expect(code, 64);
      expect(out, isEmpty);
      expect(err, contains('--project'));
      final (code2, _, err2) = await cli([
        '-p',
        project.path,
        '--previous-code',
        'x',
      ], fake());
      expect(code2, 64);
      expect(err2, contains('--previous-code'));
    });

    test('--help prints usage to stdout', () async {
      final (code, out, err) = await cli(['--help'], fake());
      expect(code, 0);
      expect(out, contains('--artifact'));
      expect(err, isEmpty);
    });
  });
}

/// Collects what the CLI writes.
class _Sink {
  _Sink() {
    _c.stream.listen(_buf.addAll, onDone: _done.complete);
  }
  final _done = Completer<void>();

  /// Closes the sink and waits until every byte has arrived.
  Future<String> collect() async {
    await sink.close();
    await _done.future;
    return text;
  }

  final _buf = <int>[];
  final _c = StreamController<List<int>>();
  late final IOSink sink = IOSink(_c.sink);
  String get text => utf8.decode(_buf);
}
