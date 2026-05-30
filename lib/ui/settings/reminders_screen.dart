import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/reminder_settings.dart';
import '../../domain/streak.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  ReminderSettings? _settings;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(reminderSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load reminders: $e')),
        data: (loaded) {
          final settings = _settings ??= loaded;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _ReminderTile(
                title: 'Daily workout reminder',
                subtitle: 'A nudge to get on the treadmill every day.',
                enabled: settings.dailyEnabled,
                time: settings.dailyTime,
                onToggle: (v) => setState(
                    () => _settings = settings.copyWith(dailyEnabled: v)),
                onPickTime: (t) => setState(
                    () => _settings = settings.copyWith(dailyTime: t)),
              ),
              const SizedBox(height: 8),
              _ReminderTile(
                title: 'Streak reminder',
                subtitle: 'Remind me if I haven\'t kept my streak alive.',
                enabled: settings.streakEnabled,
                time: settings.streakTime,
                onToggle: (v) => setState(
                    () => _settings = settings.copyWith(streakEnabled: v)),
                onPickTime: (t) => setState(
                    () => _settings = settings.copyWith(streakTime: t)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : () => _save(settings),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(ReminderSettings settings) async {
    setState(() => _saving = true);
    final service = ref.read(notificationServiceProvider);

    final anyEnabled = settings.dailyEnabled || settings.streakEnabled;
    if (anyEnabled) {
      final granted = await service.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Notification permission denied. '
                  'Enable it in system settings.')),
        );
      }
    }

    await ref.read(reminderRepositoryProvider).save(settings);
    final stats =
        ref.read(streakStatsProvider).asData?.value ?? StreakStats.empty;
    await service.apply(settings, stats);

    ref.invalidate(reminderSettingsProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminders saved.')),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onPickTime,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final TimeOfDay time;
  final ValueChanged<bool> onToggle;
  final ValueChanged<TimeOfDay> onPickTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title, style: theme.textTheme.titleMedium),
              subtitle: Text(subtitle),
              value: enabled,
              onChanged: onToggle,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: enabled,
              leading: const Icon(Icons.schedule),
              title: const Text('Time'),
              trailing: Text(
                time.format(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: enabled
                      ? theme.colorScheme.primary
                      : theme.disabledColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: enabled
                  ? () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: time,
                      );
                      if (picked != null) onPickTime(picked);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
