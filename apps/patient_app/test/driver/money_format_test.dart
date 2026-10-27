import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/driver/money_format.dart';

void main() {
  group('formatPkr', () {
    test('whole rupees have no decimals, with thousands separators', () {
      expect(formatPkr(0), 'PKR 0');
      expect(formatPkr(27), 'PKR 27');
      expect(formatPkr(1500), 'PKR 1,500');
      expect(formatPkr(1234567), 'PKR 1,234,567');
    });

    test('paisa are shown, not truncated', () {
      expect(formatPkr(27.5), 'PKR 27.50');
      expect(formatPkr(1234.05), 'PKR 1,234.05');
      expect(formatPkr(199.99), 'PKR 199.99');
    });

    test('rounds to the nearest paisa instead of dropping', () {
      expect(formatPkr(10.999), 'PKR 11');
      expect(formatPkr(0.004), 'PKR 0');
    });

    test('a negative balance shows its sign even when it is under one rupee', () {
      expect(formatPkr(-12.5), '−PKR 12.50');
      expect(formatPkr(-0.5), '−PKR 0.50');
      expect(formatPkr(-1500), '−PKR 1,500');
    });

    test('a value that rounds to zero has no sign', () {
      expect(formatPkr(-0.001), 'PKR 0');
    });
  });

  group('formatSignedPkr', () {
    test('credits get a plus and debits a minus, by the amount, not the type', () {
      expect(formatSignedPkr(500), '+PKR 500');
      expect(formatSignedPkr(-27), '−PKR 27');
      expect(formatSignedPkr(-27.5), '−PKR 27.50');
    });

    test('a commission stored as -27 is not printed as minus-PKR-minus-27', () {
      expect(formatSignedPkr(-27), isNot(contains('-')));
    });

    test('zero has no sign', () {
      expect(formatSignedPkr(0), 'PKR 0');
    });
  });

  group('isCreditAmount', () {
    test('follows the sign of the amount', () {
      expect(isCreditAmount(500), isTrue);
      expect(isCreditAmount(-27), isFalse);
      // An opening 'adjustment' can be either; it must not be drawn as a debit
      // just because its type is not 'topup'.
      expect(isCreditAmount(250), isTrue);
    });
  });
}
