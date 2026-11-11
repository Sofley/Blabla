// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../core/security/password_hasher.dart';

import 'package:uuid/uuid.dart';

import '../data/models/account.dart';
import '../data/models/app_user.dart';
import '../data/repositories/auth_repository.dart';
import '../domain/access_policy.dart';

enum AuthStatus { needsRegistration, locked, unlocked }

enum AuthResult { ok, wrong, lockedOut }

/// Local (on-device) registration and app lock.
class AuthController extends ChangeNotifier {
  AuthController(
    this._repo, {
    PasswordHasher hasher = const PasswordHasher(),
    Future<void> Function()? onWipe,
    this.onPasswordEntered,
  }) : _hasher = hasher,
       _onWipe = onWipe {
    _account = _repo.account;
    _users = _repo.users;
    _status = _account == null
        ? AuthStatus.needsRegistration
        : AuthStatus.locked;
  }

  final AuthRepository _repo;
  final PasswordHasher _hasher;
  final Future<void> Function()? _onWipe;

  /// Called with the account password whenever the owner types it
  /// (registration, password unlock, password change), so the backup key
  /// can be derived. The password itself is never stored.
  /// [isNew] is true after registration or a password change.
  final void Function(String password, bool isNew)? onPasswordEntered;

  static const _uuid = Uuid();

  // ---------- Session (who is using the app) ----------

  List<AppUser> _users = [];

  /// Local profiles created by the owner / an administrator.
  List<AppUser> get users => List.unmodifiable(_users);

  AppUser? _currentUser;

  /// null = the owner (the registered account) is using the app.
  AppUser? get currentUser => _currentUser;

  UserRole get role => _currentUser?.role ?? UserRole.owner;

  AccessPolicy get policy => AccessPolicy.forUser(_currentUser);

  String get currentUserName =>
      _currentUser?.name ??
      (_account?.displayName.isNotEmpty == true
          ? _account!.displayName
          : _account?.login ?? '');

  AppUser? userById(String id) {
    for (final u in _users) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// Opens the app as a local profile with its PIN.
  Future<AuthResult> unlockAsUser(String userId, String pin) async {
    final u = userById(userId);
    if (u == null) return AuthResult.wrong;
    if (lockedUntil != null) return AuthResult.lockedOut;
    final ok = await _hasher.verify(pin, u.pinSalt, u.pinHash);
    if (ok) _currentUser = u;
    return _finish(ok);
  }

  /// Ends the session and returns to the lock screen.
  void switchUser() {
    _currentUser = null;
    _status = AuthStatus.locked;
    notifyListeners();
  }

  Future<AppUser> addUser({
    required String name,
    required UserRole role,
    required String pin,
    String? clientId,
  }) async {
    if (!policy.canManageUsers) throw StateError('forbidden');
    if (role == UserRole.owner) throw ArgumentError('role');
    final salt = PasswordHasher.newSalt();
    final user = AppUser(
      id: _uuid.v4(),
      name: name.trim(),
      role: role,
      pinSalt: salt,
      pinHash: await _hasher.hash(pin, salt),
      clientId: role == UserRole.client ? clientId : null,
      createdAt: DateTime.now(),
    );
    _users = [..._users, user];
    await _repo.saveUsers(_users);
    notifyListeners();
    return user;
  }

  Future<void> updateUser(
    AppUser user, {
    String? name,
    UserRole? role,
    String? clientId,
    String? newPin,
  }) async {
    if (!policy.canManageUsers) throw StateError('forbidden');
    if (role == UserRole.owner) throw ArgumentError('role');
    var updated = user.copyWith(name: name?.trim(), role: role);
    final r = updated.role;
    updated = updated.copyWith(
      clientId: r == UserRole.client ? (clientId ?? user.clientId) : null,
    );
    if (newPin != null && newPin.isNotEmpty) {
      final salt = PasswordHasher.newSalt();
      updated = updated.copyWith(
        pinSalt: salt,
        pinHash: await _hasher.hash(newPin, salt),
      );
    }
    _users = [for (final u in _users) u.id == user.id ? updated : u];
    await _repo.saveUsers(_users);
    notifyListeners();
  }

  Future<void> deleteUser(String id) async {
    if (!policy.canManageUsers) throw StateError('forbidden');
    if (_currentUser?.id == id) throw StateError('self');
    _users = _users.where((u) => u.id != id).toList();
    await _repo.saveUsers(_users);
    notifyListeners();
  }

  /// Re-reads profiles (after a restore).
  void reloadUsers() {
    _users = _repo.users;
    notifyListeners();
  }

  Future<void> replaceUsers(List<AppUser> users) async {
    _users = users;
    await _repo.saveUsers(users);
    notifyListeners();
  }

  static const maxAttemptsBeforeLock = 5;

  Account? _account;
  late AuthStatus _status;
  DateTime? _backgroundSince;

  /// Lock again after the app was in background longer than this.
  static const relockAfter = Duration(minutes: 1);

  bool _needsQuickSetup = false;

  /// True right after registration until the user picks a quick unlock.
  bool get needsQuickSetup => _needsQuickSetup;

  void skipQuickSetup() {
    _needsQuickSetup = false;
    notifyListeners();
  }

  AuthStatus get status => _status;
  Account? get account => _account;
  QuickUnlock get quickUnlock => _account?.quickUnlock ?? QuickUnlock.none;

  DateTime? get lockedUntil {
    final t = _repo.lockedUntil;
    return t != null && t.isAfter(DateTime.now()) ? t : null;
  }

  // ---------- Validation helpers ----------

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? normalizeLogin(LoginType type, String raw) {
    final v = raw.trim();
    switch (type) {
      case LoginType.email:
        return _emailRe.hasMatch(v) ? v.toLowerCase() : null;
      case LoginType.phone:
        final digits = v.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.length < 7 || digits.length > 15) return null;
        return '+$digits';
    }
  }

