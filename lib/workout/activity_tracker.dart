import '../ble/ftms_service.dart';
import '../data/activity_repository.dart';
import '../domain/activity_entry.dart';

/// Captures the start state of a treadmill run and, on completion, builds and
/// persists an [ActivityEntry] when the run is long enough to qualify.
///
/// Used by both the manual dashboard controls and the workout engine so a run
/// of either kind is recorded the same way.
class ActivityTracker {
  ActivityTracker(this._ftms, this._repo);

  final FtmsService _ftms;
  final ActivityRepository _repo;

  DateTime? _startedAt;
  int? _startDistanceMeters;
  ActivityType _type = ActivityType.manual;
  String? _planId;
  String? _planName;

  bool get isTracking => _startedAt != null;

  /// Begins tracking a run. Snapshots the current distance so we can compute a
  /// delta even if the treadmill reports a cumulative total across sessions.
  void begin({
    ActivityType type = ActivityType.manual,
    String? planId,
    String? planName,
  }) {
    _startedAt = DateTime.now();
    _startDistanceMeters = _ftms.data.totalDistanceMeters;
    _type = type;
    _planId = planId;
    _planName = planName;
  }

  /// Finishes tracking and persists the run if it qualifies. [durationSec] can
  /// be supplied by callers (e.g. the workout engine knows precise elapsed
  /// time); otherwise it's derived from wall-clock time. Returns the saved
  /// entry, or null if nothing was recorded.
  Future<ActivityEntry?> complete({
    int? durationSec,
    bool? completed,
  }) async {
    final startedAt = _startedAt;
    if (startedAt == null) return null;

    final endedAt = DateTime.now();
    final elapsed =
        durationSec ?? endedAt.difference(startedAt).inSeconds;

    final data = _ftms.data;
    int? distance;
    final endDistance = data.totalDistanceMeters;
    if (endDistance != null) {
      final start = _startDistanceMeters ?? 0;
      final delta = endDistance - start;
      distance = delta >= 0 ? delta : endDistance;
    }

    double? avgSpeed = data.averageSpeedKmh;
    if (avgSpeed == null && distance != null && elapsed > 0) {
      avgSpeed = (distance / 1000) / (elapsed / 3600);
    }

    final entry = ActivityEntry(
      id: startedAt.microsecondsSinceEpoch.toString(),
      startedAt: startedAt,
      endedAt: endedAt,
      durationSec: elapsed,
      type: _type,
      planId: _planId,
      planName: _planName,
      completed: completed,
      distanceMeters: distance,
      averageSpeedKmh: avgSpeed,
      energyKcal: data.totalEnergyKcal,
      heartRateBpm: data.heartRateBpm,
    );

    _reset();

    final saved = await _repo.save(entry);
    return saved ? entry : null;
  }

  /// Discards the current tracking state without saving.
  void cancel() => _reset();

  void _reset() {
    _startedAt = null;
    _startDistanceMeters = null;
    _type = ActivityType.manual;
    _planId = null;
    _planName = null;
  }
}
