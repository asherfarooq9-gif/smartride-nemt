import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/locale_provider.dart';
import 'package:patient_app/core/router.dart';
import 'package:patient_app/features/auth/language_screen.dart';
import 'package:patient_app/features/auth/welcome_screen.dart';
import 'package:patient_app/l10n/l10n.dart';

/// The real router, with real (storage-backed) providers and an empty phone.
Future<void> _launch(WidgetTester tester, Map<String, String> saved) async {
  FlutterSecureStorage.setMockInitialValues(saved);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          routerConfig: ref.watch(routerProvider),
          locale: ref.watch(localeProvider),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a first launch opens the language screen', (tester) async {
    await _launch(tester, {});

    expect(find.byType(LanguageScreen), findsOneWidget);
    expect(find.text('We could not find that page.'), findsNothing);
  });

  testWidgets('confirming a language opens the welcome page', (tester) async {
    await _launch(tester, {});

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(LanguageScreen), findsNothing);
  });

  testWidgets('a returning visitor goes straight to the welcome page',
      (tester) async {
    await _launch(tester, {'app_locale': 'ur'});

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(LanguageScreen), findsNothing);
  });
}
