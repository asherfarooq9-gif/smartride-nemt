import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/date_format.dart';

void main() {
  final now = DateTime(2026, 11, 5, 10);

  test('English stays the default', () {
    expect(
        formatWhen(DateTime(2026, 11, 6, 9), now: now), 'Tomorrow · 9:00 AM');
  });

  test('Urdu says today, tomorrow and the time of day in Urdu', () {
    expect(formatWhen(DateTime(2026, 11, 5, 16, 30), now: now, lang: 'ur'),
        'آج · 4:30 شام');
    expect(formatWhen(DateTime(2026, 11, 6, 9), now: now, lang: 'ur'),
        'کل · 9:00 صبح');
  });

  test('Urdu names the weekday and month', () {
    // Monday 9 November 2026.
    expect(formatWhen(DateTime(2026, 11, 9, 0, 5), now: now, lang: 'ur'),
        'پیر 9 نومبر · 12:05 صبح');
  });

  test('a full date and time reads in Urdu too', () {
    expect(formatDateTime(DateTime(2026, 11, 9, 15, 5), lang: 'ur'),
        'پیر, 9 نومبر 2026 · 3:05 شام');
  });
}
