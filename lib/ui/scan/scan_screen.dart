import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../ble/scan_controller.dart';
import '../router.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scanControllerProvider).startScan();
    });
  }

  Future<void> _connect(ClassifiedDevice cd) async {
    if (_connecting) return;
    setState(() => _connecting = true);
    final scan = ref.read(scanControllerProvider);
    final ftms = ref.read(ftmsServiceProvider);
    await scan.stopScan();

    final ok = await ftms.connectAndSetup(cd.device);
    if (!mounted) return;
    setState(() => _connecting = false);

    if (ok) {
      context.go(AppRoutes.dashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ftms.errorMessage ?? 'Could not connect.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scan = ref.watch(scanControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find your treadmill'),
        actions: [
          IconButton(
            tooltip: 'Activity calendar',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => context.push(AppRoutes.activity),
          ),
          IconButton(
            tooltip: 'Workout plans',
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.push(AppRoutes.plans),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: scan.isScanning ? scan.stopScan : scan.startScan,
        icon: Icon(scan.isScanning ? Icons.stop : Icons.bluetooth_searching),
        label: Text(scan.isScanning ? 'Stop' : 'Scan'),
      ),
      body: _connecting
          ? const _Connecting()
          : RefreshIndicator(
              onRefresh: scan.startScan,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (scan.error != null)
                    _Banner(text: scan.error!, color: Colors.redAccent),
                  if (scan.isScanning) const _ScanningIndicator(),
                  _Section(
                    title: 'Treadmills found',
                    icon: Icons.directions_run,
                    highlight: true,
                    devices: scan.treadmills,
                    onTap: _connect,
                    emptyHint: scan.isScanning
                        ? 'Scanning for FTMS treadmills…'
                        : 'No treadmills detected yet. Tap Scan.',
                  ),
                  if (scan.possibleFitness.isNotEmpty)
                    _Section(
                      title: 'Possible fitness devices',
                      icon: Icons.fitness_center,
                      devices: scan.possibleFitness,
                      onTap: _connect,
                    ),
                  _Section(
                    title: 'Other nearby devices',
                    icon: Icons.bluetooth,
                    dimmed: true,
                    devices: scan.otherDevices,
                    onTap: _connect,
                  ),
                ],
              ),
            ),
    );
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Connecting and requesting control…'),
        ],
      ),
    );
  }
}

class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Scanning…'),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.devices,
    required this.onTap,
    this.highlight = false,
    this.dimmed = false,
    this.emptyHint,
  });

  final String title;
  final IconData icon;
  final List<ClassifiedDevice> devices;
  final void Function(ClassifiedDevice) onTap;
  final bool highlight;
  final bool dimmed;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = highlight ? theme.colorScheme.primary : null;

    if (devices.isEmpty && emptyHint == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (devices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              emptyHint!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
          )
        else
          ...devices.map((d) => _DeviceTile(
                device: d,
                highlight: highlight,
                dimmed: dimmed,
                onTap: () => onTap(d),
              )),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onTap,
    this.highlight = false,
    this.dimmed = false,
  });

  final ClassifiedDevice device;
  final VoidCallback onTap;
  final bool highlight;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: highlight
            ? CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.directions_run, color: Colors.black),
              )
            : Icon(
                Icons.bluetooth,
                color: dimmed ? theme.hintColor : null,
              ),
        title: Text(
          device.name,
          style: dimmed ? TextStyle(color: theme.hintColor) : null,
        ),
        subtitle: Text(
          '${device.id}  ·  ${device.rssi} dBm',
          style: theme.textTheme.bodySmall,
        ),
        trailing: highlight
            ? Icon(Icons.circle, size: 12, color: theme.colorScheme.primary)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
