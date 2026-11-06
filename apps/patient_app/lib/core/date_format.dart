const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Thu, 23 Oct 2026 · 3:05 PM" in the device's local time.
String formatDateTime(DateTime value) {
  final dt = value.toLocal();
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${_days[dt.weekday - 1]}, ${dt.day} ${_months[dt.month - 1]} '
      '${dt.year} \u00b7 $hour:$minute $period';
}

/// Formats an ISO-8601 timestamp from the API; returns [raw] if unparseable.
String formatIsoDateTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw : formatDateTime(parsed);
}

/// "Tomorrow · 9:00 AM", "Today · 4:30 PM" or "Thu 6 Nov · 9:00 AM":
/// the way people say when a trip is, in the device's local time.
String formatWhen(DateTime value, {DateTime? now}) {
  final dt = value.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final days = DateTime(dt.year, dt.month, dt.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final day = switch (days) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => '${_days[dt.weekday - 1]} ${dt.day} ${_months[dt.month - 1]}',
  };
  return '$day · $hour:$minute $period';
}
