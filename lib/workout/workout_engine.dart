import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ble/ftms_service.dart';
import '../domain/activity_entry.dart';
import '../domain/workout_plan.dart';
import 'activity_tracker.dart';

enum WorkoutPhase { idle, running, paused, finished }

/// Executes a [WorkoutPlan] against the treadmill using a 1-second tick.
///
/// Unlike a `Future.delayed` loop, this state machine can be paused, resumed
/// and stopped, and exposes a live countdown for the UI. Interval transitions
/// only send new Set-Speed / Set-Incline commands — never Stop — so the belt
/// keeps moving smoothly between segments.
class WorkoutEngine extends ChangeNotifier {
  WorkoutEngine(this._ftms, this._tracker);

  final FtmsService _ftms;
  final ActivityTracker _tracker;

  Timer? _ticker;
  WorkoutPlan? _plan;

  WorkoutPhase _phase = WorkoutPhase.idle;
  WorkoutPhase get phase => _phase;

  int _intervalIndex = 0;
  int get intervalIndex => _intervalIndex;

  int _remainingInIntervalSec = 0;
  int get remainingInIntervalSec => _remainingInIntervalSec;

  int _elapsedTotalSec = 0;
  int get elapsedTotalSec => _elapsedTotalSec;

  WorkoutPlan? get plan => _plan;

  WorkoutInterval? get currentInterval =>
      (_plan != null && _intervalIndex < _plan!.intervals.length)
          ? _plan!.intervals[_intervalIndex]
          : null;

  WorkoutInterval? get nextInterval =>
      (_plan != null && _intervalIndex + 1 < _plan!.intervals.length)
          ? _plan!.intervals[_intervalIndex + 1]
          : null;

  int get totalDurationSec => _plan?.totalDurationSec ?? 0;

  double get overallProgress {
    if (totalDurationSec == 0) return 0;
    return (_elapsedTotalSec / totalDurationSec).clamp(0.0, 1.0);
  }

  bool get isActive =>
      _phase == WorkoutPhase.running || _phase == WorkoutPhase.paused;

  /// Starts the plan: requests control, applies interval 0, and auto-starts the
  /// belt (per the chosen design). Returns false if the treadmill rejects setup.
  Future<bool> start(WorkoutPlan plan) async {
    if (plan.intervals.isEmpty) return false;
    await stop(sendStopCommand: false);

    _plan = plan;
    _intervalIndex = 0;
    _elapsedTotalSec = 0;
    _remainingInIntervalSec = plan.intervals.first.durationSec;
    _phase = WorkoutPhase.running;
    notifyListeners();

    _tracker.begin(
      type: ActivityType.plan,
      planId: plan.id,
      planName: plan.name,
    );

    await WakelockPlus.enable();

    if (!_ftms.hasControl) {
      await _ftms.requestControl();
    }
    await _applyInterval(plan.intervals.first);
    await _ftms.start();

    _startTicker();
    return true;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (_phase != WorkoutPhase.running || _plan == null) return;

    _remainingInIntervalSec--;
    _elapsedTotalSec++;

    if (_remainingInIntervalSec <= 0) {
      final isLast = _intervalIndex >= _plan!.intervals.length - 1;
      if (isLast) {
        await _finish();
        return;
      }
      _intervalIndex++;
      final next = _plan!.intervals[_intervalIndex];
      _remainingInIntervalSec = next.durationSec;
      notifyListeners();
      // Transition without stopping the belt.
      await _applyInterval(next);
    } else {
      notifyListeners();
    }
  }

  Future<void> _applyInterval(WorkoutInterval interval) async {
    await _ftms.setSpeed(interval.speedKmh);
    final caps = _ftms.capabilities;
    if (caps == null || caps.supportsInclinationTarget) {
      await _ftms.setIncline(interval.inclinePct);
    }
  }

  Future<void> pause() async {
    if (_phase != WorkoutPhase.running) return;
    _phase = WorkoutPhase.paused;
    notifyListeners();
    await _ftms.pause();
  }

  Future<void> resume() async {
    if (_phase != WorkoutPhase.paused) return;
    _phase = WorkoutPhase.running;
    notifyListeners();
    if (!_ftms.hasControl) {
      await _ftms.requestControl();
      final interval = currentInterval;
      if (interval != null) await _applyInterval(interval);
    }
    await _ftms.start();
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    _ticker = null;
    _phase = WorkoutPhase.finished;
    notifyListeners();
    await _tracker.complete(durationSec: _elapsedTotalSec, completed: true);
    await _ftms.stop();
    await WakelockPlus.disable();
  }

  /// Stops the workout. Sends the Stop command unless we're resetting state
  /// before starting a fresh run.
  Future<void> stop({bool sendStopCommand = true}) async {
    _ticker?.cancel();
    _ticker = null;
    final wasActive = isActive;
    _phase = WorkoutPhase.idle;
    notifyListeners();
    if (wasActive) {
      // A run stopped early still counts if it reached the minimum duration.
      await _tracker.complete(durationSec: _elapsedTotalSec, completed: false);
    } else {
      _tracker.cancel();
    }
    if (sendStopCommand && wasActive) {
      await _ftms.stop();
    }
    await WakelockPlus.disable();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _plan = null;
    _phase = WorkoutPhase.idle;
    _intervalIndex = 0;
    _remainingInIntervalSec = 0;
    _elapsedTotalSec = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }
}
