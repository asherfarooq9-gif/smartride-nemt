import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:patient_app/core/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('writeToken stores token and readToken retrieves it', () async {
    await SecureStorage.writeToken('test_jwt_123');
    final token = await SecureStorage.readToken();
    expect(token, 'test_jwt_123');
  });

  test('deleteToken removes token', () async {
    await SecureStorage.writeToken('test_jwt_123');
    await SecureStorage.deleteToken();
    final token = await SecureStorage.readToken();
    expect(token, isNull);
  });

  test('readToken returns null when no token stored', () async {
    final token = await SecureStorage.readToken();
    expect(token, isNull);
  });
}
