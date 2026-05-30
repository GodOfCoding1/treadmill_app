import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../core/format.dart';
import '../../domain/workout_plan.dart';
import '../../workout/workout_engine.dart';
import '../router.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workoutEngineProvider).start(widget.plan);
    });
  }

  Future<void> _confirmStop() async {
    final engine = ref.read(workoutEngineProvider);
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop workout?'),
        content: const Text('This will stop the treadmill belt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (shouldStop == true) {
      await engine.stop();
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(workoutEngineProvider);
    final ftms = ref.watch(ftmsServiceProvider);
    final theme = Theme.of(context);

    if (engine.phase == WorkoutPhase.finished) {
      return _SummaryView(
        plan: widget.plan,
        elapsedSec: engine.elapsedTotalSec,
        onDone: () {
          engine.reset();
          context.go(AppRoutes.dashboard);
        },
      );
    }

    final current = engine.currentInterval;
    final next = engine.nextInterval;
    final liveSpeed = ftms.data.instantaneousSpeedKmh;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmStop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.plan.name),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: engine.overallProgress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatDuration(engine.elapsedTotalSec)} / '
                '${formatDuration(engine.totalDurationSec)}',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                current?.label ?? '—',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                formatClock(engine.remainingInIntervalSec),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (current != null)
                Text(
                  'Target ${current.speedKmh.toStringAsFixed(1)} km/h'
                  '${current.inclinePct > 0 ? '  ·  ${current.inclinePct.toStringAsFixed(1)}% incline' : ''}',
                  style: theme.textTheme.titleMedium,
                ),
              const SizedBox(height: 16),
              _LiveVsTarget(
                live: liveSpeed,
                target: current?.speedKmh,
              ),
              const Spacer(),
              if (next != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.skip_next),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Up next: ${next.label} — '
                          '${formatClock(next.durationSec)} at '
                          '${next.speedKmh.toStringAsFixed(1)} km/h',
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: engine.phase == WorkoutPhase.paused
                        ? FilledButton.icon(
                            onPressed: engine.resume,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Resume'),
                          )
                        : FilledButton.tonalIcon(
                            onPressed: engine.pause,
                            icon: const Icon(Icons.pause),
                            label: const Text('Pause'),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade200,
                      ),
                      onPressed: _confirmStop,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveVsTarget extends StatelessWidget {
  const _LiveVsTarget({this.live, this.target});
  final double? live;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            Text('Live', style: theme.textTheme.labelMedium),
            Text('${(live ?? 0).toStringAsFixed(1)} km/h',
                style: theme.textTheme.titleLarge),
          ],
        ),
        const SizedBox(width: 32),
        Column(
          children: [
            Text('Target', style: theme.textTheme.labelMedium),
            Text('${(target ?? 0).toStringAsFixed(1)} km/h',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ],
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.plan,
    required this.elapsedSec,
    required this.onDone,
  });

  final WorkoutPlan plan;
  final int elapsedSec;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Workout complete!',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(plan.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              _SummaryRow(
                  label: 'Total time', value: formatDuration(elapsedSec)),
              _SummaryRow(
                  label: 'Intervals', value: '${plan.intervalCount}'),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onDone,
                child: const Text('Done'),
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
