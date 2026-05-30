/// Bluetooth SIG assigned UUIDs for the Fitness Machine Service (FTMS) and the
/// treadmill-relevant characteristics, in full 128-bit lowercase form.
///
/// universal_ble normalises any UUID format to lowercase 128-bit and provides
/// `BleUuidParser.compareStrings` for matching, so these strings compare
/// cleanly against values returned by the platform.
class FtmsUuids {
  FtmsUuids._();

  static String _full(String short) =>
      '0000$short-0000-1000-8000-00805f9b34fb';

  /// Fitness Machine Service.
  static final String service = _full('1826');

  /// Treadmill Data (NOTIFY) — live speed, incline, distance, HR, time.
  static final String treadmillData = _full('2acd');

  /// Fitness Machine Status (NOTIFY) — state changes (started/stopped/etc.).
  static final String status = _full('2ada');

  /// Fitness Machine Control Point (WRITE + INDICATE) — commands + responses.
  static final String controlPoint = _full('2ad9');

  /// Fitness Machine Feature (READ) — supported features + target settings.
  static final String feature = _full('2acc');

  /// Supported Speed Range (READ) — min / max / increment.
  static final String supportedSpeedRange = _full('2ad4');

  /// Supported Inclination Range (READ) — min / max / increment.
  static final String supportedInclinationRange = _full('2ad5');

  /// Supported Resistance Level Range (READ).
  static final String supportedResistanceRange = _full('2ad6');

  /// Supported Power Range (READ).
  static final String supportedPowerRange = _full('2ad8');
}

/// Control Point op-codes (written to 0x2AD9).
class FtmsOpcode {
  FtmsOpcode._();

  static const int requestControl = 0x00;
  static const int reset = 0x01;
  static const int setTargetSpeed = 0x02;
  static const int setTargetInclination = 0x03;
  static const int startOrResume = 0x07;

  /// Stop or Pause. Standard FTMS uses a single op-code with a parameter byte:
  /// 0x01 = Stop, 0x02 = Pause. (The original nRF recon observed a
  /// non-standard bare 0x08/0x09 on the FS-9B02FD; re-verify on hardware.)
  static const int stopOrPause = 0x08;

  /// Marks an indication payload as a Control Point response.
  static const int responsePrefix = 0x80;
}

/// Parameter byte for the Stop/Pause op-code.
class FtmsStopPauseParam {
  FtmsStopPauseParam._();
  static const int stop = 0x01;
  static const int pause = 0x02;
}

/// Result codes returned inside a Control Point indication
/// `[0x80, requestOpcode, resultCode]`.
enum FtmsResultCode {
  success,
  opCodeNotSupported,
  invalidParameter,
  operationFailed,
  controlNotPermitted,
  timeout,
  unknown;

  static FtmsResultCode fromByte(int b) {
    switch (b) {
      case 0x01:
        return FtmsResultCode.success;
      case 0x02:
        return FtmsResultCode.opCodeNotSupported;
      case 0x03:
        return FtmsResultCode.invalidParameter;
      case 0x04:
        return FtmsResultCode.operationFailed;
      case 0x05:
        return FtmsResultCode.controlNotPermitted;
      default:
        return FtmsResultCode.unknown;
    }
  }

  bool get isSuccess => this == FtmsResultCode.success;
}

/// The outcome of a single Control Point command.
class FtmsCommandResult {
  const FtmsCommandResult(this.requestOpcode, this.code);

  final int requestOpcode;
  final FtmsResultCode code;

  bool get isSuccess => code.isSuccess;

  @override
  String toString() =>
      'FtmsCommandResult(op: 0x${requestOpcode.toRadixString(16)}, $code)';
}

/// Byte encoders for the Control Point commands.
class FtmsCommands {
  FtmsCommands._();

  static List<int> requestControl() => [FtmsOpcode.requestControl];

  static List<int> reset() => [FtmsOpcode.reset];

  /// Target speed is transmitted as uint16 little-endian in units of 0.01 km/h.
  static List<int> setTargetSpeed(double kmh) {
    final raw = (kmh * 100).round().clamp(0, 0xFFFF);
    return [FtmsOpcode.setTargetSpeed, raw & 0xFF, (raw >> 8) & 0xFF];
  }

  /// Target inclination is transmitted as sint16 little-endian in units of 0.1%.
  static List<int> setTargetInclination(double percent) {
    var raw = (percent * 10).round();
    if (raw < 0) raw += 0x10000; // two's complement for sint16
    raw &= 0xFFFF;
    return [FtmsOpcode.setTargetInclination, raw & 0xFF, (raw >> 8) & 0xFF];
  }

  static List<int> startOrResume() => [FtmsOpcode.startOrResume];

  static List<int> stop() => [FtmsOpcode.stopOrPause, FtmsStopPauseParam.stop];

  static List<int> pause() =>
      [FtmsOpcode.stopOrPause, FtmsStopPauseParam.pause];
}
