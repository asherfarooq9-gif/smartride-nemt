import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/features/chat/chat_backend.dart';
import 'package:patient_app/features/chat/chat_screen.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:smartride_core/smartride_core.dart' as core;

import 'fake_chat_backend.dart';

typedef _Fake = FakeChatBackend;

Future<void> _pump(
  WidgetTester tester,
  FakeChatBackend backend, {
  core.ChatSender me = core.ChatSender.patient,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [chatBackendProvider.overrideWithValue(backend)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(rideId: 'ride-1', me: me),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _field => find.byType(TextField);
Finder get _sendButton => find.byKey(const ValueKey('chat-send'));

void main() {
  testWidgets('shows the history, mine on one side and theirs on the other',
      (tester) async {
    final backend = FakeChatBackend(history: [
      _Fake.message(1, core.ChatSender.patient, 'I am at the blue gate'),
      _Fake.message(2, core.ChatSender.driver, 'Two minutes away'),
    ]);
    await _pump(tester, backend);

    final mine = tester.getCenter(find.text('I am at the blue gate'));
    final theirs = tester.getCenter(find.text('Two minutes away'));
    expect(mine.dx, greaterThan(theirs.dx), reason: 'mine sits on the right');
  });

  testWidgets('the title names the other person', (tester) async {
    await _pump(tester, FakeChatBackend());
    expect(find.text('Driver'), findsOneWidget);
  });

  testWidgets('a driver sees "Patient" in the title', (tester) async {
    await _pump(tester, FakeChatBackend(), me: core.ChatSender.driver);
    expect(find.text('Patient'), findsOneWidget);
  });

  testWidgets('says so when nobody has written yet', (tester) async {
    await _pump(tester, FakeChatBackend());
    expect(find.text('No messages yet. Say hello.'), findsOneWidget);
    expect(
        find.text('Messages are deleted when the ride ends.'), findsOneWidget);
  });

  testWidgets('send is off until there is text', (tester) async {
    await _pump(tester, FakeChatBackend());

    expect(tester.widget<IconButton>(_sendButton).onPressed, isNull);
    await tester.enterText(_field, 'hello');
    await tester.pump();
    expect(tester.widget<IconButton>(_sendButton).onPressed, isNotNull);
    await tester.enterText(_field, '   ');
    await tester.pump();
    expect(tester.widget<IconButton>(_sendButton).onPressed, isNull);
  });

  testWidgets('sending shows the message and clears the box', (tester) async {
    final backend = FakeChatBackend();
    await _pump(tester, backend);

    await tester.enterText(_field, 'On my way');
    await tester.pump(); // the send button turns on in the next frame
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(backend.sentBodies, ['On my way']);
    expect(find.text('On my way'), findsOneWidget);
    expect(tester.widget<TextField>(_field).controller!.text, isEmpty);
  });

  testWidgets('a failed send keeps what was typed and says so', (tester) async {
    final backend = FakeChatBackend()..sendError = const core.NetworkError();
    await _pump(tester, backend);

    await tester.enterText(_field, 'are you there');
    await tester.pump();
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Could not send. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(_field).controller!.text, 'are you there');
  });

  testWidgets('a live message appears without any tap', (tester) async {
    final backend = FakeChatBackend();
    await _pump(tester, backend);

    backend.emit(_Fake.message(1, core.ChatSender.driver, 'I have arrived'));
    await tester.pumpAndSettle();

    expect(find.text('I have arrived'), findsOneWidget);
  });

  testWidgets('a closed chat shows the ended note and no text box',
      (tester) async {
    final backend = FakeChatBackend()
      ..fetchError = const core.AppError('closed', statusCode: 409);
    await _pump(tester, backend);

    expect(find.text('This chat has ended with the ride.'), findsOneWidget);
    expect(_field, findsNothing);
  });

  testWidgets('the chat closing while open replaces the box with the note',
      (tester) async {
    final backend = FakeChatBackend();
    await _pump(tester, backend);
    expect(_field, findsOneWidget);

    backend.emitClosed();
    await tester.pumpAndSettle();

    expect(find.text('This chat has ended with the ride.'), findsOneWidget);
    expect(_field, findsNothing);
  });

  testWidgets('a load failure offers a retry that works', (tester) async {
    final backend = FakeChatBackend(history: [
      _Fake.message(1, core.ChatSender.driver, 'hello'),
    ])
      ..fetchError = const core.NetworkError();
    await _pump(tester, backend);
    expect(find.text('Could not load the chat.'), findsOneWidget);

    backend.fetchError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('long messages wrap instead of overflowing', (tester) async {
    final backend = FakeChatBackend(history: [
      _Fake.message(1, core.ChatSender.driver, 'word ' * 90),
    ]);
    await _pump(tester, backend);

    expect(tester.takeException(), isNull);
  });

  testWidgets('works in Urdu, right to left, without overflow', (tester) async {
    final backend = FakeChatBackend(history: [
      _Fake.message(1, core.ChatSender.patient, 'میں گیٹ پر ہوں'),
      _Fake.message(2, core.ChatSender.driver, 'دو منٹ میں پہنچ رہا ہوں'),
    ]);
    await _pump(tester, backend, locale: const Locale('ur'));

    final mine = tester.getCenter(find.text('میں گیٹ پر ہوں'));
    final theirs = tester.getCenter(find.text('دو منٹ میں پہنچ رہا ہوں'));
    expect(mine.dx, lessThan(theirs.dx), reason: 'mine flips to the left');
    expect(tester.takeException(), isNull);
  });
}
