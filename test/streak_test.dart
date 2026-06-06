import 'package:flutter_test/flutter_test.dart';
import 'package:treadmill_app/domain/activity_entry.dart';
import 'package:treadmill_app/domain/streak.dart';

ActivityEntry _entry({required DateTime day}) {
  final start = DateTime(day.year, day.month, day.day, 8);
  return ActivityEntry(
    id: start.microsecondsSinceEpoch.toString(),
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 25)),
    durationSec: 25 * 60,
    type: ActivityType.manual,
  );
}

void main() {
  group('StreakStats.fromActivities', () {
    final mon = DateTime(2026, 6, 1);
    final tue = DateTime(2026, 6, 2);
    final wed = DateTime(2026, 6, 3);
    final thu = DateTime(2026, 6, 4);
    final fri = DateTime(2026, 6, 5);

    test('counts rest day when one day is skipped between workouts', () {
      final stats = StreakStats.fromActivities(
        [_entry(day: mon), _entry(day: wed)],
        now: wed,
      );

      expect(stats.current, 3);
      expect(stats.workedOutToday, isTrue);
    });

    test('keeps streak alive through one rest day before today ends', () {
      final stats = StreakStats.fromActivities(
        [_entry(day: mon)],
        now: wed,
      );

      expect(stats.current, 2);
      expect(stats.atRisk, isTrue);
      expect(stats.workedOutToday, isFalse);
      expect(stats.workedOutYesterday, isFalse);
    });

    test('breaks streak after two consecutive missed days', () {
      final stats = StreakStats.fromActivities(
        [_entry(day: mon)],
        now: thu,
      );

      expect(stats.current, 0);
    });

    test('does not warn when yesterday workout covers rest-day buffer', () {
      final stats = StreakStats.fromActivities(
        [_entry(day: mon), _entry(day: tue)],
        now: wed,
      );

      expect(stats.current, 2);
      expect(stats.atRisk, isFalse);
      expect(stats.workedOutYesterday, isTrue);
    });

    test('longest streak includes single rest days between workouts', () {
      final stats = StreakStats.fromActivities(
        [_entry(day: mon), _entry(day: wed), _entry(day: fri)],
      );

      expect(stats.longest, 5);
    });

    test('longest streak resets after two consecutive missed days', () {
      final stats = StreakStats.fromActivities(
        [_entry(day: mon), _entry(day: thu)],
      );

      expect(stats.longest, 1);
    });
  });
}
