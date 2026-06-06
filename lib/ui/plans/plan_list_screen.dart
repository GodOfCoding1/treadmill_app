import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../core/format.dart';
import '../../domain/workout_plan.dart';
import '../connect_gate.dart';
import '../layout/responsive.dart';
import '../router.dart';

class PlanListScreen extends ConsumerWidget {
  const PlanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout plans')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRoutes.planBuilder);
          ref.invalidate(plansProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Create plan'),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load plans: $e')),
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(
              child: Text('No plans yet. Tap "Create plan" to begin.'),
            );
          }
          return OrientationLayout(
            portrait: (_) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _PlanCard(plan: plans[i]),
            ),
            landscape: (_) => isWide(context)
                ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      mainAxisExtent: 184,
                    ),
                    itemCount: plans.length,
                    itemBuilder: (context, i) => _PlanCard(plan: plans[i]),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: plans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _PlanCard(plan: plans[i]),
                  ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});
  final WorkoutPlan plan;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    await ensureConnectedThen(context, ref, StartPlanIntent(plan));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${plan.intervalCount} intervals  ·  '
              '${formatDuration(plan.totalDurationSec)} total',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _start(context, ref),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Edit',
                  onPressed: () async {
                    await context.push(AppRoutes.planBuilder, extra: plan);
                    ref.invalidate(plansProvider);
                  },
                  icon: const Icon(Icons.edit),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Delete',
                  onPressed: () async {
                    await ref.read(planRepositoryProvider).delete(plan.id);
                    ref.invalidate(plansProvider);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
