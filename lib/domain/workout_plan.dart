/// A single segment of a workout: hold a speed/incline for a duration.
class WorkoutInterval {
  WorkoutInterval({
    required this.label,
    required this.durationSec,
    required this.speedKmh,
    this.inclinePct = 0.0,
  });

  final String label;
  final int durationSec;
  final double speedKmh;
  final double inclinePct;

  WorkoutInterval copyWith({
    String? label,
    int? durationSec,
    double? speedKmh,
    double? inclinePct,
  }) {
    return WorkoutInterval(
      label: label ?? this.label,
      durationSec: durationSec ?? this.durationSec,
      speedKmh: speedKmh ?? this.speedKmh,
      inclinePct: inclinePct ?? this.inclinePct,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'durationSec': durationSec,
        'speedKmh': speedKmh,
        'inclinePct': inclinePct,
      };

  factory WorkoutInterval.fromJson(Map<String, dynamic> json) {
    return WorkoutInterval(
      label: json['label'] as String? ?? 'Interval',
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 60,
      speedKmh: (json['speedKmh'] as num?)?.toDouble() ?? 4.0,
      inclinePct: (json['inclinePct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// An ordered sequence of intervals plus an id and friendly name.
class WorkoutPlan {
  WorkoutPlan({
    required this.id,
    required this.name,
    required this.intervals,
  });

  final String id;
  final String name;
  final List<WorkoutInterval> intervals;

  int get totalDurationSec =>
      intervals.fold(0, (sum, i) => sum + i.durationSec);

  int get intervalCount => intervals.length;

  WorkoutPlan copyWith({String? name, List<WorkoutInterval>? intervals}) {
    return WorkoutPlan(
      id: id,
      name: name ?? this.name,
      intervals: intervals ?? this.intervals,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'intervals': intervals.map((i) => i.toJson()).toList(),
      };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    final rawIntervals = (json['intervals'] as List?) ?? const [];
    return WorkoutPlan(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Workout',
      intervals: rawIntervals
          .map((e) => WorkoutInterval.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static WorkoutPlan sample() {
    return WorkoutPlan(
      id: 'sample-30min-interval',
      name: '30 Min Interval Run',
      intervals: [
        WorkoutInterval(label: 'Warm up', durationSec: 300, speedKmh: 4.0),
        WorkoutInterval(label: 'Easy jog', durationSec: 300, speedKmh: 6.0),
        WorkoutInterval(
            label: 'Run', durationSec: 180, speedKmh: 9.0, inclinePct: 1.0),
        WorkoutInterval(label: 'Recovery', durationSec: 120, speedKmh: 6.0),
        WorkoutInterval(label: 'Sprint', durationSec: 60, speedKmh: 12.0),
        WorkoutInterval(label: 'Recovery', durationSec: 120, speedKmh: 6.0),
        WorkoutInterval(label: 'Cool down', durationSec: 300, speedKmh: 4.0),
      ],
    );
  }
}
