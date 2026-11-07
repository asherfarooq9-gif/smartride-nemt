const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _daysUr = ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'];
const _monthsUr = [
  'جنوری',
  'فروری',
  'مارچ',
  'اپریل',
  'مئی',
  'جون',
  'جولائی',
  'اگست',
  'ستمبر',
  'اکتوبر',
  'نومبر',
  'دسمبر',
];
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
String formatDateTime(DateTime value, {String lang = 'en'}) {
  final dt = value.toLocal();
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final isUrdu = lang == 'ur';
  final period = isUrdu
      ? (dt.hour >= 12 ? '\u0634\u0627\u0645' : '\u0635\u0628\u062d')
      : (dt.hour >= 12 ? 'PM' : 'AM');
  final day = (isUrdu ? _daysUr : _days)[dt.weekday - 1];
  final month = (isUrdu ? _monthsUr : _months)[dt.month - 1];
  return '$day, ${dt.day} $month ${dt.year} \u00b7 $hour:$minute $period';
}

/// Formats an ISO-8601 timestamp from the API; returns [raw] if unparseable.
String formatIsoDateTime(String raw, {String lang = 'en'}) {
  final parsed = DateTime.tryParse(raw);
  return parsed == null ? raw : formatDateTime(parsed, lang: lang);
}

/// "Tomorrow · 9:00 AM", "Today · 4:30 PM" or "Thu 6 Nov · 9:00 AM":
/// the way people say when a trip is, in the device's local time.
String formatWhen(DateTime value, {DateTime? now, String lang = 'en'}) {
  final dt = value.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final days = DateTime(dt.year, dt.month, dt.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final isUrdu = lang == 'ur';
  final period =
      isUrdu ? (dt.hour >= 12 ? 'شام' : 'صبح') : (dt.hour >= 12 ? 'PM' : 'AM');
  final weekday = (isUrdu ? _daysUr : _days)[dt.weekday - 1];
  final month = (isUrdu ? _monthsUr : _months)[dt.month - 1];
  final day = switch (days) {
    0 => isUrdu ? 'آج' : 'Today',
    1 => isUrdu ? 'کل' : 'Tomorrow',
    _ => '$weekday ${dt.day} $month',
  };
  return '$day · $hour:$minute $period';
}
