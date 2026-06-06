import 'activity_entry.dart';

/// Maximum consecutive non-workout days allowed inside an active streak.
const int kStreakGraceDays = 1;

/// Streak metrics derived from recorded activities.
///
/// A day counts toward a streak if it has at least one qualifying run
/// (see [ActivityEntry.qualifies]) or is a single rest day within the streak
/// (up to [kStreakGraceDays] consecutive miss). The current streak counts
/// calendar days in the active run, including rest days. Today not yet having
/// a run does NOT break the streak — it stays alive until two consecutive
/// days pass without a workout.
class StreakStats {
  const StreakStats({
    required this.current,
    required this.longest,
    required this.workedOutToday,
    required this.workedOutYesterday,
  });

  /// Consecutive calendar days in the active streak counting back from today
  /// (or yesterday if today has no run yet), including up to one rest day.
  final int current;

  /// Best historical streak.
  final int longest;

  /// Whether there is a qualifying run logged for today.
  final bool workedOutToday;

  /// Whether there is a qualifying run logged for yesterday.
  final bool workedOutYesterday;

  static const empty = StreakStats(
    current: 0,
    longest: 0,
    workedOutToday: false,
    workedOutYesterday: false,
  );

  /// Whether the streak would break if no run is logged today (i.e. the user
  /// has already used their rest-day buffer by missing yesterday too).
  bool get atRisk => current > 0 && !workedOutToday && !workedOutYesterday;

  factory StreakStats.fromActivities(List<ActivityEntry> activities,
      {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    // Collect the set of qualifying days.
    final qualifyingDays = <DateTime>{};
    for (final a in activities) {
      if (a.qualifies) qualifyingDays.add(a.day);
    }

    if (qualifyingDays.isEmpty) return StreakStats.empty;

    final workedOutToday = qualifyingDays.contains(today);
    final workedOutYesterday = qualifyingDays.contains(yesterday);

    // Current streak: walk backwards one calendar day at a time. If today has
    // no run, start from yesterday so the streak stays alive until the day ends.
    var current = 0;
    var graceUsed = false;
    var cursor =
        workedOutToday ? today : today.subtract(const Duration(days: 1));
    final earliest = qualifyingDays.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    while (!cursor.isBefore(earliest)) {
      if (qualifyingDays.contains(cursor)) {
        current++;
        graceUsed = false;
      } else if (!graceUsed) {
        current++;
        graceUsed = true;
      } else {
        current--;
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Longest streak: scan qualifying days in chronological order.
    final sorted = qualifyingDays.toList()..sort();
    var longest = 0;
    var run = 0;
    DateTime? prev;
    for (final day in sorted) {
      if (prev == null) {
        run = 1;
      } else {
        final gap = day.difference(prev).inDays;
        if (gap == 1) {
          run++;
        } else if (gap == kStreakGraceDays + 1) {
          run += gap;
        } else {
          run = 1;
        }
      }
      if (run > longest) longest = run;
      prev = day;
    }

    return StreakStats(
      current: current,
      longest: longest,
      workedOutToday: workedOutToday,
      workedOutYesterday: workedOutYesterday,
    );
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
