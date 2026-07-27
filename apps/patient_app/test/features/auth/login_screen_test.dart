import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/auth/login_screen.dart';
import 'package:smartride_core/smartride_core.dart' as core;

import '../../helpers/secure_storage_mock.dart';

// ---------------------------------------------------------------------------
// AuthNotifier's constructor always calls its private _init() (reads
// SecureStorage) — unavoidable via subclassing. mockSecureStorage() handles
// that; this fake then overrides the public signIn() so tests don't hit the
// real network.
// ---------------------------------------------------------------------------

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.ref);

  bool signInCalled = false;
  String? phoneReceived;
  String? passwordReceived;
  Object? failWith;

  @override
  Future<void> signIn(String phone, String password, {String? activeRole}) async {
    signInCalled = true;
    phoneReceived = phone;
    passwordReceived = password;
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
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SizedBox()),
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

void main() {
  setUp(mockSecureStorage);

  testWidgets('shows validation errors and does not call signIn on empty submit',
      (tester) async {
    late _FakeAuthNotifier notifier;
    await tester.pumpWidget(_buildUnderTest((n) => notifier = n));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(notifier.signInCalled, isFalse);
  });

  testWidgets('calls signIn with trimmed phone and entered password on valid submit',
      (tester) async {
    late _FakeAuthNotifier notifier;
    await tester.pumpWidget(_buildUnderTest((n) => notifier = n));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, ' +923001234567 ');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(notifier.signInCalled, isTrue);
    expect(notifier.phoneReceived, '+923001234567');
    expect(notifier.passwordReceived, 'secret123');
  });

  testWidgets('shows an error snackbar when signIn fails with an AppError',
      (tester) async {
    late _FakeAuthNotifier notifier;
    await tester.pumpWidget(_buildUnderTest((n) {
      notifier = n;
      notifier.failWith = const core.AppError('Invalid credentials', statusCode: 401);
    }));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '+923001234567');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials'), findsOneWidget);
  });
}
