import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_settings.dart';
import '../domain/streak.dart';

/// Wraps [FlutterLocalNotificationsPlugin] for the two reminder types:
/// a configurable daily workout reminder and a streak-at-risk nudge.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  static const _dailyReminderId = 1001;
  static const _streakNudgeId = 1002;

  static const _channelId = 'workout_reminders';
  static const _channelName = 'Workout reminders';
  static const _channelDescription =
      'Daily workout reminders and streak nudges.';

  Future<void> init() async {
    if (_initialised) return;

    tz.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Fall back to the default (UTC) if the platform timezone is unknown.
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _initialised = true;
  }

  /// Requests OS permission to post notifications. Returns true if granted.
  Future<bool> requestPermissions() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Schedules a daily repeating reminder at [time].
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await init();
    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Time for your run',
      'Hop on the treadmill and get your workout in today.',
      _nextInstanceOf(time),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() => _plugin.cancel(_dailyReminderId);

  /// Schedules a daily streak nudge at [time], but only if the user hasn't
  /// worked out today (so completed days don't get nagged). Repeats daily and
  /// is re-evaluated whenever activities change.
  Future<void> scheduleStreakNudge(TimeOfDay time, StreakStats stats) async {
    await init();
    await _plugin.cancel(_streakNudgeId);
    if (stats.workedOutToday) {
      // Already done today; (re)schedule for tomorrow onwards via daily match.
    }

    final message = stats.current > 0
        ? 'Keep your ${stats.current}-day streak alive — get a run in!'
        : 'Start a new streak today. A quick run counts!';

    await _plugin.zonedSchedule(
      _streakNudgeId,
      "Don't break your streak",
      message,
      _nextInstanceOf(time),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelStreakNudge() => _plugin.cancel(_streakNudgeId);

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Applies the given [settings] by scheduling or cancelling each reminder.
  /// The streak nudge text reflects the latest [stats].
  Future<void> apply(ReminderSettings settings, StreakStats stats) async {
    await init();
    if (settings.dailyEnabled) {
      await scheduleDailyReminder(settings.dailyTime);
    } else {
      await cancelDailyReminder();
    }
    if (settings.streakEnabled) {
      await scheduleStreakNudge(settings.streakTime, stats);
    } else {
      await cancelStreakNudge();
    }
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
