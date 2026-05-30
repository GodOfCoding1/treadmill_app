import 'package:flutter_test/flutter_test.dart';
import 'package:treadmill_app/core/ftms_constants.dart';
import 'package:treadmill_app/ftms/capabilities.dart';
import 'package:treadmill_app/ftms/treadmill_data.dart';

void main() {
  group('Control point encoders', () {
    test('set target speed encodes 0.01 km/h little-endian', () {
      expect(FtmsCommands.setTargetSpeed(1.0), [0x02, 0x64, 0x00]);
      expect(FtmsCommands.setTargetSpeed(6.0), [0x02, 0x58, 0x02]);
      expect(FtmsCommands.setTargetSpeed(10.0), [0x02, 0xE8, 0x03]);
      expect(FtmsCommands.setTargetSpeed(12.0), [0x02, 0xB0, 0x04]);
      expect(FtmsCommands.setTargetSpeed(15.0), [0x02, 0xDC, 0x05]);
    });

    test('set target incline encodes 0.1% little-endian', () {
      expect(FtmsCommands.setTargetInclination(1.0), [0x03, 0x0A, 0x00]);
      expect(FtmsCommands.setTargetInclination(5.0), [0x03, 0x32, 0x00]);
    });

    test('negative incline uses two-complement sint16', () {
      // -1.0% -> raw -10 -> 0xFFF6
      expect(FtmsCommands.setTargetInclination(-1.0), [0x03, 0xF6, 0xFF]);
    });

    test('start / pause / stop', () {
      expect(FtmsCommands.startOrResume(), [0x07]);
      expect(FtmsCommands.pause(), [0x08, 0x02]);
      expect(FtmsCommands.stop(), [0x08, 0x01]);
      expect(FtmsCommands.requestControl(), [0x00]);
    });
  });

  group('Result codes', () {
    test('maps known bytes', () {
      expect(FtmsResultCode.fromByte(0x01), FtmsResultCode.success);
      expect(FtmsResultCode.fromByte(0x05),
          FtmsResultCode.controlNotPermitted);
      expect(FtmsResultCode.fromByte(0xAA), FtmsResultCode.unknown);
    });
  });

  group('Treadmill data parser', () {
    test('parses instantaneous speed only', () {
      // flags = 0x0000 (More Data bit 0 clear -> speed present), speed = 600 (6 km/h)
      final data = TreadmillData.parse([0x00, 0x00, 0x58, 0x02]);
      expect(data.instantaneousSpeedKmh, closeTo(6.0, 0.001));
    });

    test('parses speed + inclination', () {
      // flags bit3 set (0x08) -> inclination present after speed.
      // speed = 1000 (10 km/h), incline = 15 (1.5%), ramp angle = 0
      final data = TreadmillData.parse([
        0x08, 0x00, // flags
        0xE8, 0x03, // speed 10.0
        0x0F, 0x00, // inclination 1.5%
        0x00, 0x00, // ramp angle (ignored)
      ]);
      expect(data.instantaneousSpeedKmh, closeTo(10.0, 0.001));
      expect(data.inclinationPercent, closeTo(1.5, 0.001));
    });

    test('handles empty payload', () {
      expect(TreadmillData.parse([]).instantaneousSpeedKmh, isNull);
    });
  });

  group('Capabilities parser', () {
    test('reads target setting feature bits', () {
      // Fitness Machine Features = 0, Target Setting = bit0 | bit1 = 0x03
      final caps = TreadmillCapabilities.fromFeature(
          [0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00]);
      expect(caps.supportsSpeedTarget, isTrue);
      expect(caps.supportsInclinationTarget, isTrue);
      expect(caps.supportsResistanceTarget, isFalse);
    });

    test('parses speed range (0.01 km/h units)', () {
      // min 100 (1.0), max 2000 (20.0), step 10 (0.1)
      final range = TreadmillCapabilities.parseSpeedRange(
          [0x64, 0x00, 0xD0, 0x07, 0x0A, 0x00]);
      expect(range!.min, closeTo(1.0, 0.001));
      expect(range.max, closeTo(20.0, 0.001));
      expect(range.increment, closeTo(0.1, 0.001));
    });

    test('parses inclination range (0.1% units, signed)', () {
      // min -50 (-5.0), max 150 (15.0), step 5 (0.5)
      final range = TreadmillCapabilities.parseInclinationRange(
          [0xCE, 0xFF, 0x96, 0x00, 0x05, 0x00]);
      expect(range!.min, closeTo(-5.0, 0.001));
      expect(range.max, closeTo(15.0, 0.001));
      expect(range.increment, closeTo(0.5, 0.001));
    });
  });
}
