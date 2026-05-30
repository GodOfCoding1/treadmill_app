import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../core/ftms_constants.dart';
import '../ftms/capabilities.dart';
import '../ftms/treadmill_data.dart';

enum FtmsConnectionStatus {
  disconnected,
  connecting,
  discovering,
  requestingControl,
  ready,
  error,
}

/// Owns the BLE connection to a single FTMS treadmill and exposes a high-level,
/// byte-free API. UI and the workout engine talk only to this class.
///
/// Built on `universal_ble` (BSD-3 licensed, free for commercial use).
///
/// Key responsibilities:
///  - connect, discover services, locate FTMS characteristics
///  - subscribe to indications (0x2AD9) and notifications (0x2ADA, 0x2ACD)
///  - read capabilities + supported ranges
///  - serialize Control Point commands and await their `[0x80, op, result]`
///    indication with a timeout, auto re-requesting control when revoked
class FtmsService extends ChangeNotifier {
  FtmsConnectionStatus _status = FtmsConnectionStatus.disconnected;
  FtmsConnectionStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  BleDevice? _device;
  BleDevice? get device => _device;
  String get deviceName =>
      (_device?.name?.isNotEmpty ?? false) ? _device!.name! : 'Treadmill';

  TreadmillCapabilities? _capabilities;
  TreadmillCapabilities? get capabilities => _capabilities;

  TreadmillData _data = TreadmillData.empty;
  TreadmillData get data => _data;

  bool _hasControl = false;
  bool get hasControl => _hasControl;

  bool _everConnected = false;

  BleCharacteristic? _controlPoint;
  BleCharacteristic? _treadmillData;
  BleCharacteristic? _statusChar;

  final List<StreamSubscription<dynamic>> _subs = [];

  // Control Point request/response state.
  Completer<FtmsCommandResult>? _pending;

  bool get isConnected => _status == FtmsConnectionStatus.ready;

  void _setStatus(FtmsConnectionStatus s, {String? error}) {
    _status = s;
    _errorMessage = error;
    notifyListeners();
  }

  /// Full connect + setup sequence. Returns true once the treadmill is ready.
  Future<bool> connectAndSetup(BleDevice device) async {
    await disconnect();
    _device = device;
    _setStatus(FtmsConnectionStatus.connecting);

    try {
      _subs.add(device.connectionStream.listen(_onConnectionChanged));
      await device.connect(timeout: const Duration(seconds: 15));

      _setStatus(FtmsConnectionStatus.discovering);
      final services = await device.discoverServices();
      final ftms = services
          .where((s) => BleUuidParser.compareStrings(s.uuid, FtmsUuids.service))
          .toList();
      if (ftms.isEmpty) {
        await disconnect();
        _setStatus(FtmsConnectionStatus.error,
            error: 'This device does not expose the Fitness Machine Service '
                '(0x1826) and cannot be controlled.');
        return false;
      }

      final service = ftms.first;
      _bindCharacteristics(service);

      if (_controlPoint == null) {
        await disconnect();
        _setStatus(FtmsConnectionStatus.error,
            error: 'Treadmill has no Control Point characteristic (0x2AD9).');
        return false;
      }

      await _readCapabilities(service);
      await _enableSubscriptions();

      _setStatus(FtmsConnectionStatus.requestingControl);
      final result =
          await _enqueue(() => _writeAndAwait(FtmsCommands.requestControl()));
      if (!result.isSuccess) {
        await disconnect();
        _setStatus(FtmsConnectionStatus.error,
            error: 'Treadmill refused control request (${result.code.name}).');
        return false;
      }
      _hasControl = true;

      _setStatus(FtmsConnectionStatus.ready);
      return true;
    } catch (e) {
      await disconnect();
      _setStatus(FtmsConnectionStatus.error, error: 'Connection failed: $e');
      return false;
    }
  }

  BleCharacteristic? _charFor(BleService service, String uuid) {
    final matches = service.characteristics
        .where((c) => BleUuidParser.compareStrings(c.uuid, uuid));
    return matches.isEmpty ? null : matches.first;
  }

  void _bindCharacteristics(BleService service) {
    _controlPoint = _charFor(service, FtmsUuids.controlPoint);
    _treadmillData = _charFor(service, FtmsUuids.treadmillData);
    _statusChar = _charFor(service, FtmsUuids.status);
  }

  Future<void> _readCapabilities(BleService service) async {
    TreadmillCapabilities caps = const TreadmillCapabilities(
      fitnessMachineFeatures: 0,
      targetSettingFeatures: 0,
    );

    bool canRead(BleCharacteristic? c) =>
        c != null && c.properties.contains(CharacteristicProperty.read);

    try {
      final feature = _charFor(service, FtmsUuids.feature);
      if (canRead(feature)) {
        caps = TreadmillCapabilities.fromFeature(await feature!.read());
      }
    } catch (_) {/* feature read is best-effort */}

    try {
      final speed = _charFor(service, FtmsUuids.supportedSpeedRange);
      if (canRead(speed)) {
        caps = caps.copyWith(
          speedRange:
              TreadmillCapabilities.parseSpeedRange(await speed!.read()),
        );
      }
    } catch (_) {}

    try {
      final incline = _charFor(service, FtmsUuids.supportedInclinationRange);
      if (canRead(incline)) {
        caps = caps.copyWith(
          inclinationRange: TreadmillCapabilities.parseInclinationRange(
              await incline!.read()),
        );
      }
    } catch (_) {}

    _capabilities = caps;
    notifyListeners();
  }

