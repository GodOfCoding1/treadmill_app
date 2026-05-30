import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../ble/ftms_service.dart';
import '../core/format.dart';
import '../domain/activity_entry.dart';
import '../domain/workout_plan.dart';
import 'activity_tracker.dart';
import 'foreground_service.dart';

enum WorkoutPhase { idle, running, paused, finished }

/// Executes a [WorkoutPlan] against the treadmill.
///
/// Timing is derived from the wall clock (not by counting timer ticks), so the
/// elapsed time and interval transitions stay correct even when the OS throttles
/// or suspends the 1-second ticker — e.g. while the app is backgrounded during a
/// phone call or while the user listens to music. An Android foreground service
/// keeps the process (BLE connection + this ticker) alive in the background.
///
/// Interval transitions only send new Set-Speed / Set-Incline commands — never
/// Stop — so the belt keeps moving smoothly between segments. After a long
/// background gap the engine jumps straight to whichever interval should be
/// active "now", skipping any segments that fully elapsed.
class WorkoutEngine extends ChangeNotifier {
  WorkoutEngine(this._ftms, this._tracker) {
    _ftms.onReconnected = _onBleReconnected;
  }

  final FtmsService _ftms;
  final ActivityTracker _tracker;

  Timer? _ticker;
  WorkoutPlan? _plan;

  WorkoutPhase _phase = WorkoutPhase.idle;
  WorkoutPhase get phase => _phase;

  // Wall-clock anchors. Elapsed = (now - start) - pausedTotal.
  DateTime? _runStartedAt;
  DateTime? _pauseStartedAt;
  int _pausedAccumSec = 0;

  int _intervalIndex = 0;
  int get intervalIndex => _intervalIndex;

  int _remainingInIntervalSec = 0;
  int get remainingInIntervalSec => _remainingInIntervalSec;

  int _elapsedTotalSec = 0;
  int get elapsedTotalSec => _elapsedTotalSec;

  WorkoutPlan? get plan => _plan;

  List<WorkoutInterval> get _intervals => _plan?.intervals ?? const [];

  WorkoutInterval? get currentInterval =>
      (_plan != null && _intervalIndex < _intervals.length)
          ? _intervals[_intervalIndex]
          : null;

  WorkoutInterval? get nextInterval =>
      (_plan != null && _intervalIndex + 1 < _intervals.length)
          ? _intervals[_intervalIndex + 1]
          : null;

  int get totalDurationSec => _plan?.totalDurationSec ?? 0;

  double get overallProgress {
    if (totalDurationSec == 0) return 0;
    return (_elapsedTotalSec / totalDurationSec).clamp(0.0, 1.0);
  }

  int get elapsedInIntervalSec {
    final cur = currentInterval;
    if (cur == null || cur.durationSec == 0) return 0;
    return (cur.durationSec - _remainingInIntervalSec)
        .clamp(0, cur.durationSec);
  }

  double get intervalProgress {
    final cur = currentInterval;
    if (cur == null || cur.durationSec == 0) return 0;
    return (elapsedInIntervalSec / cur.durationSec).clamp(0.0, 1.0);
  }

  bool get isActive =>
      _phase == WorkoutPhase.running || _phase == WorkoutPhase.paused;

