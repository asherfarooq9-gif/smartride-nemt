import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/core/locale_provider.dart';
import 'package:patient_app/features/settings/settings_screen.dart';
import 'package:patient_app/l10n/app_localizations.dart';

Future<ProviderContainer> _pump(WidgetTester tester, {Locale? locale}) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (locale != null) {
    await container.read(localeProvider.notifier).setLocale(locale);
  }
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        locale: ref.watch(localeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('every English string has an Urdu translation and the reverse', () {
    Map<String, dynamic> read(String name) =>
        jsonDecode(File('lib/l10n/$name.arb').readAsStringSync())
            as Map<String, dynamic>;
    final en = read('app_en').keys.where((k) => !k.startsWith('@')).toSet();
    final ur = read('app_ur').keys.where((k) => !k.startsWith('@')).toSet();

    expect(en.difference(ur), isEmpty, reason: 'missing in Urdu');
    expect(ur.difference(en), isEmpty, reason: 'missing in English');
  });

  testWidgets('settings reads in English by default', (tester) async {
    await _pump(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
  });

  testWidgets('settings reads in Urdu, right to left', (tester) async {
    await _pump(tester, locale: const Locale('ur'));

    expect(find.text('ترتیبات'), findsOneWidget);
    expect(find.text('ڈارک موڈ'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    final direction = Directionality.of(tester.element(find.byType(ListView)));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('picking اردو in the language list switches the app',
      (tester) async {
    final container = await _pump(tester);

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsWidgets);
    await tester.tap(find.text('اردو'));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider)?.languageCode, 'ur');
    expect(find.text('ترتیبات'), findsOneWidget);
  });
}
