import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ble/ftms_service.dart';
import 'ble/scan_controller.dart';
import 'data/activity_repository.dart';
import 'data/plan_repository.dart';
import 'domain/activity_entry.dart';
import 'domain/workout_plan.dart';
import 'workout/activity_tracker.dart';
import 'workout/workout_engine.dart';

/// The single shared BLE/FTMS connection.
final ftmsServiceProvider = ChangeNotifierProvider<FtmsService>((ref) {
  final service = FtmsService();
  ref.onDispose(service.dispose);
  return service;
});

/// Drives BLE scanning and device classification.
final scanControllerProvider = ChangeNotifierProvider<ScanController>((ref) {
  final controller = ScanController();
  ref.onDispose(controller.dispose);
  return controller;
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

/// Shared activity tracker used to record both manual and plan runs.
final activityTrackerProvider = Provider<ActivityTracker>((ref) {
  final ftms = ref.watch(ftmsServiceProvider);
  final repo = ref.watch(activityRepositoryProvider);
  return ActivityTracker(ftms, repo);
});

/// The workout execution state machine, wired to the BLE service.
final workoutEngineProvider = ChangeNotifierProvider<WorkoutEngine>((ref) {
  final ftms = ref.watch(ftmsServiceProvider);
  final tracker = ref.watch(activityTrackerProvider);
  final engine = WorkoutEngine(ftms, tracker);
  ref.onDispose(engine.dispose);
  return engine;
});
