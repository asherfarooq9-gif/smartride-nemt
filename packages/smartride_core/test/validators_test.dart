import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';

void main() {
  group('Validators.phone', () {
    test('valid numbers pass', () {
      expect(Validators.phone('+923001234567'), isNull);
      expect(Validators.phone('1234567890'), isNull);
      expect(Validators.phone('+12345678901234'), isNull);
    });

    test('invalid numbers fail', () {
      expect(Validators.phone(''), isNotNull);
      expect(Validators.phone('123'), isNotNull);
      expect(Validators.phone('abcdefghij'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('valid passwords pass', () {
      expect(Validators.password('secret123'), isNull);
      expect(Validators.password('abcdef'), isNull);
    });

    test('short password fails', () {
      expect(Validators.password('abc'), isNotNull);
      expect(Validators.password(''), isNotNull);
    });
  });

  group('Validators.symptomText', () {
    test('valid symptom passes', () {
      expect(Validators.symptomText('chest pain and shortness of breath'), isNull);
    });

    test('empty fails', () {
      expect(Validators.symptomText(''), isNotNull);
      expect(Validators.symptomText(null), isNotNull);
    });

    test('too long fails', () {
      expect(Validators.symptomText('a' * 2001), isNotNull);
      expect(Validators.symptomText('a' * 2000), isNull);
    });
  });

  group('Validators.required', () {
    test('non-empty passes', () => expect(Validators.required('hello'), isNull));
    test('empty fails', () => expect(Validators.required(''), isNotNull));
    test('whitespace fails', () => expect(Validators.required('   '), isNotNull));
  });
}
