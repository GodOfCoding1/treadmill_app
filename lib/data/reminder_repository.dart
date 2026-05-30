import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reminder_settings.dart';

/// Persists [ReminderSettings] in shared_preferences.
class ReminderRepository {
  static const _dailyEnabled = 'reminder_daily_enabled';
  static const _dailyTime = 'reminder_daily_time';
  static const _streakEnabled = 'reminder_streak_enabled';
  static const _streakTime = 'reminder_streak_time';

  Future<ReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      dailyEnabled: prefs.getBool(_dailyEnabled) ??
          ReminderSettings.defaults.dailyEnabled,
      dailyTime: _readTime(prefs, _dailyTime) ??
          ReminderSettings.defaults.dailyTime,
      streakEnabled: prefs.getBool(_streakEnabled) ??
          ReminderSettings.defaults.streakEnabled,
      streakTime: _readTime(prefs, _streakTime) ??
          ReminderSettings.defaults.streakTime,
    );
  }

  Future<void> save(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyEnabled, settings.dailyEnabled);
    await prefs.setString(_dailyTime, _encodeTime(settings.dailyTime));
    await prefs.setBool(_streakEnabled, settings.streakEnabled);
    await prefs.setString(_streakTime, _encodeTime(settings.streakTime));
  }

  static String _encodeTime(TimeOfDay t) => '${t.hour}:${t.minute}';

  static TimeOfDay? _readTime(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}
