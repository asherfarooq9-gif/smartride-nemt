import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:patient_app/shared/offline_banner.dart';
import 'package:smartride_core/smartride_core.dart' as core;

Widget _app() => const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: OfflineBanner(child: Text('content'))),
    );

void main() {
  tearDown(() => core.ApiClient.isReachable.value = true);

  testWidgets('shows nothing while the server is reachable', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('content'), findsOneWidget);
    expect(find.textContaining('No connection'), findsNothing);
  });

  testWidgets(
      'shows a bar when the server cannot be reached and hides it again',
      (tester) async {
    await tester.pumpWidget(_app());

    core.ApiClient.isReachable.value = false;
    await tester.pump();
    expect(find.textContaining('No connection'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);

    core.ApiClient.isReachable.value = true;
    await tester.pump();
    expect(find.textContaining('No connection'), findsNothing);
  });
}
