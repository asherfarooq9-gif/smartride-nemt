import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/features/chat/chat_backend.dart';
import 'package:patient_app/features/chat/chat_controller.dart';
import 'package:smartride_core/smartride_core.dart' as core;

import 'fake_chat_backend.dart';

typedef _Fake = FakeChatBackend;

ProviderContainer _container(FakeChatBackend backend) {
  final container = ProviderContainer(
    overrides: [chatBackendProvider.overrideWithValue(backend)],
  );
  addTearDown(container.dispose);
  return container;
}

ChatState _state(ProviderContainer c) =>
    c.read(chatControllerProvider('ride-1'));

ChatController _controller(ProviderContainer c) =>
    c.read(chatControllerProvider('ride-1').notifier);

/// Opens the chat and lets the first load finish.
Future<ChatState> _open(ProviderContainer container) async {
  container.listen(chatControllerProvider('ride-1'), (_, __) {});
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return _state(container);
}

void main() {
  test('loads the history and opens the live channel', () async {
    final backend = FakeChatBackend(history: [
      _Fake.message(1, core.ChatSender.patient, 'hello'),
      _Fake.message(2, core.ChatSender.driver, 'on my way'),
    ]);
    final container = _container(backend);

    final state = await _open(container);

    expect(state.status, ChatStatus.open);
    expect(state.messages.map((m) => m.body), ['hello', 'on my way']);
    expect(backend.connectCalls, 1);
  });

  test('a closed chat shows as closed and opens no live channel', () async {
    final backend = FakeChatBackend()
      ..fetchError = const core.AppError('closed', statusCode: 409);
    final container = _container(backend);

    final state = await _open(container);

    expect(state.status, ChatStatus.closed);
    expect(backend.connectCalls, 0);
  });

  test('a network failure on load is a failure, not a closed chat', () async {
    final backend = FakeChatBackend()..fetchError = const core.NetworkError();
    final container = _container(backend);

    final state = await _open(container);

    expect(state.status, ChatStatus.failed);
  });

  test('a live message is added once, in order', () async {
    final backend = FakeChatBackend(history: [
      _Fake.message(1, core.ChatSender.patient, 'hello'),
    ]);
    final container = _container(backend);
    await _open(container);

    final reply = _Fake.message(2, core.ChatSender.driver, 'hi');
    backend.emit(reply);
    backend.emit(reply); // delivered twice: shown once

    expect(_state(container).messages.map((m) => m.id), [1, 2]);
  });

  test('sending trims the text and adds the message once', () async {
    final backend = FakeChatBackend();
    final container = _container(backend);
    await _open(container);

    final ok = await _controller(container).send('  I am at the gate  ');

    expect(ok, isTrue);
    expect(backend.sentBodies, ['I am at the gate']);
    expect(_state(container).messages.map((m) => m.body), ['I am at the gate']);
    // the server also echoes it over the live channel
    backend.emit(_state(container).messages.single);
    expect(_state(container).messages, hasLength(1));
    expect(_state(container).isSending, isFalse);
  });

  test('empty and whitespace-only text is never sent', () async {
    final backend = FakeChatBackend();
    final container = _container(backend);
    await _open(container);

    expect(await _controller(container).send(''), isFalse);
    expect(await _controller(container).send('  \n '), isFalse);

    expect(backend.sentBodies, isEmpty);
  });

  test('text over 500 characters is not sent and says why', () async {
    final backend = FakeChatBackend();
    final container = _container(backend);
    await _open(container);

    final ok = await _controller(container).send('x' * 501);

    expect(ok, isFalse);
    expect(backend.sentBodies, isEmpty);
    expect(_state(container).sendError, ChatSendError.tooLong);
  });

  test('a failed send keeps everything and reports it', () async {
    final backend = FakeChatBackend(history: [
      _Fake.message(1, core.ChatSender.driver, 'hello'),
    ]);
    final container = _container(backend);
    await _open(container);
    backend.sendError = const core.NetworkError();

    final ok = await _controller(container).send('are you there');

    expect(ok, isFalse);
    expect(_state(container).sendError, ChatSendError.failed);
    expect(_state(container).messages, hasLength(1));
    expect(_state(container).isSending, isFalse);
    expect(_state(container).status, ChatStatus.open);
  });

  test('sending to a chat that has closed closes the screen', () async {
    final backend = FakeChatBackend();
    final container = _container(backend);
    await _open(container);
    backend.sendError = const core.AppError('closed', statusCode: 409);

    await _controller(container).send('too late');

    expect(_state(container).status, ChatStatus.closed);
  });

  test('the server saying chat_closed closes it and drops the socket',
      () async {
    final backend = FakeChatBackend();
    final container = _container(backend);
    await _open(container);

    backend.emitClosed();
    await Future<void>.delayed(Duration.zero);

    expect(_state(container).status, ChatStatus.closed);
    expect(backend.closeCalls, 1);
  });

  test('after a reconnect it fetches what it missed', () async {
    final backend = FakeChatBackend(history: [
      _Fake.message(1, core.ChatSender.patient, 'hello'),
    ]);
    final container = _container(backend);
    await _open(container);
    backend.history.add(_Fake.message(2, core.ChatSender.driver, 'missed'));

    backend.emitConnected();
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(_state(container).messages.map((m) => m.body), ['hello', 'missed']);
    expect(backend.fetchAfterIds.last, 1);
  });

  test('leaving the screen closes the live channel', () async {
    final backend = FakeChatBackend();
    final container = _container(backend);
    await _open(container);

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(backend.closeCalls, 1);
  });
}
