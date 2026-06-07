import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../core/format.dart';
import '../../domain/workout_plan.dart';
import '../../workout/workout_engine.dart';
import '../layout/responsive.dart';
import '../router.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workoutEngineProvider).start(widget.plan);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the foreground: the 1-second ticker may have been throttled
    // while backgrounded, so force an immediate wall-clock resync to correct
    // the countdown and re-apply the interval that should be active now.
    if (state == AppLifecycleState.resumed) {
      ref.read(workoutEngineProvider).syncFromWallClock();
    }
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
      ref.invalidate(activitiesProvider);
      await rescheduleReminders(ref);
      if (mounted) {
        context.canPop() ? context.pop() : context.go(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(workoutEngineProvider);
    final ftms = ref.watch(ftmsServiceProvider);

    if (engine.phase == WorkoutPhase.finished) {
      return _SummaryView(
        plan: widget.plan,
        elapsedSec: engine.elapsedTotalSec,
        onDone: () async {
          await ref
              .read(interstitialAdServiceProvider)
              .showPostWorkoutAdIfReady();
          if (!context.mounted) return;
          engine.reset();
          ref.invalidate(activitiesProvider);
          rescheduleReminders(ref);
          context.go(AppRoutes.home);
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
        body: _WorkoutBody(
          engine: engine,
          current: current,
          next: next,
          liveSpeed: liveSpeed,
          onStop: _confirmStop,
        ),
      ),
    );
  }
}

class _WorkoutBody extends StatelessWidget {
  const _WorkoutBody({
    required this.engine,
    required this.current,
    required this.next,
    required this.liveSpeed,
    required this.onStop,
  });

  final WorkoutEngine engine;
  final WorkoutInterval? current;
  final WorkoutInterval? next;
  final double? liveSpeed;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return OrientationLayout(
      portrait: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _OverallProgress(engine: engine),
            const Spacer(),
            _IntervalFocus(engine: engine, current: current),
            const SizedBox(height: 16),
            _LiveVsTarget(live: liveSpeed, target: current?.speedKmh),
            const Spacer(),
            if (next != null) _NextIntervalCard(next: next!),
            const SizedBox(height: 20),
            _WorkoutActions(engine: engine, onStop: onStop),
          ],
        ),
      ),
      landscape: (_) => LayoutBuilder(
        builder: (context, constraints) {
          final shouldScroll = constraints.maxHeight < 400;
          final content = _LandscapeWorkoutBody(
            engine: engine,
            current: current,
            next: next,
            liveSpeed: liveSpeed,
            onStop: onStop,
            scrollSafe: shouldScroll,
          );

          if (shouldScroll) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: content,
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          );
        },
      ),
    );
  }
}

class _LandscapeWorkoutBody extends StatelessWidget {
  const _LandscapeWorkoutBody({
    required this.engine,
    required this.current,
    required this.next,
    required this.liveSpeed,
    required this.onStop,
    required this.scrollSafe,
  });

  final WorkoutEngine engine;
  final WorkoutInterval? current;
  final WorkoutInterval? next;
  final double? liveSpeed;
  final VoidCallback onStop;
  final bool scrollSafe;

  @override
  Widget build(BuildContext context) {
    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OverallProgress(engine: engine),
        const SizedBox(height: 16),
        _LiveVsTarget(live: liveSpeed, target: current?.speedKmh),
        const SizedBox(height: 16),
        if (next != null) _NextIntervalCard(next: next!),
        if (scrollSafe) const SizedBox(height: 20) else const Spacer(),
        _WorkoutActions(engine: engine, onStop: onStop),
      ],
    );

    return Row(
      crossAxisAlignment:
          scrollSafe ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: Center(
            child: _IntervalFocus(
              engine: engine,
              current: current,
              compact: true,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(flex: 9, child: rightColumn),
      ],
    );
  }
}

class _OverallProgress extends StatelessWidget {
  const _OverallProgress({required this.engine});

  final WorkoutEngine engine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _IntervalFocus extends StatelessWidget {
  const _IntervalFocus({
    required this.engine,
    required this.current,
    this.compact = false,
  });

  final WorkoutEngine engine;
  final WorkoutInterval? current;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          current?.label ?? '—',
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        if (current != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: engine.intervalProgress,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.secondary.withValues(alpha: 0.2),
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatClock(engine.elapsedInIntervalSec)} / '
            '${formatClock(current!.durationSec)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatClock(engine.remainingInIntervalSec),
            style: (compact
                    ? theme.textTheme.displayMedium
                    : theme.textTheme.displayLarge)
                ?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        if (current != null)
          Text(
            'remaining',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        if (current != null)
          Text(
            'Target ${current!.speedKmh.toStringAsFixed(1)} km/h'
            '${current!.inclinePct > 0 ? '  ·  ${current!.inclinePct.toStringAsFixed(1)}% incline' : ''}',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

class _NextIntervalCard extends StatelessWidget {
  const _NextIntervalCard({required this.next});

  final WorkoutInterval next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
    );
  }
}

class _WorkoutActions extends StatelessWidget {
  const _WorkoutActions({required this.engine, required this.onStop});

  final WorkoutEngine engine;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              foregroundColor: Colors.white,
            ),
            onPressed: onStop,
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
        ),
      ],
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
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: OrientationLayout(
        portrait: (_) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _SummaryContent(
              plan: plan,
              elapsedSec: elapsedSec,
              onDone: onDone,
            ),
          ),
        ),
        landscape: (_) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 88,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 32),
                AdaptiveConstraints(
                  maxWidth: 360,
                  child: _SummaryContent(
                    plan: plan,
                    elapsedSec: elapsedSec,
                    onDone: onDone,
                    showIcon: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({
    required this.plan,
    required this.elapsedSec,
    required this.onDone,
    this.showIcon = true,
  });

  final WorkoutPlan plan;
  final int elapsedSec;
  final Future<void> Function() onDone;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Icon(Icons.emoji_events, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
        ],
        Text('Workout complete!', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(plan.name, style: theme.textTheme.titleMedium),
        const SizedBox(height: 24),
        _SummaryRow(label: 'Total time', value: formatDuration(elapsedSec)),
        _SummaryRow(label: 'Intervals', value: '${plan.intervalCount}'),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => onDone(),
          child: const Text('Done'),
        ),
      ],
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
