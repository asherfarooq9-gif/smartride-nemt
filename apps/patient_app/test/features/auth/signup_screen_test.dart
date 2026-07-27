import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/auth/signup_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

import '../../helpers/secure_storage_mock.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.ref);

  core.RegisterRequest? requestReceived;
  Object? failWith;

  @override
  Future<void> registerAccount(core.RegisterRequest req) async {
    requestReceived = req;
    state = const AsyncValue.loading();
    if (failWith != null) {
      state = AsyncValue.error(failWith!, StackTrace.current);
    } else {
      state = const AsyncValue.data('fake-token');
    }
  }
}

Widget _buildUnderTest(void Function(_FakeAuthNotifier) capture) {
  final router = GoRouter(
    initialLocation: '/signup',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/login', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
    ],
  );
  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) {
        final notifier = _FakeAuthNotifier(ref);
        capture(notifier);
        return notifier;
      }),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _fillCommonFields(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Jane Doe'); // full name
  await tester.enterText(fields.at(1), '+923001234567'); // phone
  await tester.enterText(fields.at(2), 'password123'); // password
  await tester.enterText(fields.at(3), 'password123'); // confirm
}

// This form is long (name/phone/password/confirm/role cards/driver fields)
// and overflows the default 800x600 test surface, which makes widgets below
// the fold fail hit tests. setSurfaceSize must run inside the test body (it
// asserts the binding is mid-test), so this is called first thing in every
// testWidgets callback below rather than from a bare setUp.
Future<void> _useTallSurface(WidgetTester tester) async {
  // Width is generous (not just phone-sized): GoogleFonts can't fetch DM
  // Sans in the test environment (no network) and falls back to a wider
  // system font, which overflows some Rows at a true phone width even
  // though the real app (with the real, narrower font) does not.
  await tester.binding.setSurfaceSize(const Size(800, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUp(mockSecureStorage);

  final createAccountButton = find.widgetWithText(ElevatedButton, 'Create Account');

  testWidgets('driver fields are hidden for the default patient role', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_buildUnderTest((_) {}));
    await tester.pumpAndSettle();

    expect(find.text('LICENSE NUMBER'), findsNothing);
    expect(find.text('VEHICLE PLATE'), findsNothing);
  });

  testWidgets('selecting Driver reveals license and plate fields', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_buildUnderTest((_) {}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Driver'));
    await tester.pumpAndSettle();

    expect(find.text('LICENSE NUMBER'), findsOneWidget);
    expect(find.text('VEHICLE PLATE'), findsOneWidget);
  });

  testWidgets('shows a mismatch error when confirm password differs', (tester) async {
    await _useTallSurface(tester);
    late _FakeAuthNotifier notifier;
    await tester.pumpWidget(_buildUnderTest((n) => notifier = n));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Jane Doe');
    await tester.enterText(fields.at(1), '+923001234567');
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'different');
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(notifier.requestReceived, isNull);
  });

  testWidgets('submits patient-only roles when patient is selected', (tester) async {
    await _useTallSurface(tester);
    late _FakeAuthNotifier notifier;
    await tester.pumpWidget(_buildUnderTest((n) => notifier = n));
    await tester.pumpAndSettle();

    await _fillCommonFields(tester);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(notifier.requestReceived, isNotNull);
    expect(notifier.requestReceived!.roles, ['patient']);
    expect(notifier.requestReceived!.activeRole, 'patient');
    expect(notifier.requestReceived!.licenseNo, isNull);
  });

  testWidgets('submits both roles with driver details when Both is selected',
      (tester) async {
    await _useTallSurface(tester);
    late _FakeAuthNotifier notifier;
    await tester.pumpWidget(_buildUnderTest((n) => notifier = n));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Both'));
    await tester.pumpAndSettle();
    await _fillCommonFields(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(4), 'LHR-DL-99999');
    await tester.enterText(fields.at(5), 'ABC-999');
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(notifier.requestReceived, isNotNull);
    expect(notifier.requestReceived!.roles, ['patient', 'driver']);
    expect(notifier.requestReceived!.licenseNo, 'LHR-DL-99999');
    expect(notifier.requestReceived!.vehiclePlate, 'ABC-999');
  });

  testWidgets('shows an error snackbar when registration fails', (tester) async {
    await _useTallSurface(tester);
    late _FakeAuthNotifier notifier;
    await tester.pumpWidget(_buildUnderTest((n) {
      notifier = n;
      notifier.failWith = const core.AppError('Phone already registered');
    }));
    await tester.pumpAndSettle();

    await _fillCommonFields(tester);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(find.text('Phone already registered'), findsOneWidget);
  });
}
