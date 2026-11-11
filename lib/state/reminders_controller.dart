// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Reminder settings of one user: every [everyDays] days (0 = off, 1, 3
/// or 7) at [time].
class ReminderSettings {
  const ReminderSettings({
    this.everyDays = 0,
    this.time = const TimeOfDay(hour: 9, minute: 0),
  });

  static const choices = [0, 1, 3, 7];

  final int everyDays;
  final TimeOfDay time;

  bool get enabled => everyDays > 0;

  ReminderSettings copyWith({int? everyDays, TimeOfDay? time}) =>
      ReminderSettings(
        everyDays: everyDays ?? this.everyDays,
        time: time ?? this.time,
      );

  Map<String, dynamic> toJson() => {
    'days': everyDays,
    'h': time.hour,
    'm': time.minute,
  };

  static ReminderSettings fromJson(Map<dynamic, dynamic>? j) {
    if (j == null) return const ReminderSettings();
    final days = (j['days'] as num?)?.toInt() ?? 0;
    return ReminderSettings(
      everyDays: choices.contains(days) ? days : 0,
      time: TimeOfDay(
        hour: ((j['h'] as num?)?.toInt() ?? 9).clamp(0, 23),
        minute: ((j['m'] as num?)?.toInt() ?? 0).clamp(0, 59),
      ),
    );
  }

  /// The next [count] reminder moments after [now] (local time).
  List<DateTime> nextTimes(DateTime now, {int count = 10}) {
    if (!enabled) return const [];
    var t = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return [
      for (var i = 0; i < count; i++)
        DateTime(
          t.year,
          t.month,
          t.day + i * everyDays,
          time.hour,
          time.minute,
        ),
    ];
  }
}

/// Shows reminders on the device. Replaced by a fake in tests.
abstract class ReminderScheduler {
  Future<bool> requestPermission();
  Future<void> schedule(List<DateTime> times, String title, String body);
  Future<void> cancelAll();
}

class LocalNotificationScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<void> schedule(List<DateTime> times, String title, String body) async {
    await _init();
    await _plugin.cancelAll();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'deal_reminders',
        'Reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (var i = 0; i < times.length; i++) {
      await _plugin.zonedSchedule(
        1000 + i,
        title,
        body,
        // A fixed instant: rescheduled at every start, so no time zone
        // database lookup for the device zone is needed.
        tz.TZDateTime.from(times[i], tz.UTC),
        details,
        // Inexact: no "exact alarm" permission is required.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }
}

class FakeReminderScheduler implements ReminderScheduler {
  List<DateTime> scheduled = [];
  bool permission = true;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> schedule(
    List<DateTime> times,
    String title,
    String body,
  ) async => scheduled = times;

  @override
  Future<void> cancelAll() async => scheduled = [];
}

/// Per-user reminders: daily, every 3 days or weekly at a chosen time.
class RemindersController extends ChangeNotifier {
  RemindersController(
    this._box, {
    required String Function() userId,
    ReminderScheduler? scheduler,
  }) : _userId = userId,
       _scheduler = scheduler ?? LocalNotificationScheduler();

  final Box _box;
  final String Function() _userId;
  final ReminderScheduler _scheduler;

  Map<dynamic, dynamic> get _all => (_box.get('reminders') as Map?) ?? const {};

  ReminderSettings get current =>
      ReminderSettings.fromJson(_all[_userId()] as Map?);

  /// Saves the setting of the current user and reschedules.
  /// Returns false when notifications are not allowed on the phone.
  Future<bool> update(
    ReminderSettings value, {
    required String title,
    required String body,
  }) async {
    await _box.put('reminders', {..._all, _userId(): value.toJson()});
    notifyListeners();
    if (value.enabled && !await _scheduler.requestPermission()) {
      return false;
    }
    await reschedule(title: title, body: body);
    return true;
  }

  /// Plans the next reminders of the current user (called at every start
  /// and after a user switch).
  Future<void> reschedule({required String title, required String body}) async {
    try {
      final s = current;
      if (!s.enabled) {
        await _scheduler.cancelAll();
        return;
      }
      await _scheduler.schedule(s.nextTimes(DateTime.now()), title, body);
    } catch (e) {
      debugPrint('reminders: $e');
    }
  }
}
