import 'dart:typed_data';

/// A min/max/increment range as advertised by a Supported * Range
/// characteristic. Values are already converted to human units.
class FtmsRange {
  const FtmsRange({
    required this.min,
    required this.max,
    required this.increment,
  });

  final double min;
  final double max;
  final double increment;

  @override
  String toString() => 'FtmsRange(min: $min, max: $max, step: $increment)';
}

/// Parsed Fitness Machine Feature characteristic (0x2ACC) plus the supported
/// speed/incline ranges read from 0x2AD4 / 0x2AD5. Drives what the UI exposes.
class TreadmillCapabilities {
  const TreadmillCapabilities({
    required this.fitnessMachineFeatures,
    required this.targetSettingFeatures,
    this.speedRange,
    this.inclinationRange,
  });

  final int fitnessMachineFeatures;
  final int targetSettingFeatures;
  final FtmsRange? speedRange;
  final FtmsRange? inclinationRange;

  // Target Setting Features bit positions (second uint32 of 0x2ACC).
  bool get supportsSpeedTarget => _bit(targetSettingFeatures, 0);
  bool get supportsInclinationTarget => _bit(targetSettingFeatures, 1);
  bool get supportsResistanceTarget => _bit(targetSettingFeatures, 2);
  bool get supportsPowerTarget => _bit(targetSettingFeatures, 3);

  // A few useful Fitness Machine Features bits (first uint32 of 0x2ACC).
  bool get hasInclinationData => _bit(fitnessMachineFeatures, 3);
  bool get hasHeartRateData => _bit(fitnessMachineFeatures, 10);

  /// Sensible UI bounds for the speed slider, falling back to a generic range
  /// when the device does not advertise one.
  double get minSpeed => speedRange?.min ?? 0.0;
  double get maxSpeed => speedRange?.max ?? 20.0;
  double get speedStep =>
      (speedRange?.increment ?? 0.1).clamp(0.1, double.infinity);

  double get minIncline => inclinationRange?.min ?? 0.0;
  double get maxIncline => inclinationRange?.max ?? 15.0;
  double get inclineStep =>
      (inclinationRange?.increment ?? 0.5).clamp(0.1, double.infinity);

  static bool _bit(int value, int index) => (value & (1 << index)) != 0;

  /// Parses the 8-byte Fitness Machine Feature value (two LE uint32 fields).
  factory TreadmillCapabilities.fromFeature(List<int> bytes) {
    if (bytes.length < 8) {
      return const TreadmillCapabilities(
        fitnessMachineFeatures: 0,
        targetSettingFeatures: 0,
      );
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return TreadmillCapabilities(
      fitnessMachineFeatures: data.getUint32(0, Endian.little),
      targetSettingFeatures: data.getUint32(4, Endian.little),
    );
  }

  TreadmillCapabilities copyWith({
    FtmsRange? speedRange,
    FtmsRange? inclinationRange,
  }) {
    return TreadmillCapabilities(
      fitnessMachineFeatures: fitnessMachineFeatures,
      targetSettingFeatures: targetSettingFeatures,
      speedRange: speedRange ?? this.speedRange,
      inclinationRange: inclinationRange ?? this.inclinationRange,
    );
  }

  /// Supported Speed Range (0x2AD4): three LE uint16 in units of 0.01 km/h.
  static FtmsRange? parseSpeedRange(List<int> bytes) {
    if (bytes.length < 6) return null;
    final d = ByteData.sublistView(Uint8List.fromList(bytes));
    return FtmsRange(
      min: d.getUint16(0, Endian.little) / 100.0,
      max: d.getUint16(2, Endian.little) / 100.0,
      increment: d.getUint16(4, Endian.little) / 100.0,
    );
  }

  /// Supported Inclination Range (0x2AD5): two LE sint16 + one LE uint16,
  /// all in units of 0.1%.
  static FtmsRange? parseInclinationRange(List<int> bytes) {
    if (bytes.length < 6) return null;
    final d = ByteData.sublistView(Uint8List.fromList(bytes));
    return FtmsRange(
      min: d.getInt16(0, Endian.little) / 10.0,
      max: d.getInt16(2, Endian.little) / 10.0,
      increment: d.getUint16(4, Endian.little) / 10.0,
    );
  }
}
