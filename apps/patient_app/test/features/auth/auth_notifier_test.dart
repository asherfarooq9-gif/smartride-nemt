import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/features/auth/auth_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('initial state is AsyncData(null) when no token stored', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = await container.read(authNotifierProvider.future);
    expect(state, isNull);
  });

  test('logout clears token and state becomes AsyncData(null)', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'tok'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.notifier).logout();
    final state = await container.read(authNotifierProvider.future);
    expect(state, isNull);
  });

  test('build restores session if token exists in secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'existing_token'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = await container.read(authNotifierProvider.future);
    expect(state, isNotNull);
    expect(state!.token, 'existing_token');
  });
}
