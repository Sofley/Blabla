import 'parsers.dart';

enum Status { pass, warn, fail }

class CheckResult {
  const CheckResult(this.id, this.status, this.message);
  final String id;
  final Status status;
  final String message;

  Map<String, Object> toJson() => {
    'id': id,
    'status': status.name,
    'message': message,
  };
}

/// Values the release must match. The fingerprint is the permanent upload
/// key's certificate (public data; the key itself never leaves the owner).
class ReleaseRules {
  const ReleaseRules({
    this.expectedSha256 =
        '83e0aae3ca5474b0128af75725f628e0835fed90f52ba2004541bba6c28d928f',
    this.minTargetSdk = 35,
    this.allowedPermissions = const {
      'android.permission.INTERNET',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
      'android.permission.VIBRATE',
      'android.permission.WAKE_LOCK',
      'android.permission.FOREGROUND_SERVICE',
    },
  });

  final String expectedSha256;
  final int minTargetSdk;
  final Set<String> allowedPermissions;
}

List<CheckResult> checkVersion(
  AppVersion? pubspec,
  Badging? badging, {
  int? previousCode,
}) {
  if (pubspec == null) {
    return [
      const CheckResult(
        'version',
        Status.fail,
        'В pubspec.yaml нет строки version: X.Y.Z+N',
      ),
    ];
  }
  final out = <CheckResult>[];
  if (badging == null) {
    out.add(
      CheckResult(
        'version',
        Status.pass,
        'pubspec: $pubspec (сборка не проверялась)',
      ),
    );
  } else {
    final base = baseVersionCode(badging.versionCode);
    final same = badging.versionName == pubspec.name && base == pubspec.code;
    out.add(
      CheckResult(
        'version',
        same ? Status.pass : Status.fail,
        same
            ? 'Версия ${badging.versionName} (код ${badging.versionCode}) совпадает с pubspec'
            : 'Сборка ${badging.versionName}+${badging.versionCode}, а pubspec $pubspec — пересоберите',
      ),
    );
  }
  if (previousCode != null) {
    final grows = pubspec.code > previousCode;
    out.add(
      CheckResult(
        'version-code',
        grows ? Status.pass : Status.fail,
        grows
            ? 'Код версии ${pubspec.code} больше опубликованного $previousCode'
            : 'Код версии ${pubspec.code} должен быть больше опубликованного $previousCode',
      ),
    );
  }
  return out;
}

List<CheckResult> checkSignature(
  List<SignerCert> certs,
  ReleaseRules rules, {
  required bool verified,
  bool? v2,
}) {
  if (!verified || certs.isEmpty) {
    return [
      const CheckResult('signature', Status.fail, 'Подпись не прошла проверку'),
    ];
  }
  final out = <CheckResult>[];
  final expected = normalizeSha(rules.expectedSha256);
  if (certs.any((c) => c.isDebug)) {
    out.add(
      const CheckResult(
        'signature',
        Status.fail,
        'Сборка подписана отладочным ключом (Android Debug) — для релиза нельзя',
      ),
    );
  } else if (certs.length == 1 && certs.single.sha256 == expected) {
    out.add(
      CheckResult(
        'signature',
        Status.pass,
        'Подписано постоянным ключом (${certs.single.subject})',
      ),
    );
  } else {
    out.add(
      CheckResult(
        'signature',
        Status.fail,
        'Чужой ключ: SHA-256 ${certs.map((c) => c.sha256).join(', ')} '
            '≠ $expected',
      ),
    );
  }
  if (v2 == false) {
    out.add(
      const CheckResult(
        'signature-scheme',
        Status.fail,
        'Нет подписи APK Signature Scheme v2',
      ),
    );
  }
  return out;
}

List<CheckResult> checkManifest(Badging b, ReleaseRules rules) {
  final out = <CheckResult>[];
  final t = b.targetSdk;
  out.add(
    t != null && t >= rules.minTargetSdk
        ? CheckResult('target-sdk', Status.pass, 'targetSdk $t')
        : CheckResult(
            'target-sdk',
            Status.fail,
            'targetSdk ${t ?? '—'} ниже требуемого Google Play (${rules.minTargetSdk})',
          ),
  );
  out.add(
    b.debuggable
        ? const CheckResult(
            'debuggable',
            Status.fail,
            'Сборка отладочная (debuggable)',
          )
        : const CheckResult('debuggable', Status.pass, 'Не отладочная'),
  );
  final extra = [
    for (final p in b.permissions)
      if (!rules.allowedPermissions.contains(p) &&
          !p.endsWith('.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'))
        p,
  ];
  out.add(
    extra.isEmpty
        ? CheckResult(
            'permissions',
            Status.pass,
            'Разрешения: ${b.permissions.length}, лишних нет',
          )
        : CheckResult(
            'permissions',
            Status.warn,
            'Новые разрешения — проверьте и укажите в анкете «Безопасность данных»: '
                '${extra.join(', ')}',
          ),
  );
  out.add(
    CheckResult(
      'package',
      Status.warn,
      'Идентификатор ${b.packageName}: после первой публикации изменить нельзя',
    ),
  );
  return out;
}

CheckResult checkFormat(String artifactPath) =>
    artifactPath.toLowerCase().endsWith('.aab')
    ? const CheckResult(
        'format',
        Status.pass,
        'Формат AAB — его принимает Google Play',
      )
    : const CheckResult(
        'format',
        Status.warn,
        'Это APK: в Google Play загружается AAB (flutter build appbundle)',
      );

/// Secrets must stay out of git.
List<CheckResult> checkSecrets({
  required bool keyPropertiesExists,
  required List<String> trackedSecrets,
}) => [
  keyPropertiesExists
      ? const CheckResult(
          'key-properties',
          Status.pass,
          'android/key.properties на месте',
        )
      : const CheckResult(
          'key-properties',
          Status.fail,
          'Нет android/key.properties — релиз соберётся без постоянного ключа',
        ),
  trackedSecrets.isEmpty
      ? const CheckResult(
          'secrets-in-git',
          Status.pass,
          'Ключи и пароли не в git',
        )
      : CheckResult(
          'secrets-in-git',
          Status.fail,
          'В git попали секреты: ${trackedSecrets.join(', ')}',
        ),
];