  static bool isStrongEnough(String password) =>
      password.length >= 6 &&
      RegExp(r'[A-Za-zА-Яа-яЁё]').hasMatch(password) &&
      RegExp(r'\d').hasMatch(password);

  // ---------- Registration ----------

  Future<void> register({
    required LoginType type,
    required String login,
    required String password,
    String displayName = '',
  }) async {
    final normalized = normalizeLogin(type, login);
    if (normalized == null) throw ArgumentError('login');
    final salt = PasswordHasher.newSalt();
    final account = Account(
      loginType: type,
      login: normalized,
      displayName: displayName.trim(),
      passwordSalt: salt,
      passwordHash: await _hasher.hash(password, salt),
      createdAt: DateTime.now(),
    );
    await _repo.saveAccount(account);
    await _resetAttempts();
    _account = account;
    _currentUser = null;
    _status = AuthStatus.unlocked;
    _needsQuickSetup = true;
    notifyListeners();
    onPasswordEntered?.call(password, true);
  }

  /// [secret] is the PIN digits or the pattern encoded as "0-4-8-5".
  Future<void> setQuickUnlock(QuickUnlock type, [String secret = '']) async {
    final a = _account;
    if (a == null) return;
    Account updated;
    if (type == QuickUnlock.none) {
      updated = a.copyWith(
        quickUnlock: QuickUnlock.none,
        quickSalt: '',
        quickHash: '',
      );
    } else {
      final salt = PasswordHasher.newSalt();
      updated = a.copyWith(
        quickUnlock: type,
        quickSalt: salt,
        quickHash: await _hasher.hash(secret, salt),
      );
    }
    await _repo.saveAccount(updated);
    _account = updated;
    _needsQuickSetup = false;
    notifyListeners();
  }

  // ---------- Unlock ----------

  Future<AuthResult> unlockWithPassword(String login, String password) async {
    final a = _account;
    if (a == null) return AuthResult.wrong;
    if (lockedUntil != null) return AuthResult.lockedOut;
    final normalized = normalizeLogin(a.loginType, login);
    final ok =
        normalized == a.login &&
        await _hasher.verify(password, a.passwordSalt, a.passwordHash);
    if (ok) _currentUser = null;
    final result = await _finish(ok);
    if (ok) onPasswordEntered?.call(password, false);
    return result;
  }

  Future<AuthResult> unlockWithQuick(String secret) async {
    final a = _account;
    if (a == null || a.quickUnlock == QuickUnlock.none) return AuthResult.wrong;
    if (lockedUntil != null) return AuthResult.lockedOut;
    final ok = await _hasher.verify(secret, a.quickSalt, a.quickHash);
    if (ok) _currentUser = null;
    return _finish(ok);
  }

  Future<AuthResult> _finish(bool ok) async {
    if (ok) {
      await _resetAttempts();
      _status = AuthStatus.unlocked;
      notifyListeners();
      return AuthResult.ok;
    }
    final attempts = _repo.failedAttempts + 1;
    await _repo.setFailedAttempts(attempts);
    if (attempts >= maxAttemptsBeforeLock) {
      // 30 s, 1 min, 2 min … capped at 15 min.
      final factor = 1 << (attempts - maxAttemptsBeforeLock).clamp(0, 5);
      final seconds = (30 * factor).clamp(30, 900);
      await _repo.setLockedUntil(
        DateTime.now().add(Duration(seconds: seconds)),
      );
      notifyListeners();
      return AuthResult.lockedOut;
    }
    notifyListeners();
    return AuthResult.wrong;
  }

  Future<void> _resetAttempts() async {
    await _repo.setFailedAttempts(0);
    await _repo.setLockedUntil(null);
  }

  int get remainingAttempts =>
      (maxAttemptsBeforeLock - _repo.failedAttempts).clamp(0, 99);

  void lock() {
    if (_status != AuthStatus.unlocked) return;
    _status = AuthStatus.locked;
    notifyListeners();
  }

  // ---------- App lifecycle ----------

  void onBackground() => _backgroundSince ??= DateTime.now();

  void onForeground() {
    final since = _backgroundSince;
    _backgroundSince = null;
    if (since != null && DateTime.now().difference(since) > relockAfter) {
      lock();
    }
  }

  // ---------- Account management ----------

  /// Verifies the password without changing the lock state.
  Future<bool> checkPassword(String password) async {
    final a = _account;
    if (a == null) return false;
    return _hasher.verify(password, a.passwordSalt, a.passwordHash);
  }

  Future<bool> changePassword(String current, String next) async {
    final a = _account;
    if (a == null) return false;
    if (!await _hasher.verify(current, a.passwordSalt, a.passwordHash)) {
      return false;
    }
    final salt = PasswordHasher.newSalt();
    final updated = a.copyWith(
      passwordSalt: salt,
      passwordHash: await _hasher.hash(next, salt),
    );
    await _repo.saveAccount(updated);
    _account = updated;
    notifyListeners();
    onPasswordEntered?.call(next, true);
    return true;
  }

  Future<void> updateDisplayName(String name) async {
    final a = _account;
    if (a == null) return;
    _account = a.copyWith(displayName: name.trim());
    await _repo.saveAccount(_account!);
    notifyListeners();
  }

  /// Deletes the account and ALL local data (also used for "forgot password").
  Future<void> deleteAccountAndData() async {
    await _onWipe?.call();
    _account = null;
    _users = [];
    _currentUser = null;
    _status = AuthStatus.needsRegistration;
    notifyListeners();
  }
}
