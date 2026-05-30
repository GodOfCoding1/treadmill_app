import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../domain/activity_entry.dart';
import '../../workout/foreground_service.dart';
import '../router.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  double _targetSpeed = 0;
  double _targetIncline = 0;
  bool _userTouchedSpeed = false;

  @override
  Widget build(BuildContext context) {
    final ftms = ref.watch(ftmsServiceProvider);
    final caps = ftms.capabilities;
    final theme = Theme.of(context);

    // Initialise the speed slider to the device minimum once capabilities load.
    if (!_userTouchedSpeed && caps != null && _targetSpeed == 0) {
      _targetSpeed = caps.minSpeed;
    }

    if (!ftms.isConnected) {
      return _Disconnected(message: ftms.errorMessage);
    }

    final supportsIncline = caps?.supportsInclinationTarget ?? false;
    final data = ftms.data;

    return Scaffold(
      appBar: AppBar(
        title: Text(ftms.deviceName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.home),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Icon(Icons.circle,
                    size: 12, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                const Text('Connected'),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _LiveMetric(
                  label: 'Speed',
                  value: (data.instantaneousSpeedKmh ?? 0).toStringAsFixed(1),
                  unit: 'km/h',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LiveMetric(
                  label: 'Incline',
                  value: (data.inclinationPercent ?? 0).toStringAsFixed(1),
                  unit: '%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LiveMetric(
                  label: 'Distance',
                  value: ((data.totalDistanceMeters ?? 0) / 1000)
                      .toStringAsFixed(2),
                  unit: 'km',
                  small: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LiveMetric(
                  label: 'Heart rate',
                  value: data.heartRateBpm?.toString() ?? '--',
                  unit: 'bpm',
                  small: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SliderCard(
            label: 'Target speed',
            value: _targetSpeed,
            min: caps?.minSpeed ?? 0,
            max: caps?.maxSpeed ?? 20,
            step: caps?.speedStep ?? 0.5,
            unit: 'km/h',
            onChanged: (v) => setState(() {
              _userTouchedSpeed = true;
              _targetSpeed = v;
            }),
            onChangeEnd: (v) => ftms.setSpeed(v),
          ),
          if (supportsIncline)
            _SliderCard(
              label: 'Target incline',
              value: _targetIncline,
              min: caps?.minIncline ?? 0,
              max: caps?.maxIncline ?? 15,
              step: caps?.inclineStep ?? 0.5,
              unit: '%',
              onChanged: (v) => setState(() => _targetIncline = v),
              onChangeEnd: (v) => ftms.setIncline(v),
            )
          else
            const _InfoNote(
                text: 'This treadmill does not support incline control.'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    // Start uses the treadmill's last target speed; apply the
                    // slider values first so it doesn't default to ~1 km/h.
                    await ftms.setSpeed(_targetSpeed);
                    if (supportsIncline) {
                      await ftms.setIncline(_targetIncline);
                    }
                    await ftms.start();
                    final tracker = ref.read(activityTrackerProvider);
                    if (!tracker.isTracking) {
                      tracker.begin(type: ActivityType.manual);
                      await WorkoutForegroundService.requestPermissions();
                      await WorkoutForegroundService.start(
                        title: 'Manual run',
                        text: 'Treadmill running',
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => ftms.pause(),
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.shade200,
            ),
            onPressed: () async {
              await ftms.stop();
              await WorkoutForegroundService.stop();
              final tracker = ref.read(activityTrackerProvider);
              final entry = await tracker.complete();
              if (entry != null) {
                ref.invalidate(activitiesProvider);
                await rescheduleReminders(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activity logged.')),
                  );
                }
              }
            },
            icon: const Icon(Icons.stop),
            label: const Text('Stop'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.reminders),
            icon: const Icon(Icons.notifications_outlined),
            label: const Text('Reminders'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await ftms.disconnect();
              if (context.mounted) context.go(AppRoutes.home);
            },
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}

class _Disconnected extends ConsumerWidget {
  const _Disconnected({this.message});
  final String? message;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treadmill'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.home),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bluetooth_disabled, size: 48),
              const SizedBox(height: 16),
              Text(message ?? 'Not connected to a treadmill.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  ref.read(pendingIntentProvider.notifier).state =
                      const OpenControlIntent();
                  context.push(AppRoutes.scan);
                },
                child: const Text('Scan for treadmills'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric({
    required this.label,
    required this.value,
    required this.unit,
    this.small = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge,
                children: [
                  TextSpan(
                    text: value,
                    style: (small
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.displaySmall)
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  TextSpan(text: '  $unit'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeMax = max > min ? max : min + 1;
    final clamped = value.clamp(min, safeMax);
    final divisions =
        step > 0 ? ((safeMax - min) / step).round().clamp(1, 1000) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: theme.textTheme.labelLarge),
                Text('${clamped.toStringAsFixed(1)} $unit',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            Slider(
              value: clamped.toDouble(),
              min: min,
              max: safeMax,
              divisions: divisions,
              label: clamped.toStringAsFixed(1),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.hintColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
          ),
        ],
      ),
    );
  }
}
