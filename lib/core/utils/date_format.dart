const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "Sun, 11 Oct 2026 · 13:06" (local time).
String formatDateTime(DateTime t) {
  final d = t.toLocal();
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} '
      '${d.year} · ${_two(d.hour)}:${_two(d.minute)}';
}

/// "1h 12m" or "45m". Under a minute shows "<1m".
String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 1) return '<1m';
  if (minutes < 60) return '${minutes}m';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

/// "Sun, 11 Oct 2026" (local time).
String formatDate(DateTime t) {
  final d = t.toLocal();
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
}
