import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Top-level entry point required by `flutter_foreground_task`. The service
/// exists purely to keep the app process alive and unfrozen while a workout is
/// active — all BLE and timer logic stays in the main isolate — so this handler
/// is intentionally a no-op.
@pragma('vm:entry-point')
void _foregroundCallback() {
  FlutterForegroundTask.setTaskHandler(_WorkoutTaskHandler());
}

class _WorkoutTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Thin wrapper around an Android foreground service that keeps the BLE
/// connection and the workout ticker running when the app is backgrounded
/// (incoming call, switching to a music app, screen off).
///
/// No-ops on non-Android platforms.
class WorkoutForegroundService {
  WorkoutForegroundService._();

  static const int _serviceId = 2001;
  static bool _initialized = false;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Initializes the notification channel and task options. Safe to call more
  /// than once.
  static void init() {
    if (!_supported || _initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'workout_foreground',
        channelName: 'Active workout',
        channelDescription:
            'Keeps the treadmill connected and the workout running while the '
            'app is in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The main isolate owns the timer; we never need a repeating event.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  /// Requests notification permission and (best-effort) a battery optimization
  /// exemption so Android does not freeze the process during long workouts.
  static Future<void> requestPermissions() async {
    if (!_supported) return;
    final notif = await FlutterForegroundTask.checkNotificationPermission();
    if (notif != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  /// Starts (or updates, if already running) the foreground service.
  static Future<void> start({
    required String title,
    required String text,
  }) async {
    if (!_supported) return;
    init();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: title,
      notificationText: text,
      callback: _foregroundCallback,
    );
  }

  /// Updates the ongoing notification text (e.g. elapsed time / current speed).
  static Future<void> update({
    required String title,
    required String text,
  }) async {
    if (!_supported) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  static Future<void> stop() async {
    if (!_supported) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}
