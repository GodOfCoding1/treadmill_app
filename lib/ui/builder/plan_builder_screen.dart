import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_providers.dart';
import '../../core/format.dart';
import '../../core/interval_labels.dart';
import '../../domain/workout_plan.dart';
import '../layout/responsive.dart';

class PlanBuilderScreen extends ConsumerStatefulWidget {
  const PlanBuilderScreen({super.key, this.existing});

  final WorkoutPlan? existing;

  @override
  ConsumerState<PlanBuilderScreen> createState() => _PlanBuilderScreenState();
}

class _PlanBuilderScreenState extends ConsumerState<PlanBuilderScreen> {
  late TextEditingController _nameController;
  late List<WorkoutInterval> _intervals;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? 'New Workout');
    _intervals = List<WorkoutInterval>.from(
      widget.existing?.intervals ??
          [
            WorkoutInterval(label: 'Warm up', durationSec: 300, speedKmh: 4.0),
          ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _totalSec => _intervals.fold(0, (sum, i) => sum + i.durationSec);

  Future<void> _save() async {
    final repo = ref.read(planRepositoryProvider);
    final plan = WorkoutPlan(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim().isEmpty
          ? 'Untitled Workout'
          : _nameController.text.trim(),
      intervals: _intervals,
    );
    await repo.save(plan);
    if (mounted) context.pop();
  }

  Future<void> _editInterval(int index) async {
    final result = await showAdaptiveSheet<WorkoutInterval>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IntervalEditor(interval: _intervals[index]),
    );
    if (result != null) {
      setState(() => _intervals[index] = result);
    }
  }

  Future<void> _addInterval() async {
    final result = await showAdaptiveSheet<WorkoutInterval>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IntervalEditor(
        interval:
            WorkoutInterval(label: 'Run', durationSec: 120, speedKmh: 6.0),
      ),
    );
    if (result != null) {
      setState(() => _intervals.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Create plan' : 'Edit plan'),
        actions: [
          TextButton(
            onPressed: _intervals.isEmpty ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addInterval,
        icon: const Icon(Icons.add),
        label: const Text('Add interval'),
      ),
      body: OrientationLayout(
        portrait: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Plan name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_intervals.length} intervals  ·  '
                  '${formatDuration(_totalSec)} total',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(child: _intervalList()),
          ],
        ),
        landscape: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Plan name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${_intervals.length} intervals  ·  '
                      '${formatDuration(_totalSec)} total',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _intervalList()),
          ],
        ),
      ),
    );
  }

  Widget _intervalList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: _intervals.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _intervals.removeAt(oldIndex);
          _intervals.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final iv = _intervals[index];
        return Card(
          key: ObjectKey(iv),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.drag_handle),
            title: Text(iv.label),
            subtitle: Text(
              '${formatClock(iv.durationSec)}  ·  '
              '${iv.speedKmh.toStringAsFixed(1)} km/h  ·  '
              '${iv.inclinePct.toStringAsFixed(1)}%',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _editInterval(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => setState(() => _intervals.removeAt(index)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IntervalEditor extends StatefulWidget {
  const _IntervalEditor({required this.interval});
  final WorkoutInterval interval;

  @override
  State<_IntervalEditor> createState() => _IntervalEditorState();
}

class _IntervalEditorState extends State<_IntervalEditor> {
  late TextEditingController _label;
  late String? _selectedPreset;
  late int _minutes;
  late int _seconds;
  late double _speed;
  late double _incline;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.interval.label);
    _selectedPreset = matchingIntervalLabelPreset(widget.interval.label);
    _minutes = widget.interval.durationSec ~/ 60;
    _seconds = widget.interval.durationSec % 60;
    _speed = widget.interval.speedKmh;
    _incline = widget.interval.inclinePct;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    final duration = (_minutes * 60 + _seconds).clamp(1, 24 * 3600);
    Navigator.of(context).pop(
      WorkoutInterval(
        label: _label.text.trim().isEmpty ? 'Interval' : _label.text.trim(),
        durationSec: duration,
        speedKmh: _speed,
        inclinePct: _incline,
      ),
    );
  }

  void _setPresetLabel(String preset) {
    setState(() {
      _selectedPreset = preset;
      _label.value = TextEditingValue(
        text: preset,
        selection: TextSelection.collapsed(offset: preset.length),
      );
    });
  }

  void _syncSelectedPreset(String value) {
    setState(() {
      _selectedPreset = matchingIntervalLabelPreset(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interval', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Label', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(
              'Pick one or type your own',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in kIntervalLabelPresets)
                  FilterChip(
                    label: Text(preset),
                    selected: _selectedPreset == preset,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => _setPresetLabel(preset),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              onChanged: _syncSelectedPreset,
              decoration: const InputDecoration(
                labelText: 'Custom label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _NumberStepper(
                    label: 'Minutes',
                    value: _minutes,
                    min: 0,
                    max: 180,
                    onChanged: (v) => setState(() => _minutes = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberStepper(
                    label: 'Seconds',
                    value: _seconds,
                    min: 0,
                    max: 59,
                    step: 5,
                    onChanged: (v) => setState(() => _seconds = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LabeledSlider(
              label: 'Speed',
              value: _speed,
              min: 0,
              max: 20,
              step: 0.5,
              unit: 'km/h',
              onChanged: (v) => setState(() => _speed = v),
            ),
            _LabeledSlider(
              label: 'Incline',
              value: _incline,
              min: 0,
              max: 15,
              step: 0.5,
              unit: '%',
              onChanged: (v) => setState(() => _incline = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              onPressed: value > min
                  ? () => onChanged((value - step).clamp(min, max))
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text('$value', style: Theme.of(context).textTheme.titleLarge),
            IconButton.filledTonal(
              onPressed: value < max
                  ? () => onChanged((value + step).clamp(min, max))
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final divisions = ((max - min) / step).round().clamp(1, 1000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Text('${value.toStringAsFixed(1)} $unit'),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
