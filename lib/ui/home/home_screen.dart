import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../ble/ftms_service.dart';
import '../../core/format.dart';
import '../../domain/activity_entry.dart';
import '../../domain/workout_plan.dart';
import '../connect_gate.dart';
import '../router.dart';
import '../widgets/streak_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treadmill'),
        actions: const [
          _ConnectionChip(),
          SizedBox(width: 4),
          _RemindersButton(),
          SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const StreakBanner(),
          const SizedBox(height: 16),
          const _WeeklySummaryCard(),
          const SizedBox(height: 24),
          Text('Quick start',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _QuickStartPlans(),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: () =>
                ensureConnectedThen(context, ref, const OpenControlIntent()),
            icon: const Icon(Icons.directions_run),
            label: const Text('Manual run (no plan)'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionChip extends ConsumerWidget {
  const _ConnectionChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ftms = ref.watch(ftmsServiceProvider);
    final connected = ftms.status == FtmsConnectionStatus.ready;
    final busy = ftms.status == FtmsConnectionStatus.connecting ||
        ftms.status == FtmsConnectionStatus.discovering ||
        ftms.status == FtmsConnectionStatus.requestingControl ||
        ftms.status == FtmsConnectionStatus.reconnecting;

    final color = connected
        ? theme.colorScheme.primary
        : (busy ? Colors.amber : theme.disabledColor);
    final label = connected
        ? 'Connected'
        : (busy ? 'Connecting' : 'Disconnected');

    return ActionChip(
      avatar: Icon(Icons.circle, size: 12, color: color),
      label: Text(label),
      onPressed: () {
        if (connected) {
          context.push(AppRoutes.control);
        } else {
          context.push(AppRoutes.scan);
        }
      },
    );
  }
}

class _RemindersButton extends StatelessWidget {
  const _RemindersButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Reminders',
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () => context.push(AppRoutes.reminders),
    );
  }
}

class _WeeklySummaryCard extends ConsumerWidget {
  const _WeeklySummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activitiesAsync = ref.watch(activitiesProvider);

    final activities = activitiesAsync.asData?.value ?? const <ActivityEntry>[];
    final now = DateTime.now();
    // Start of the current week (Monday).
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final thisWeek = activities.where((a) {
      final d = a.day;
      return !d.isBefore(weekStart);
    }).toList();

    final runs = thisWeek.length;
    final totalSec =
        thisWeek.fold<int>(0, (sum, a) => sum + a.durationSec);
    final distanceMeters = thisWeek.fold<int>(
        0, (sum, a) => sum + (a.distanceMeters ?? 0));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('This week',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => context.go(AppRoutes.activity),
                  child: const Text('View calendar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _SummaryStat(label: 'Runs', value: '$runs'),
                _SummaryStat(
                    label: 'Time', value: formatDuration(totalSec)),
                _SummaryStat(
                  label: 'Distance',
                  value: '${(distanceMeters / 1000).toStringAsFixed(1)} km',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              )),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }
}

class _QuickStartPlans extends ConsumerWidget {
  const _QuickStartPlans();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);

    return plansAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Failed to load plans: $e'),
      data: (plans) {
        if (plans.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No workout plans yet.'),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => context.go(AppRoutes.plans),
                    child: const Text('Create a plan'),
                  ),
                ],
              ),
            ),
          );
        }

        final top = plans.take(3).toList();
        return Column(
          children: [
            ...top.map((p) => _QuickPlanTile(plan: p)),
            if (plans.length > top.length)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.plans),
                  child: Text('See all ${plans.length} plans'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickPlanTile extends ConsumerWidget {
  const _QuickPlanTile({required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(plan.name),
        subtitle: Text(
          '${plan.intervalCount} intervals  ·  '
          '${formatDuration(plan.totalDurationSec)} total',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        trailing: FilledButton.icon(
          onPressed: () =>
              ensureConnectedThen(context, ref, StartPlanIntent(plan)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start'),
        ),
      ),
    );
  }
}
