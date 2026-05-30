import 'dart:typed_data';

/// A decoded Treadmill Data notification (characteristic 0x2ACD).
///
/// The characteristic has a variable layout: a leading uint16 flags field
/// determines which optional fields follow, in a fixed spec order.
class TreadmillData {
  const TreadmillData({
    this.instantaneousSpeedKmh,
    this.averageSpeedKmh,
    this.totalDistanceMeters,
    this.inclinationPercent,
    this.totalEnergyKcal,
    this.heartRateBpm,
    this.elapsedTimeSec,
    this.remainingTimeSec,
  });

  final double? instantaneousSpeedKmh;
  final double? averageSpeedKmh;
  final int? totalDistanceMeters;
  final double? inclinationPercent;
  final int? totalEnergyKcal;
  final int? heartRateBpm;
  final int? elapsedTimeSec;
  final int? remainingTimeSec;

  static const TreadmillData empty = TreadmillData();

  /// Parses a raw Treadmill Data payload. Walks each present field, advancing
  /// the byte offset, per the FTMS spec field order.
  factory TreadmillData.parse(List<int> bytes) {
    if (bytes.length < 2) return empty;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final flags = data.getUint16(0, Endian.little);
    var offset = 2;

    bool flag(int bit) => (flags & (1 << bit)) != 0;

    int? readUint8() {
      if (offset + 1 > bytes.length) return null;
      final v = data.getUint8(offset);
      offset += 1;
      return v;
    }

    int? readUint16() {
      if (offset + 2 > bytes.length) return null;
      final v = data.getUint16(offset, Endian.little);
      offset += 2;
      return v;
    }

    int? readInt16() {
      if (offset + 2 > bytes.length) return null;
      final v = data.getInt16(offset, Endian.little);
      offset += 2;
      return v;
    }

    int? readUint24() {
      if (offset + 3 > bytes.length) return null;
      final v = data.getUint8(offset) |
          (data.getUint8(offset + 1) << 8) |
          (data.getUint8(offset + 2) << 16);
      offset += 3;
      return v;
    }

    void skip(int n) => offset += n;

    double? instantSpeed;
    double? avgSpeed;
    int? distance;
    double? incline;
    int? energy;
    int? hr;
    int? elapsed;
    int? remaining;

    // Bit 0 (More Data): instantaneous speed present when the bit is 0.
    if (!flag(0)) {
      final raw = readUint16();
      if (raw != null) instantSpeed = raw / 100.0;
    }
    // Bit 1: Average Speed (uint16, 0.01 km/h).
    if (flag(1)) {
      final raw = readUint16();
      if (raw != null) avgSpeed = raw / 100.0;
    }
    // Bit 2: Total Distance (uint24, meters).
    if (flag(2)) {
      distance = readUint24();
    }
    // Bit 3: Inclination (sint16, 0.1%) + Ramp Angle Setting (sint16, 0.1deg).
    if (flag(3)) {
      final raw = readInt16();
      if (raw != null) incline = raw / 10.0;
      skip(2); // ramp angle setting, unused
    }
    // Bit 4: Positive + Negative Elevation Gain (uint16 each).
    if (flag(4)) skip(4);
    // Bit 5: Instantaneous Pace (uint8).
    if (flag(5)) skip(1);
    // Bit 6: Average Pace (uint8).
    if (flag(6)) skip(1);
    // Bit 7: Expended Energy — Total (uint16), Per Hour (uint16), Per Min (uint8).
    if (flag(7)) {
      energy = readUint16();
      skip(3);
    }
    // Bit 8: Heart Rate (uint8, bpm).
    if (flag(8)) {
      hr = readUint8();
    }
    // Bit 9: Metabolic Equivalent (uint8).
    if (flag(9)) skip(1);
    // Bit 10: Elapsed Time (uint16, seconds).
    if (flag(10)) {
      elapsed = readUint16();
    }
    // Bit 11: Remaining Time (uint16, seconds).
    if (flag(11)) {
      remaining = readUint16();
    }
    // Bit 12: Force on Belt (sint16) + Power Output (sint16) — ignored.

    return TreadmillData(
      instantaneousSpeedKmh: instantSpeed,
      averageSpeedKmh: avgSpeed,
      totalDistanceMeters: distance,
      inclinationPercent: incline,
      totalEnergyKcal: energy,
      heartRateBpm: hr,
      elapsedTimeSec: elapsed,
      remainingTimeSec: remaining,
    );
  }

  TreadmillData mergeWith(TreadmillData other) {
    return TreadmillData(
      instantaneousSpeedKmh:
          other.instantaneousSpeedKmh ?? instantaneousSpeedKmh,
      averageSpeedKmh: other.averageSpeedKmh ?? averageSpeedKmh,
      totalDistanceMeters: other.totalDistanceMeters ?? totalDistanceMeters,
      inclinationPercent: other.inclinationPercent ?? inclinationPercent,
      totalEnergyKcal: other.totalEnergyKcal ?? totalEnergyKcal,
      heartRateBpm: other.heartRateBpm ?? heartRateBpm,
      elapsedTimeSec: other.elapsedTimeSec ?? elapsedTimeSec,
      remainingTimeSec: other.remainingTimeSec ?? remainingTimeSec,
    );
  }
}
