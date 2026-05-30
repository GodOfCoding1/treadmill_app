import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';

/// Shows the user's current running streak and personal best. Returns an empty
/// box while stats are still loading.
class StreakBanner extends ConsumerWidget {
  const StreakBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(streakStatsProvider);
    final value = stats.asData?.value;
    if (value == null) return const SizedBox.shrink();

    final hasStreak = value.current > 0;
    final color = hasStreak ? theme.colorScheme.primary : theme.disabledColor;

    String subtitle;
    if (!hasStreak) {
      subtitle = 'Run 20+ minutes today to start a streak.';
    } else if (value.atRisk) {
      subtitle = 'Run today to keep it going!';
    } else {
      subtitle = 'Nice — you worked out today.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_fire_department, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasStreak
                        ? '${value.current} day streak'
                        : 'No active streak',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
            if (value.longest > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Best',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.hintColor)),
                  Text('${value.longest}',
                      style: theme.textTheme.titleMedium),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
