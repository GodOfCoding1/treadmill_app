import 'package:flutter/material.dart';

/// User preferences for workout reminder notifications.
class ReminderSettings {
  const ReminderSettings({
    required this.dailyEnabled,
    required this.dailyTime,
    required this.streakEnabled,
    required this.streakTime,
  });

  final bool dailyEnabled;
  final TimeOfDay dailyTime;
  final bool streakEnabled;
  final TimeOfDay streakTime;

  static const defaults = ReminderSettings(
    dailyEnabled: false,
    dailyTime: TimeOfDay(hour: 18, minute: 0),
    streakEnabled: false,
    streakTime: TimeOfDay(hour: 20, minute: 0),
  );

  ReminderSettings copyWith({
    bool? dailyEnabled,
    TimeOfDay? dailyTime,
    bool? streakEnabled,
    TimeOfDay? streakTime,
  }) {
    return ReminderSettings(
      dailyEnabled: dailyEnabled ?? this.dailyEnabled,
      dailyTime: dailyTime ?? this.dailyTime,
      streakEnabled: streakEnabled ?? this.streakEnabled,
      streakTime: streakTime ?? this.streakTime,
    );
  }
}
