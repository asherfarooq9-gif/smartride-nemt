import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patient_app/core/locale_provider.dart';
import 'package:patient_app/features/auth/language_screen.dart';
import 'package:patient_app/l10n/l10n.dart';

class _App extends ConsumerWidget {
  const _App({required this.router});
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        routerConfig: router,
        locale: ref.watch(localeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/language',
    routes: [
      GoRoute(path: '/language', builder: (_, __) => const LanguageScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const Text('welcome page')),
    ],
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
        container: container, child: _App(router: router)),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('offers English and Urdu, each in its own name', (tester) async {
    await _pump(tester);

    expect(find.text('Choose language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('اردو'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('English is ticked to start with', (tester) async {
    await _pump(tester);

    expect(find.byIcon(Icons.check), findsOneWidget);
    final tick = tester.getCenter(find.byIcon(Icons.check));
    final english = tester.getCenter(find.text('English'));
    final urdu = tester.getCenter(find.text('اردو'));
    expect((tick.dy - english.dy).abs(), lessThan((tick.dy - urdu.dy).abs()));
  });

  testWidgets('a selection list has no "more" chevrons', (tester) async {
    await _pump(tester);

    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('tapping Urdu switches the screen to Urdu at once',
      (tester) async {
    final container = await _pump(tester);

    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), const Locale('ur'));
    expect(find.text('Choose language'), findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('Continue saves the language and opens the welcome page',
      (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(container.read(languageChosenProvider), isTrue);
    expect(container.read(localeProvider), const Locale('ur'));
    expect(find.text('welcome page'), findsOneWidget);
  });

  testWidgets('Continue with no tap keeps and saves the shown language',
      (tester) async {
    final container = await _pump(tester);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), const Locale('en'));
    expect(container.read(languageChosenProvider), isTrue);
    expect(find.text('welcome page'), findsOneWidget);
  });
}
