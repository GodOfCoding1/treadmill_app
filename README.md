# Treadmill App

A Flutter app that connects to any **FTMS** (Fitness Machine Service, BLE UUID `0x1826`)
treadmill, lets you build custom interval workout plans, and runs them automatically by
controlling the treadmill in real time. Built to work with treadmills that expose the open
FTMS standard, instead of relying on a manufacturer's paywalled app.

BLE is handled by [`universal_ble`](https://pub.dev/packages/universal_ble), which is
**BSD-3-Clause licensed and free for commercial use** — so this app can be published to the
Play Store (and other stores) at no cost.

## Features

- Scan + auto-classify nearby BLE devices into **Treadmills / Possible fitness / Other**.
- Connect and run the full FTMS setup sequence (enable indications, request control).
- **Capability detection**: reads the Fitness Machine Feature (`0x2ACC`) and supported
  speed/incline ranges (`0x2AD4` / `0x2AD5`) so the UI only exposes controls the treadmill
  actually supports, with sliders bounded to the device's real ranges.
- Live data parsing from Treadmill Data (`0x2ACD`): speed, incline, distance, HR, time.
- Manual control dashboard (speed/incline sliders, start/pause/stop).
- Workout plan builder (reorderable intervals) with local persistence.
- Workout engine: a pausable/cancellable 1-second state machine that transitions between
  intervals by sending new target speed/incline (never Stop), with a live countdown,
  progress bar, "up next" preview, and completion summary.

## Architecture

```
lib/
  main.dart            App entry + router setup
  app_providers.dart   Riverpod providers wiring services together
  core/                UUIDs, opcodes/encoders, theme, permissions, formatting
  ble/                 FtmsService (connection + control-point queue), ScanController
  ftms/                Decoders: TreadmillData, TreadmillCapabilities/ranges
  domain/              WorkoutPlan / WorkoutInterval models
  workout/             WorkoutEngine state machine
  data/                PlanRepository (shared_preferences)
  ui/                  scan / dashboard / plans / builder / active screens
```

The BLE byte protocol is isolated inside `core/ftms_constants.dart` (encoders) and
`ble/ftms_service.dart` (connection + serialized request/response queue, built on
`universal_ble`). UI and the workout engine never touch raw bytes — so the BLE library can be
swapped by editing only `ble/`.

## Getting started

This repository contains the complete Dart source plus a hand-written Android scaffold.
You need the Flutter SDK installed to build and run.

1. **Install Flutter** (3.16+ recommended): https://docs.flutter.dev/get-started/install
2. From the project root:

   ```bash
   flutter pub get
   ```

3. **Android** (primary target) — plug in a phone with USB debugging enabled and run:

   ```bash
   flutter run
   ```

4. **iOS** (structure prepared, not yet generated). The `ios/Runner/Info.plist` with the
   required Bluetooth/location keys is included, but the Xcode project itself is not
   hand-written. Generate it once with:

   ```bash
   flutter create --platforms=ios .
   ```

   This will scaffold the Xcode project; then re-apply the three usage-description keys in
   `ios/Runner/Info.plist` if `flutter create` overwrote them (see the keys in this repo).

## Protocol notes / verification checklist

The control-point command bytes follow the Bluetooth SIG FTMS spec:

| Command            | Bytes                                  |
|--------------------|----------------------------------------|
| Request Control    | `0x00`                                 |
| Set Target Speed   | `0x02, <uint16 LE 0.01 km/h>`          |
| Set Target Incline | `0x03, <sint16 LE 0.1%>`               |
| Start / Resume     | `0x07`                                 |
| Pause              | `0x08, 0x02`                           |
| Stop               | `0x08, 0x01`                           |

> **Per-device quirk to re-verify:** during nRF Connect recon, the FS-9B02FD appeared to
> accept a bare `0x08` (stop) and `0x09` (pause). The standard form uses a single op-code
> `0x08` with a parameter byte (`0x01` stop / `0x02` pause), which is what this app sends for
> broad compatibility. If your treadmill rejects the parameterised form (result code
> `Op Code Not Supported`), switch `FtmsCommands.stop()/pause()` in
> `lib/core/ftms_constants.dart` to the bare bytes.

## Tests

```bash
flutter test
```

`test/ftms_protocol_test.dart` covers the command encoders, the Treadmill Data parser, and
the capability/range parsers.
