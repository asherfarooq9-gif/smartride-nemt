import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/api_client.dart';

void main() {
  test('ApiException toString includes status code and message', () {
    const e = ApiException('Not found', statusCode: 404);
    expect(e.toString(), contains('404'));
    expect(e.toString(), contains('Not found'));
  });

  test('ApiException with no status code still formats', () {
    const e = ApiException('Network error');
    expect(e.toString(), isA<String>());
    expect(e.message, 'Network error');
  });
}
