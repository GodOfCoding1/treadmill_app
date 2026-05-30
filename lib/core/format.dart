/// Formats a duration in seconds as `m:ss` (or `h:mm:ss` past an hour).
String formatDuration(int totalSeconds) {
  final s = totalSeconds.clamp(0, 1 << 31);
  final hours = s ~/ 3600;
  final minutes = (s % 3600) ~/ 60;
  final seconds = s % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}

/// Formats `m:ss` always with two-digit minutes for compact rows.
String formatClock(int totalSeconds) {
  final s = totalSeconds.clamp(0, 1 << 31);
  final minutes = s ~/ 60;
  final seconds = s % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
