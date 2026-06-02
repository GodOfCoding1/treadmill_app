const kIntervalLabelPresets = [
  'Warm up',
  'Jog',
  'Run',
  'Walk',
  'Sprint',
  'Recover',
  'Cool down',
];

String? matchingIntervalLabelPreset(String value) {
  final normalized = value.trim().toLowerCase();
  for (final preset in kIntervalLabelPresets) {
    if (preset.toLowerCase() == normalized) {
      return preset;
    }
  }
  return null;
}
