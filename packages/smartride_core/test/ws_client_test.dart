import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _FakeSink implements WebSocketSink {
  _FakeSink(this._socket);
  final _FakeSocket _socket;

  @override
  void add(dynamic data) {
    if (_socket.closed) throw StateError('closed');
    _socket.sent.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.forEach(add);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _socket.closed = true;
  }

  @override
  Future<void> get done => Future<void>.value();
}

class _FakeSocket extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeSocket({this.openError});

  final Object? openError;
  final incoming = StreamController<dynamic>();
  final sent = <dynamic>[];
  bool closed = false;

  @override
  Future<void> get ready =>
      openError == null ? Future<void>.value() : Future<void>.error(openError!);

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  WebSocketSink get sink => _FakeSink(this);

  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
}

class _Harness {
  _Harness({this.failOpens = 0, int maxRetries = 3}) {
    client = WsClient(
      onMessage: messages.add,
      onConnected: () => events.add('connected'),
      onDisconnected: () => events.add('disconnected'),
      onError: errors.add,
      maxRetries: maxRetries,
      baseDelay: const Duration(milliseconds: 2),
      maxDelay: const Duration(milliseconds: 8),
      channelFactory: (_) {
        final socket =
            _FakeSocket(openError: sockets.length < failOpens ? 'refused' : null);
        sockets.add(socket);
        return socket;
      },
    );
  }

  final int failOpens;
  late final WsClient client;
  final sockets = <_FakeSocket>[];
  final messages = <Map<String, dynamic>>[];
  final events = <String>[];
  final errors = <Object>[];

  Future<void> start() => client.connect(Uri.parse('ws://test/ws'), 'tok');
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 120));

void main() {
  test('connects, authenticates with the token and reports connected', () async {
    final h = _Harness();
    await h.start();

    expect(h.client.isConnected, isTrue);
    expect(h.events, ['connected']);
    expect(jsonDecode(h.sockets.single.sent.single as String), {'token': 'tok'});
    await h.client.disconnect();
  });

  test('decodes JSON messages and reports malformed ones without dropping',
      () async {
    final h = _Harness();
    await h.start();

    h.sockets.single.incoming
      ..add('{"lat": 1.5, "lng": 2.5}')
      ..add('not json')
      ..add('[1, 2]');
    await settle();

    expect(h.messages, [
      {'lat': 1.5, 'lng': 2.5},
    ]);
    expect(h.errors, hasLength(2));
    expect(h.errors, everyElement(isA<FormatException>()));
    expect(h.client.isConnected, isTrue);
    await h.client.disconnect();
  });

  test('a dropped connection reconnects exactly once and closes the old socket',
      () async {
    final h = _Harness();
    await h.start();

    await h.sockets.single.incoming.close();
    await settle();

    expect(h.sockets, hasLength(2));
    expect(h.sockets.first.closed, isTrue);
    expect(h.events, ['connected', 'disconnected', 'connected']);
    expect(h.client.isConnected, isTrue);
    await h.client.disconnect();
  });

  test('an error followed by done still schedules a single reconnect',
      () async {
    final h = _Harness();
    await h.start();

    h.sockets.single.incoming.addError('boom');
    await h.sockets.single.incoming.close();
    await settle();

    expect(h.sockets, hasLength(2));
    expect(h.errors, contains('boom'));
    expect(h.events.where((e) => e == 'disconnected'), hasLength(1));
    await h.client.disconnect();
  });

  test('connect failures reach onError and stop after the retry limit',
      () async {
    final h = _Harness(failOpens: 100, maxRetries: 3);
    await h.start();
    await settle();

    expect(h.sockets, hasLength(4)); // first try + 3 retries
    expect(h.client.isConnected, isFalse);
    expect(h.events, isEmpty);
    expect(h.errors.whereType<String>(), hasLength(4));
    expect(h.errors.last, isA<WsRetriesExhausted>());
    await h.client.disconnect();
  });

  test('recovers after transient failures and resets the retry budget',
      () async {
    final h = _Harness(failOpens: 2, maxRetries: 3);
    await h.start();
    await settle();

    expect(h.events, ['connected']);
    expect(h.client.isConnected, isTrue);
    await h.client.disconnect();
  });

  test('send reports whether the message could be written', () async {
    final h = _Harness();
    expect(h.client.send({'a': 1}), isFalse); // never connected

    await h.start();
    expect(h.client.send({'lat': 1}), isTrue);

    await h.sockets.single.incoming.close();
    await Future<void>.delayed(Duration.zero);
    expect(h.client.send({'lat': 2}), isFalse); // dropped, not yet reconnected
    await h.client.disconnect();
  });

  test('disconnect stops reconnecting and fires no further callbacks',
      () async {
    final h = _Harness();
    await h.start();
    await h.client.disconnect();
    final eventsAtDisconnect = List.of(h.events);

    await h.sockets.single.incoming.close();
    await settle();

    expect(h.sockets, hasLength(1));
    expect(h.events, eventsAtDisconnect);
    expect(h.client.isConnected, isFalse);
  });
}
