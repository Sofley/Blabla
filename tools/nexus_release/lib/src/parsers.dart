/// Pure parsers for the outputs the release check reads. No I/O here, so
/// every rule is unit-tested in memory.
library;

/// `version: 3.0.1+7` from pubspec.yaml.
class AppVersion {
  const AppVersion(this.name, this.code);
  final String name;
  final int code;

  @override
  String toString() => '$name+$code';
}

AppVersion? parsePubspecVersion(String pubspec) {
  final m = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (m == null) return null;
  return AppVersion(m.group(1)!, int.parse(m.group(2)!));
}

/// What `aapt2 dump badging` says about an APK.
class Badging {
  const Badging({
    required this.packageName,
    required this.versionCode,
    required this.versionName,
    required this.targetSdk,
    required this.minSdk,
    required this.permissions,
    required this.debuggable,
  });

  final String packageName;
  final int versionCode;
  final String versionName;
  final int? targetSdk;
  final int? minSdk;
  final List<String> permissions;
  final bool debuggable;
}

Badging? parseBadging(String out) {
  final pkg = RegExp(
    r"^package: name='([^']+)' versionCode='([0-9]+)' versionName='([^']*)'",
    multiLine: true,
  ).firstMatch(out);
  if (pkg == null) return null;
  int? sdk(String key) {
    final m = RegExp("^$key:'([0-9]+)'", multiLine: true).firstMatch(out);
    return m == null ? null : int.parse(m.group(1)!);
  }

  return Badging(
    packageName: pkg.group(1)!,
    versionCode: int.parse(pkg.group(2)!),
    versionName: pkg.group(3)!,
    targetSdk: sdk('targetSdkVersion'),
    minSdk: sdk('(?:minSdkVersion|sdkVersion)'),
    permissions: [
      for (final m in RegExp(
        r"^uses-permission: name='([^']+)'",
        multiLine: true,
      ).allMatches(out))
        m.group(1)!,
    ],
    debuggable: RegExp(
      r'^application-debuggable',
      multiLine: true,
    ).hasMatch(out),
  );
}

/// One signing certificate of an artifact.
class SignerCert {
  const SignerCert({required this.subject, required this.sha256});

  final String subject;

  /// Lower-case hex without separators.
  final String sha256;

  bool get isDebug => subject.contains('CN=Android Debug');
}

/// `apksigner verify --print-certs -v` (APK).
({bool verified, bool v2, List<SignerCert> certs}) parseApksigner(String out) {
  final dns = RegExp(
    r'^Signer #\d+ certificate DN: (.+)$',
    multiLine: true,
  ).allMatches(out).map((m) => m.group(1)!.trim()).toList();
  final shas = RegExp(
    r'^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)$',
    multiLine: true,
  ).allMatches(out).map((m) => m.group(1)!.toLowerCase()).toList();
  return (
    verified: RegExp(r'^Verifies$', multiLine: true).hasMatch(out),
    v2: RegExp(
      r'^Verified using v2 scheme.*: true$',
      multiLine: true,
    ).hasMatch(out),
    certs: [
      for (var i = 0; i < shas.length; i++)
        SignerCert(subject: i < dns.length ? dns[i] : '', sha256: shas[i]),
    ],
  );
}

/// `keytool -printcert -jarfile` (AAB, JAR-signed).
List<SignerCert> parseKeytool(String out) {
  final owners = RegExp(
    r'^\s*Owner: (.+)$',
    multiLine: true,
  ).allMatches(out).map((m) => m.group(1)!.trim()).toList();
  final shas = RegExp(
    r'^\s*SHA256: ([0-9A-Fa-f:]+)$',
    multiLine: true,
  ).allMatches(out).map((m) => normalizeSha(m.group(1)!)).toList();
  return [
    for (var i = 0; i < shas.length; i++)
      SignerCert(subject: i < owners.length ? owners[i] : '', sha256: shas[i]),
  ];
}

/// "83:E0:AA…" or "83e0aa…" → "83e0aa…".
String normalizeSha(String s) => s.replaceAll(':', '').trim().toLowerCase();

/// Split APKs (per ABI) get versionCode = 1000 × abi + base, so the base
/// code is what pubspec holds.
int baseVersionCode(int code) => code % 1000;
