import 'activity_entry.dart';

/// Streak metrics derived from recorded activities.
///
/// A day counts toward a streak only if it has at least one qualifying run
/// (see [ActivityEntry.qualifies]). The current streak is the number of
/// consecutive qualifying days counting back from today. Today not yet having
/// a run does NOT break the streak — it stays "alive but at risk" until the
/// day ends.
class StreakStats {
  const StreakStats({
    required this.current,
    required this.longest,
    required this.workedOutToday,
  });

  /// Consecutive qualifying days counting back from today (or yesterday if
  /// today has no run yet).
  final int current;

  /// Best historical streak.
  final int longest;

  /// Whether there is a qualifying run logged for today.
  final bool workedOutToday;

  static const empty =
      StreakStats(current: 0, longest: 0, workedOutToday: false);

  /// Whether the current streak is alive but would break if no run is logged
  /// today (i.e. the user has a streak going but hasn't run yet today).
  bool get atRisk => current > 0 && !workedOutToday;

  factory StreakStats.fromActivities(List<ActivityEntry> activities,
      {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());

    // Collect the set of qualifying days.
    final qualifyingDays = <DateTime>{};
    for (final a in activities) {
      if (a.qualifies) qualifyingDays.add(a.day);
    }

    if (qualifyingDays.isEmpty) return StreakStats.empty;

    final workedOutToday = qualifyingDays.contains(today);

    // Current streak: walk backwards from today. If today has no run, start
    // from yesterday so the streak stays alive until the day ends.
    var current = 0;
    var cursor = workedOutToday ? today : today.subtract(const Duration(days: 1));
    while (qualifyingDays.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Longest streak: scan all qualifying days in chronological order.
    final sorted = qualifyingDays.toList()..sort();
    var longest = 0;
    var run = 0;
    DateTime? prev;
    for (final day in sorted) {
      if (prev != null && day.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      prev = day;
    }

    return StreakStats(
      current: current,
      longest: longest,
      workedOutToday: workedOutToday,
    );
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
