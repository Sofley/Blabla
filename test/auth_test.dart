import 'dart:io';

import 'package:b2b_contracts/core/security/password_hasher.dart';
import 'package:b2b_contracts/data/models/account.dart';
import 'package:b2b_contracts/data/repositories/auth_repository.dart';
import 'package:b2b_contracts/state/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'test_helpers.dart';

void main() {
  late Directory dir;
  late Box box;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('auth_test');
    Hive.init(dir.path);
    box = await Hive.openBox('auth_test');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  AuthController make() => AuthController(
    AuthRepository(box),
    hasher: const FastHasher(),
    onWipe: () => box.clear(),
  );

  test('login normalization', () {
    expect(
      AuthController.normalizeLogin(LoginType.email, ' Ivan@Mail.RU '),
      'ivan@mail.ru',
    );
    expect(AuthController.normalizeLogin(LoginType.email, 'bad@'), isNull);
    expect(
      AuthController.normalizeLogin(LoginType.phone, '+998 (90) 123-45-67'),
      '+998901234567',
    );
    expect(AuthController.normalizeLogin(LoginType.phone, '123'), isNull);
    expect(AuthController.isStrongEnough('abc123'), isTrue);
    expect(AuthController.isStrongEnough('123456'), isFalse);
  });

  test('pbkdf2 matches the RFC 7914 test vector', () {
    // PBKDF2-HMAC-SHA256("passwd", "salt", 1): 55 ac 04 6e 56 e3 08 9f …
    final h = PasswordHasher.pbkdf2('passwd', 'salt', 1);
    expect(h, 'VawEblbjCJ_sFpHCJUS2BflBhSFt3gRl5oudV8INrLw=');
  });

  test('register, lock, unlock with password / PIN / pattern', () async {
    final auth = make();
    expect(auth.status, AuthStatus.needsRegistration);

    await auth.register(
      type: LoginType.phone,
      login: '+998 90 1234567',
      password: 'secret1',
    );
    expect(auth.status, AuthStatus.unlocked);
    expect(auth.needsQuickSetup, isTrue);
    expect(box.get('account')['passwordHash'], isNot(contains('secret1')));

    await auth.setQuickUnlock(QuickUnlock.pin4, '2468');
    auth.lock();
    expect(auth.status, AuthStatus.locked);
    expect(await auth.unlockWithQuick('1111'), AuthResult.wrong);
    expect(await auth.unlockWithQuick('2468'), AuthResult.ok);

    auth.lock();
    expect(
      await auth.unlockWithPassword('+998901234567', 'wrong1'),
      AuthResult.wrong,
    );
    expect(
      await auth.unlockWithPassword('998 90 123 45 67', 'secret1'),
      AuthResult.ok,
    );

    await auth.setQuickUnlock(QuickUnlock.pattern, '0-4-8-5');
    auth.lock();
    expect(await auth.unlockWithQuick('0-4-8-5'), AuthResult.ok);

    // Re-opening the app finds the account and starts locked.
    expect(make().status, AuthStatus.locked);
  });

  test('locks out after 5 wrong attempts', () async {
    final auth = make();
    await auth.register(
      type: LoginType.email,
      login: 'a@b.co',
      password: 'secret1',
    );
    auth.lock();
    for (var i = 0; i < 4; i++) {
      expect(
        await auth.unlockWithPassword('a@b.co', 'nope00'),
        AuthResult.wrong,
      );
    }
    expect(
      await auth.unlockWithPassword('a@b.co', 'nope00'),
      AuthResult.lockedOut,
    );
    expect(
      await auth.unlockWithPassword('a@b.co', 'secret1'),
      AuthResult.lockedOut,
    );
    expect(auth.lockedUntil, isNotNull);
  });

  test('change password and delete account', () async {
    final auth = make();
    await auth.register(
      type: LoginType.email,
      login: 'a@b.co',
      password: 'secret1',
    );
    expect(await auth.changePassword('bad', 'newpass2'), isFalse);
    expect(await auth.changePassword('secret1', 'newpass2'), isTrue);
    auth.lock();
    expect(await auth.unlockWithPassword('a@b.co', 'newpass2'), AuthResult.ok);
    await auth.deleteAccountAndData();
    expect(auth.status, AuthStatus.needsRegistration);
    expect(box.isEmpty, isTrue);
  });
}
