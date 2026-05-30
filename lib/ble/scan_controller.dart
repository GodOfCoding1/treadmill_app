import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../core/ftms_constants.dart';

enum DeviceClass { treadmill, possibleFitness, other }

/// A discovered device enriched with our treadmill classification.
class ClassifiedDevice {
  ClassifiedDevice(this.device, this.deviceClass);

  final BleDevice device;
  final DeviceClass deviceClass;

  String get name =>
      (device.name?.isNotEmpty ?? false) ? device.name! : 'Unknown device';
  String get id => device.deviceId;
  int get rssi => device.rssi ?? -100;
}

/// Drives BLE scanning and groups discovered devices into treadmills, possible
/// fitness devices, and everything else. Built on `universal_ble`.
class ScanController extends ChangeNotifier {
  ScanController() {
    _scanSub = UniversalBle.scanStream.listen(_onDevice);
    _availabilitySub =
        UniversalBle.availabilityStream.listen((state) {
      _availability = state;
      notifyListeners();
    });
    _refreshAvailability();
  }

  late final StreamSubscription<BleDevice> _scanSub;
  late final StreamSubscription<AvailabilityState> _availabilitySub;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  AvailabilityState _availability = AvailabilityState.unknown;
  bool get isBluetoothOn => _availability == AvailabilityState.poweredOn;

  String? _error;
  String? get error => _error;

  final Map<String, ClassifiedDevice> _devices = {};

  List<ClassifiedDevice> get treadmills => _filtered(DeviceClass.treadmill);
  List<ClassifiedDevice> get possibleFitness =>
      _filtered(DeviceClass.possibleFitness);
  List<ClassifiedDevice> get otherDevices => _filtered(DeviceClass.other);

  List<ClassifiedDevice> _filtered(DeviceClass c) {
    final list = _devices.values.where((d) => d.deviceClass == c).toList();
    list.sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  Future<void> _refreshAvailability() async {
    try {
      _availability = await UniversalBle.getBluetoothAvailabilityState();
      notifyListeners();
    } catch (_) {}
  }

  void _onDevice(BleDevice device) {
    _devices[device.deviceId] = ClassifiedDevice(device, _classify(device));
    notifyListeners();
  }

  DeviceClass _classify(BleDevice device) {
    final advertisesFtms = device.services.any(
        (uuid) => BleUuidParser.compareStrings(uuid, FtmsUuids.service));
    if (advertisesFtms) return DeviceClass.treadmill;

    final name = (device.name ?? '').toLowerCase();
    const hints = ['treadmill', 'fs-', 'jodu', 'fitness', 'run', 'tread'];
    if (name.isNotEmpty && hints.any(name.contains)) {
      return DeviceClass.possibleFitness;
    }

    return DeviceClass.other;
  }

  Future<void> startScan() async {
    _error = null;

    try {
      await UniversalBle.requestPermissions();
    } catch (e) {
      _error = 'Bluetooth permissions were denied.';
      notifyListeners();
      return;
    }

    await _refreshAvailability();
    if (!isBluetoothOn) {
      _error = 'Please turn on Bluetooth.';
      notifyListeners();
      return;
    }

    _devices.clear();
    _isScanning = true;
    notifyListeners();

    try {
      // Scan broadly (no service filter) so non-FTMS devices still appear in
      // the "other" section; classification happens client-side.
      await UniversalBle.startScan();
    } catch (e) {
      _isScanning = false;
      _error = 'Scan failed: $e';
      notifyListeners();
      return;
    }

    // universal_ble has no fixed scan timeout; stop after a window so the UI's
    // scanning indicator resolves.
    Timer(const Duration(seconds: 12), () {
      if (_isScanning) stopScan();
    });
  }

  Future<void> stopScan() async {
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    _isScanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub.cancel();
    _availabilitySub.cancel();
    UniversalBle.stopScan();
    super.dispose();
  }
}
