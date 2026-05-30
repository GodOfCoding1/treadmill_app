import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ble/ftms_service.dart';
import 'ble/scan_controller.dart';
import 'data/activity_repository.dart';
import 'data/plan_repository.dart';
import 'data/reminder_repository.dart';
import 'domain/activity_entry.dart';
import 'domain/reminder_settings.dart';
import 'domain/streak.dart';
import 'domain/workout_plan.dart';
import 'notifications/notification_service.dart';
import 'workout/activity_tracker.dart';
import 'workout/workout_engine.dart';

/// The single shared BLE/FTMS connection.
/// `ChangeNotifierProvider` disposes the notifier automatically, so no explicit
/// `ref.onDispose` is needed (that would dispose it twice).
final ftmsServiceProvider = ChangeNotifierProvider<FtmsService>((ref) {
  return FtmsService();
});

/// Drives BLE scanning and device classification.
final scanControllerProvider = ChangeNotifierProvider<ScanController>((ref) {
  return ScanController();
});

/// Workout plan persistence.
final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository();
});

/// The list of saved plans. Refresh after create/edit/delete.
final plansProvider =
    FutureProvider.autoDispose<List<WorkoutPlan>>((ref) async {
  final repo = ref.watch(planRepositoryProvider);
  await repo.seedIfEmpty();
  return repo.loadAll();
});

/// Recorded activity persistence.
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository();
});

/// All recorded activities, newest first. Invalidate after recording a run.
final activitiesProvider =
    FutureProvider.autoDispose<List<ActivityEntry>>((ref) async {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.loadAll();
});

/// Streak metrics derived from recorded activities.
final streakStatsProvider = Provider.autoDispose<AsyncValue<StreakStats>>((ref) {
  return ref.watch(activitiesProvider).whenData(StreakStats.fromActivities);
});

/// Local notification scheduling.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Reminder preferences persistence.
final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository();
});

/// Current reminder settings. Invalidate after saving.
final reminderSettingsProvider =
    FutureProvider.autoDispose<ReminderSettings>((ref) async {
  final repo = ref.watch(reminderRepositoryProvider);
  return repo.load();
});

/// Re-evaluates the streak nudge against freshly loaded activities so it does
/// not fire on a day the user has already completed. Safe to call after a run
/// is logged.
Future<void> rescheduleReminders(WidgetRef ref) async {
  final settings = await ref.read(reminderRepositoryProvider).load();
  final activities = await ref.read(activityRepositoryProvider).loadAll();
  final stats = StreakStats.fromActivities(activities);
  await ref.read(notificationServiceProvider).apply(settings, stats);
}

/// Shared activity tracker used to record both manual and plan runs.
/// Uses `ref.read` for the BLE service: it only needs the long-lived instance
/// and must not be rebuilt every time the treadmill pushes a data packet.
final activityTrackerProvider = Provider<ActivityTracker>((ref) {
  final ftms = ref.read(ftmsServiceProvider);
  final repo = ref.read(activityRepositoryProvider);
  return ActivityTracker(ftms, repo);
});

/// The workout execution state machine, wired to the BLE service. Reads (not
/// watches) its dependencies so it survives for the whole session;
/// `ChangeNotifierProvider` disposes the engine automatically.
final workoutEngineProvider = ChangeNotifierProvider<WorkoutEngine>((ref) {
  final ftms = ref.read(ftmsServiceProvider);
  final tracker = ref.read(activityTrackerProvider);
  return WorkoutEngine(ftms, tracker);
});