  /// Starts the plan: requests control, starts the belt, then applies interval 0.
  /// Returns false if the treadmill rejects setup.
  Future<bool> start(WorkoutPlan plan) async {
    if (plan.intervals.isEmpty) return false;
    await stop(sendStopCommand: false);

    _plan = plan;
    _intervalIndex = 0;
    _elapsedTotalSec = 0;
    _pausedAccumSec = 0;
    _pauseStartedAt = null;
    _runStartedAt = DateTime.now();
    _remainingInIntervalSec = plan.intervals.first.durationSec;
    _phase = WorkoutPhase.running;
    notifyListeners();

    _tracker.begin(
      type: ActivityType.plan,
      planId: plan.id,
      planName: plan.name,
    );

    await WakelockPlus.enable();
    await WorkoutForegroundService.requestPermissions();
    await WorkoutForegroundService.start(
      title: plan.name,
      text: _notificationText(),
    );

    if (!_ftms.hasControl) {
      await _ftms.requestControl();
    }
    // Start the belt first; many treadmills ignore target speed set while stopped.
    await _ftms.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _applyInterval(plan.intervals.first);

    _startTicker();
    return true;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() => _recompute();

  /// Recomputes elapsed/interval state from the wall clock. Safe to call at any
  /// time (ticker, lifecycle resume, BLE reconnect).
  Future<void> _recompute() async {
    if (_phase != WorkoutPhase.running || _plan == null) return;

    final elapsed = _computeElapsedSec();
    _elapsedTotalSec = elapsed;

    if (elapsed >= totalDurationSec) {
      _intervalIndex = _intervals.length - 1;
      _remainingInIntervalSec = 0;
      await _finish();
      return;
    }

    final newIndex = _intervalIndexForElapsed(elapsed);
    final intervalEnd = _cumulativeDurationThrough(newIndex);
    _remainingInIntervalSec = (intervalEnd - elapsed).clamp(0, 1 << 31);

    final advanced = newIndex != _intervalIndex;
    if (advanced) {
      _intervalIndex = newIndex;
      notifyListeners();
      // Jump the belt straight to whatever interval should be active now.
      await _applyInterval(_intervals[newIndex]);
    } else {
      notifyListeners();
    }
    await WorkoutForegroundService.update(
      title: _plan!.name,
      text: _notificationText(),
    );
  }

  int _computeElapsedSec() {
    if (_runStartedAt == null) return _elapsedTotalSec;
    final now = DateTime.now();
    var pausedSec = _pausedAccumSec;
    if (_phase == WorkoutPhase.paused && _pauseStartedAt != null) {
      pausedSec += now.difference(_pauseStartedAt!).inSeconds;
    }
    final raw = now.difference(_runStartedAt!).inSeconds - pausedSec;
    return raw < 0 ? 0 : raw;
  }

  int _intervalIndexForElapsed(int elapsed) {
    var acc = 0;
    for (var i = 0; i < _intervals.length; i++) {
      acc += _intervals[i].durationSec;
      if (elapsed < acc) return i;
    }
    return _intervals.length - 1;
  }

  int _cumulativeDurationThrough(int index) {
    var acc = 0;
    for (var i = 0; i <= index && i < _intervals.length; i++) {
      acc += _intervals[i].durationSec;
    }
    return acc;
  }

  String _notificationText() {
    final cur = currentInterval;
    final target =
        cur == null ? '' : ' · ${cur.speedKmh.toStringAsFixed(1)} km/h';
    return '${formatDuration(_elapsedTotalSec)} / '
        '${formatDuration(totalDurationSec)}$target';
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
    _pauseStartedAt = DateTime.now();
    notifyListeners();
    await _ftms.pause();
    await WorkoutForegroundService.update(
      title: _plan?.name ?? 'Workout',
      text: 'Paused · ${_notificationText()}',
    );
  }

  Future<void> resume() async {
    if (_phase != WorkoutPhase.paused) return;
    if (_pauseStartedAt != null) {
      _pausedAccumSec += DateTime.now().difference(_pauseStartedAt!).inSeconds;
      _pauseStartedAt = null;
    }
    _phase = WorkoutPhase.running;
    notifyListeners();
    if (!_ftms.hasControl) {
      await _ftms.requestControl();
    }
    final interval = currentInterval;
    if (interval != null) await _applyInterval(interval);
    await _ftms.start();
  }

  /// Forces a wall-clock resync. Call when the app returns to the foreground so
  /// the countdown and belt catch up immediately if ticks were suppressed.
  Future<void> syncFromWallClock() => _recompute();

  Future<void> _onBleReconnected() async {
    if (!isActive) return;
    if (!_ftms.hasControl) {
      await _ftms.requestControl();
    }
    final interval = currentInterval;
    if (interval != null) await _applyInterval(interval);
    if (_phase == WorkoutPhase.running) {
      await _ftms.start();
    }
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    _ticker = null;
    _phase = WorkoutPhase.finished;
    _elapsedTotalSec = totalDurationSec;
    notifyListeners();
    await _tracker.complete(durationSec: _elapsedTotalSec, completed: true);
    await _ftms.stop();
    await WakelockPlus.disable();
    await WorkoutForegroundService.stop();
  }

  /// Stops the workout. Sends the Stop command unless we're resetting state
  /// before starting a fresh run.
  Future<void> stop({bool sendStopCommand = true}) async {
    _ticker?.cancel();
    _ticker = null;
    final wasActive = isActive;
    if (wasActive) {
      _elapsedTotalSec = _computeElapsedSec();
    }
    _phase = WorkoutPhase.idle;
    _runStartedAt = null;
    _pauseStartedAt = null;
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
    await WorkoutForegroundService.stop();
  }

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _plan = null;
    _phase = WorkoutPhase.idle;
    _intervalIndex = 0;
    _remainingInIntervalSec = 0;
    _elapsedTotalSec = 0;
    _runStartedAt = null;
    _pauseStartedAt = null;
    _pausedAccumSec = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (identical(_ftms.onReconnected, _onBleReconnected)) {
      _ftms.onReconnected = null;
    }
    WakelockPlus.disable();
    WorkoutForegroundService.stop();
    super.dispose();
  }
}
