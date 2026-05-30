/// Whether an activity came from a structured workout plan or manual control.
enum ActivityType { manual, plan }

/// Minimum elapsed time (seconds) before a run counts as a tracked activity.
const int kActivityMinDurationSec = 20 * 60;

/// A single recorded treadmill session, persisted locally for the calendar view.
class ActivityEntry {
  ActivityEntry({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.type,
    this.planId,
    this.planName,
    this.completed,
    this.distanceMeters,
    this.averageSpeedKmh,
    this.energyKcal,
    this.heartRateBpm,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSec;
  final ActivityType type;

  /// Plan metadata (only for [ActivityType.plan]).
  final String? planId;
  final String? planName;

  /// Whether a plan ran to completion (null for manual runs).
  final bool? completed;

  final int? distanceMeters;
  final double? averageSpeedKmh;
  final int? energyKcal;
  final int? heartRateBpm;

  /// Whether this run is long enough to count as a tracked activity.
  bool get qualifies => durationSec >= kActivityMinDurationSec;

  /// The local calendar day this activity belongs to (date-only).
  DateTime get day => DateTime(startedAt.year, startedAt.month, startedAt.day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'durationSec': durationSec,
        'type': type.name,
        'planId': planId,
        'planName': planName,
        'completed': completed,
        'distanceMeters': distanceMeters,
        'averageSpeedKmh': averageSpeedKmh,
        'energyKcal': energyKcal,
        'heartRateBpm': heartRateBpm,
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ??
          DateTime.now(),
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
      type: ActivityType.values.firstWhere(
        (t) => t.name == (json['type'] as String?),
        orElse: () => ActivityType.manual,
      ),
      planId: json['planId'] as String?,
      planName: json['planName'] as String?,
      completed: json['completed'] as bool?,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      averageSpeedKmh: (json['averageSpeedKmh'] as num?)?.toDouble(),
      energyKcal: (json['energyKcal'] as num?)?.toInt(),
      heartRateBpm: (json['heartRateBpm'] as num?)?.toInt(),
    );
  }
}
