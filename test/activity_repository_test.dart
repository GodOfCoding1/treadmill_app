import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treadmill_app/data/activity_repository.dart';
import 'package:treadmill_app/domain/activity_entry.dart';

ActivityEntry _entry({
  required int durationSec,
  ActivityType type = ActivityType.manual,
  DateTime? startedAt,
}) {
  final start = startedAt ?? DateTime(2026, 5, 30, 8, 0);
  return ActivityEntry(
    id: start.microsecondsSinceEpoch.toString(),
    startedAt: start,
    endedAt: start.add(Duration(seconds: durationSec)),
    durationSec: durationSec,
    type: type,
    distanceMeters: 3000,
    averageSpeedKmh: 9.0,
  );
}

void main() {
  group('ActivityEntry', () {
    test('qualifies only at or above the 20-minute threshold', () {
      expect(_entry(durationSec: 19 * 60).qualifies, isFalse);
      expect(_entry(durationSec: 20 * 60).qualifies, isTrue);
      expect(_entry(durationSec: 45 * 60).qualifies, isTrue);
    });

    test('day strips the time component', () {
      final e = _entry(
        durationSec: 1500,
        startedAt: DateTime(2026, 5, 30, 14, 37, 12),
      );
      expect(e.day, DateTime(2026, 5, 30));
    });

    test('round-trips through JSON', () {
      final original = _entry(
        durationSec: 1800,
        type: ActivityType.plan,
      );
      final restored = ActivityEntry.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.durationSec, original.durationSec);
      expect(restored.type, ActivityType.plan);
      expect(restored.distanceMeters, 3000);
      expect(restored.averageSpeedKmh, 9.0);
    });
  });

  group('ActivityRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('does not persist runs below the threshold', () async {
      final repo = ActivityRepository();
      final saved = await repo.save(_entry(durationSec: 10 * 60));
      expect(saved, isFalse);
      expect(await repo.loadAll(), isEmpty);
    });

    test('persists qualifying runs and loads them newest-first', () async {
      final repo = ActivityRepository();
      await repo.save(_entry(
          durationSec: 25 * 60, startedAt: DateTime(2026, 5, 28, 8)));
      await repo.save(_entry(
          durationSec: 30 * 60, startedAt: DateTime(2026, 5, 30, 8)));

      final all = await repo.loadAll();
      expect(all.length, 2);
      expect(all.first.startedAt, DateTime(2026, 5, 30, 8));
    });

    test('delete removes an entry', () async {
      final repo = ActivityRepository();
      final entry = _entry(durationSec: 25 * 60);
      await repo.save(entry);
      await repo.delete(entry.id);
      expect(await repo.loadAll(), isEmpty);
    });
  });
}
