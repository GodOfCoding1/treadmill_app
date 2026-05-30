import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/workout_plan.dart';

/// Persists workout plans as JSON in shared_preferences under `plan_<id>` keys.
class PlanRepository {
  static const _prefix = 'plan_';

  Future<List<WorkoutPlan>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final plans = <WorkoutPlan>[];
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        plans.add(
            WorkoutPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {/* skip corrupt entries */}
    }
    plans.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return plans;
  }

  Future<void> save(WorkoutPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${plan.id}', jsonEncode(plan.toJson()));
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$id');
  }

  /// Seeds the sample plan on first launch so the user has something to try.
  Future<void> seedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAny = prefs.getKeys().any((k) => k.startsWith(_prefix));
    if (!hasAny) {
      await save(WorkoutPlan.sample());
    }
  }
}
