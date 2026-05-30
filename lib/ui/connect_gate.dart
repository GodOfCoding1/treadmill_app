import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_providers.dart';
import '../ble/ftms_service.dart';
import 'router.dart';

/// Performs [intent] immediately if a treadmill is connected. Otherwise stores
/// it as a [PendingIntent] and prompts the user to connect, routing them to the
/// scan screen so the action can resume automatically once connected.
Future<void> ensureConnectedThen(
  BuildContext context,
  WidgetRef ref,
  PendingIntent intent,
) async {
  final ftms = ref.read(ftmsServiceProvider);
  if (ftms.status == FtmsConnectionStatus.ready) {
    _perform(context, intent);
    return;
  }

  final connect = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.bluetooth_searching),
      title: const Text('Connect a treadmill'),
      content: Text(
        intent is StartPlanIntent
            ? 'Connect to a treadmill to start "${intent.plan.name}".'
            : 'Connect to a treadmill to start a run.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.bluetooth),
          label: const Text('Connect'),
        ),
      ],
    ),
  );

  if (connect != true || !context.mounted) return;
  ref.read(pendingIntentProvider.notifier).state = intent;
  context.push(AppRoutes.scan);
}

/// Resolves a [PendingIntent] after a successful connection. Returns true if an
/// intent was handled (and clears it), false otherwise.
bool resolvePendingIntent(BuildContext context, WidgetRef ref) {
  final intent = ref.read(pendingIntentProvider);
  if (intent == null) return false;
  ref.read(pendingIntentProvider.notifier).state = null;
  _perform(context, intent);
  return true;
}

void _perform(BuildContext context, PendingIntent intent) {
  switch (intent) {
    case StartPlanIntent(:final plan):
      context.go(AppRoutes.activeWorkout, extra: plan);
    case OpenControlIntent():
      context.go(AppRoutes.control);
  }
}
