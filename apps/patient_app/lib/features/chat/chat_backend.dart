import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// A live chat channel; close it when the screen goes away.
abstract class ChatConnection {
  Future<void> close();
}

/// Everything the chat screen needs from the server, behind one small door so
/// tests can play the server.
abstract class ChatBackend {
  Future<List<core.RideMessage>> fetch(String rideId, {int? afterId});

  Future<core.RideMessage> send(String rideId, String body);

  /// Opens the live channel. [onMessage] gets each new message, [onClosed] fires
  /// when the server says the chat is over, and [onConnected] fires every time
  /// the socket (re)opens so the caller can fetch anything it missed.
  Future<ChatConnection> connect(
    String rideId, {
    required void Function(core.RideMessage) onMessage,
    required void Function() onClosed,
    required void Function() onConnected,
  });
}

/// The real server: REST for history and sending, a WebSocket for live messages.
class ApiChatBackend implements ChatBackend {
  const ApiChatBackend();

  @override
  Future<List<core.RideMessage>> fetch(String rideId, {int? afterId}) =>
      core.getRideMessages(rideId, afterId: afterId);

  @override
  Future<core.RideMessage> send(String rideId, String body) =>
      core.sendRideMessage(rideId, body);

  @override
  Future<ChatConnection> connect(
    String rideId, {
    required void Function(core.RideMessage) onMessage,
    required void Function() onClosed,
    required void Function() onConnected,
  }) async {
    final ws = core.WsClient(
      tokenProvider: core.SecureStorage.instance.readToken,
      onConnected: onConnected,
      onMessage: (frame) {
        if (frame['event'] == 'chat_closed') {
          onClosed();
        } else if (frame.containsKey('body') && frame.containsKey('id')) {
          try {
            onMessage(core.RideMessage.fromJson(frame));
          } on FormatException {
            // A frame we cannot read is skipped; the next fetch brings it back.
          }
        }
        // Anything else (the server's ping) needs no action.
      },
    );
    final token = await core.SecureStorage.instance.readToken();
    if (token != null) {
      final uri = Uri.parse(
        '${core.ApiClient.instance.wsBaseUrl}/ws/chat/$rideId',
      );
      await ws.connect(uri, token);
    }
    return _WsConnection(ws);
  }
}

class _WsConnection implements ChatConnection {
  _WsConnection(this._ws);
  final core.WsClient _ws;

  @override
  Future<void> close() => _ws.disconnect();
}

final chatBackendProvider = Provider<ChatBackend>(
  (ref) => const ApiChatBackend(),
);