  Future<void> _enableSubscriptions() async {
    // Control Point: INDICATE (request/response). universal_ble writes the
    // CCCD automatically.
    _subs.add(_controlPoint!.onValueReceived.listen(_onControlPointIndication));
    await _controlPoint!.indications.subscribe();

    if (_statusChar != null &&
        _statusChar!.properties.contains(CharacteristicProperty.notify)) {
      _subs.add(_statusChar!.onValueReceived.listen(_onStatusNotification));
      await _statusChar!.notifications.subscribe();
    }

    if (_treadmillData != null &&
        _treadmillData!.properties.contains(CharacteristicProperty.notify)) {
      _subs.add(_treadmillData!.onValueReceived.listen(_onTreadmillData));
      await _treadmillData!.notifications.subscribe();
    }
  }

  void _onTreadmillData(List<int> value) {
    final parsed = TreadmillData.parse(value);
    _data = _data.mergeWith(parsed);
    notifyListeners();
  }

  void _onStatusNotification(List<int> value) {
    // 0x2ADA op-codes describe state transitions. We surface control loss so
    // the next command can transparently re-request control.
    if (value.isEmpty) return;
    final op = value[0];
    // 0x01 = Reset, 0x03 = Stopped by safety key.
    if (op == 0x01 || op == 0x03) {
      _hasControl = false;
    }
  }

  void _onControlPointIndication(List<int> value) {
    if (value.length >= 3 && value[0] == FtmsOpcode.responsePrefix) {
      final requestOp = value[1];
      final code = FtmsResultCode.fromByte(value[2]);
      final pending = _pending;
      if (pending != null && !pending.isCompleted) {
        _pending = null;
        pending.complete(FtmsCommandResult(requestOp, code));
      }
    }
  }

  void _onConnectionChanged(bool isConnected) {
    if (isConnected) {
      _everConnected = true;
      return;
    }
    if (_everConnected &&
        _status != FtmsConnectionStatus.disconnected &&
        _status != FtmsConnectionStatus.error) {
      _hasControl = false;
      _everConnected = false;
      _setStatus(FtmsConnectionStatus.disconnected,
          error: 'Treadmill disconnected.');
    }
  }

  // --- Control Point command queue -----------------------------------------

  Future<FtmsCommandResult> _enqueue(
      Future<FtmsCommandResult> Function() action) {
    final completer = Completer<FtmsCommandResult>();
    _queueTail = _queueTail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _queueTail = Future<void>.value();

  Future<FtmsCommandResult> _writeAndAwait(List<int> bytes) async {
    final cp = _controlPoint;
    if (cp == null) {
      return const FtmsCommandResult(0, FtmsResultCode.operationFailed);
    }
    final opcode = bytes[0];
    final completer = Completer<FtmsCommandResult>();
    _pending = completer;

    try {
      await cp.write(bytes, withResponse: true);
    } catch (e) {
      _pending = null;
      return FtmsCommandResult(opcode, FtmsResultCode.operationFailed);
    }

    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        if (identical(_pending, completer)) {
          _pending = null;
        }
        return FtmsCommandResult(opcode, FtmsResultCode.timeout);
      },
    );
  }

  /// Sends a command, transparently re-requesting control once if the
  /// treadmill reports that control is not permitted.
  Future<FtmsCommandResult> _command(List<int> bytes) async {
    var result = await _enqueue(() => _writeAndAwait(bytes));
    if (result.code == FtmsResultCode.controlNotPermitted) {
      _hasControl = false;
      final reacquire =
          await _enqueue(() => _writeAndAwait(FtmsCommands.requestControl()));
      if (reacquire.isSuccess) {
        _hasControl = true;
        result = await _enqueue(() => _writeAndAwait(bytes));
      }
    }
    return result;
  }

  // --- Public commands ------------------------------------------------------

  Future<FtmsCommandResult> requestControl() =>
      _command(FtmsCommands.requestControl());

  Future<FtmsCommandResult> setSpeed(double kmh) =>
      _command(FtmsCommands.setTargetSpeed(kmh));

  Future<FtmsCommandResult> setIncline(double percent) =>
      _command(FtmsCommands.setTargetInclination(percent));

  Future<FtmsCommandResult> start() => _command(FtmsCommands.startOrResume());

  Future<FtmsCommandResult> pause() => _command(FtmsCommands.pause());

  Future<FtmsCommandResult> stop() async {
    final r = await _command(FtmsCommands.stop());
    _hasControl = false; // a full stop releases control on most devices
    return r;
  }

  Future<void> disconnect() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _pending = null;
    _hasControl = false;
    _everConnected = false;
    _controlPoint = null;
    _treadmillData = null;
    _statusChar = null;
    _data = TreadmillData.empty;
    _capabilities = null;

    final d = _device;
    _device = null;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
    if (_status != FtmsConnectionStatus.error) {
      _setStatus(FtmsConnectionStatus.disconnected);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}
