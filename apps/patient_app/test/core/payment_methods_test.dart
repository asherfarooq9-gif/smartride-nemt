import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/payment_methods.dart';
import 'package:patient_app/l10n/app_localizations_en.dart';
import 'package:patient_app/l10n/app_localizations_ur.dart';

void main() {
  test('lists the methods in the order the driver chose', () {
    expect(
      paymentMethodsSummary(AppLocalizationsEn(), ['cash', 'easypaisa']),
      'Cash · Easypaisa',
    );
  });

  test('says nothing when the driver listed none', () {
    expect(paymentMethodsSummary(AppLocalizationsEn(), []), '');
  });

  test('reads in Urdu', () {
    expect(
      paymentMethodsSummary(AppLocalizationsUr(), ['jazzcash']),
      'جاز کیش',
    );
  });

  test('every known method has a label in both languages', () {
    for (final id in paymentMethodIds) {
      expect(paymentMethodLabel(AppLocalizationsEn(), id), isNot(id));
      expect(paymentMethodLabel(AppLocalizationsUr(), id), isNot(id));
    }
  });
}
