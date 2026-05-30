import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/format.dart';
import '../../domain/activity_entry.dart';

class ActivityCalendarScreen extends ConsumerStatefulWidget {
  const ActivityCalendarScreen({super.key});

  @override
  ConsumerState<ActivityCalendarScreen> createState() =>
      _ActivityCalendarScreenState();
}

class _ActivityCalendarScreenState
    extends ConsumerState<ActivityCalendarScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load activity: $e')),
        data: (activities) {
          final byDay = <DateTime, List<ActivityEntry>>{};
          for (final a in activities) {
            byDay.putIfAbsent(a.day, () => []).add(a);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _MonthHeader(
                month: _visibleMonth,
                onPrev: () => _changeMonth(-1),
                onNext: () => _changeMonth(1),
              ),
              const SizedBox(height: 12),
              _CalendarGrid(
                month: _visibleMonth,
                byDay: byDay,
                onDayTap: (day, entries) =>
                    _showDayDetails(context, day, entries),
              ),
              const SizedBox(height: 16),
              _MonthSummary(month: _visibleMonth, byDay: byDay),
              const SizedBox(height: 16),
              const _MinDurationNote(),
            ],
          );
        },
      ),
    );
  }

  void _showDayDetails(
      BuildContext context, DateTime day, List<ActivityEntry> entries) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DayDetailsSheet(day: day, entries: entries),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${_monthName(month.month)} ${month.year}',
          style: theme.textTheme.titleLarge,
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.byDay,
    required this.onDayTap,
  });

  final DateTime month;
  final Map<DateTime, List<ActivityEntry>> byDay;
  final void Function(DateTime day, List<ActivityEntry> entries) onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday: Mon=1..Sun=7. Grid starts on Monday.
    final leadingBlanks = firstOfMonth.weekday - 1;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[];
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (final w in weekdays) {
      cells.add(Center(
        child: Text(w,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.hintColor)),
      ));
    }
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(month.year, month.month, d);
      final entries = byDay[day] ?? const [];
      final hasActivity = entries.isNotEmpty;
      final isToday = day == todayDay;
      cells.add(
        _DayCell(
          dayNumber: d,
          hasActivity: hasActivity,
          isToday: isToday,
          onTap: hasActivity ? () => onDayTap(day, entries) : null,
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNumber,
    required this.hasActivity,
    required this.isToday,
    this.onTap,
  });

  final int dayNumber;
  final bool hasActivity;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: hasActivity
              ? theme.colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            '$dayNumber',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasActivity
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight:
                  hasActivity || isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthSummary extends ConsumerWidget {
  const _MonthSummary({required this.month, required this.byDay});

  final DateTime month;
  final Map<DateTime, List<ActivityEntry>> byDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streak = ref.watch(streakStatsProvider).asData?.value;
    final monthEntries = byDay.entries
        .where((e) => e.key.year == month.year && e.key.month == month.month)
        .toList();
    final activeDays = monthEntries.length;
    var totalDurationSec = 0;
    var totalDistanceMeters = 0;
    var hasDistance = false;
    for (final e in monthEntries) {
      for (final a in e.value) {
        totalDurationSec += a.durationSec;
        if (a.distanceMeters != null) {
          totalDistanceMeters += a.distanceMeters!;
          hasDistance = true;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This month', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (streak != null) ...[
              _SummaryRow(
                  label: 'Current streak', value: '${streak.current} days'),
              _SummaryRow(
                  label: 'Longest streak', value: '${streak.longest} days'),
            ],
            _SummaryRow(
                label: 'Active days', value: '$activeDays'),
            _SummaryRow(
                label: 'Total time',
                value: formatDuration(totalDurationSec)),
            if (hasDistance)
              _SummaryRow(
                label: 'Total distance',
                value: '${(totalDistanceMeters / 1000).toStringAsFixed(2)} km',
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MinDurationNote extends StatelessWidget {
  const _MinDurationNote();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.info_outline, size: 18, color: theme.hintColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Runs count as activity after 20 minutes. Keep it up!',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.hintColor),
          ),
        ),
      ],
    );
  }
}

class _DayDetailsSheet extends StatelessWidget {
  const _DayDetailsSheet({required this.day, required this.entries});

  final DateTime day;
  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_weekdayName(day.weekday)}, ${_monthName(day.month)} ${day.day}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${entries.length} '
              '${entries.length == 1 ? 'activity' : 'activities'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ActivityCard(entry: entries[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.entry});
  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlan = entry.type == ActivityType.plan;
    final title = isPlan
        ? (entry.planName ?? 'Workout plan')
        : 'Manual run';

    final stats = <String>[];
    if (entry.distanceMeters != null) {
      stats.add(
          '${(entry.distanceMeters! / 1000).toStringAsFixed(2)} km');
    }
    if (entry.averageSpeedKmh != null) {
      stats.add('${entry.averageSpeedKmh!.toStringAsFixed(1)} km/h avg');
    }
    if (entry.energyKcal != null) {
      stats.add('${entry.energyKcal} kcal');
    }
    if (entry.heartRateBpm != null) {
      stats.add('${entry.heartRateBpm} bpm');
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isPlan ? Icons.list_alt : Icons.directions_run,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                Text(_timeOfDay(entry.startedAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Duration ${formatDuration(entry.durationSec)}'
              '${entry.completed == true ? '  ·  Completed' : ''}'
              '${entry.completed == false ? '  ·  Stopped early' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                stats.join('  ·  '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _monthName(int month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return names[(month - 1) % 12];
}

String _weekdayName(int weekday) {
  const names = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
    'Saturday', 'Sunday',
  ];
  return names[(weekday - 1) % 7];
}

String _timeOfDay(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}
