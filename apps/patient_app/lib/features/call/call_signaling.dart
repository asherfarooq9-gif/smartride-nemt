import 'package:smartride_core/smartride_core.dart' as core;

/// The call set-up channel to the server for one ride. Behind an interface so the
/// call logic can be tested with a fake.
abstract class CallSignaling {
  /// Opens the channel. [onFrame] gets everything the server and the other person
  /// send (`{type: ...}` messages and `{event: ...}` notices).
  Future<void> connect(
    String rideId, {
    required void Function(Map<String, dynamic>) onFrame,
  });

  /// False when the channel is not open, so a caller can tell nothing was sent.
  bool send(Map<String, dynamic> frame);

  Future<void> close();
}

/// The real server, over the same reconnecting WebSocket the live map uses.
class WsCallSignaling implements CallSignaling {
  core.WsClient? _ws;

  @override
  Future<void> connect(
    String rideId, {
    required void Function(Map<String, dynamic>) onFrame,
  }) async {
    final token = await core.SecureStorage.instance.readToken();
    if (token == null) return;
    final ws = core.WsClient(
      tokenProvider: core.SecureStorage.instance.readToken,
      onMessage: onFrame,
    );
    _ws = ws;
    final uri = Uri.parse(
      '${core.ApiClient.instance.wsBaseUrl}/ws/call/$rideId',
    );
    await ws.connect(uri, token);
  }

  @override
  bool send(Map<String, dynamic> frame) => _ws?.send(frame) ?? false;

  @override
  Future<void> close() async => _ws?.disconnect();
}
