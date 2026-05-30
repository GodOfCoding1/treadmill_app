import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/activity_entry.dart';

/// Persists recorded activities as JSON in shared_preferences under
/// `activity_<id>` keys.
class ActivityRepository {
  static const _prefix = 'activity_';

  Future<List<ActivityEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final entries = <ActivityEntry>[];
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        entries.add(
            ActivityEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {/* skip corrupt entries */}
    }
    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return entries;
  }

  /// Saves an entry only if it meets the minimum-duration threshold.
  Future<bool> save(ActivityEntry entry) async {
    if (!entry.qualifies) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${entry.id}', jsonEncode(entry.toJson()));
    return true;
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$id');
  }
}
