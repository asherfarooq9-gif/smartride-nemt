import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/features/auth/welcome_screen.dart';
import 'package:patient_app/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget screen, Locale locale) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp.router(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
    ]),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the welcome screen speaks English by default', (tester) async {
    await _pump(tester, const WelcomeScreen(), const Locale('en'));

    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('the welcome screen speaks Urdu when asked', (tester) async {
    await _pump(tester, const WelcomeScreen(), const Locale('ur'));

    expect(find.text('شروع کریں'), findsOneWidget);
    expect(find.text('لاگ اِن'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });
}
