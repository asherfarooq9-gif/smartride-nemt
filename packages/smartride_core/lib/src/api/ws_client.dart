import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../diagnostics/error_reporter.dart';

/// Thrown through `onError` when every reconnect attempt has failed.
class WsRetriesExhausted implements Exception {
  const WsRetriesExhausted(this.attempts);
  final int attempts;

  @override
  String toString() => 'WsRetriesExhausted: gave up after $attempts attempts';
}

typedef WsChannelFactory = WebSocketChannel Function(Uri uri);

/// WebSocket that owns its own reconnection.
///
/// Callers create one client per screen and derive their connection state from
/// [onConnected] / [onDisconnected]. Reconnects use bounded exponential
/// backoff and stop after [maxRetries]; [onError] receives every failure,
/// including malformed frames and the final [WsRetriesExhausted].
class WsClient {
  WsClient({
    required this.onMessage,
    this.onConnected,
    this.onDisconnected,
    this.onError,
    this.maxRetries = 8,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    WsChannelFactory? channelFactory,
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final void Function(Map<String, dynamic>) onMessage;
  final void Function()? onConnected;
  final void Function()? onDisconnected;
  final void Function(Object error)? onError;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final WsChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retryTimer;
  Uri? _uri;
  String? _token;
  bool _stopped = true;
  bool _connected = false;
  int _retries = 0;
  int _generation = 0; // invalidates callbacks from superseded connections

  bool get isConnected => _connected;

  /// Opens the socket. Completes after the first attempt; later retries run in
  /// the background. Calling again restarts with a fresh retry budget.
  Future<void> connect(Uri uri, String token) async {
    _uri = uri;
    _token = token;
    _stopped = false;
    _retries = 0;
    _retryTimer?.cancel();
    await _open();
  }

  Future<void> _open() async {
    if (_stopped) return;
    await _closeChannel();
    final generation = ++_generation;
    try {
      final channel = _channelFactory(_uri!);
      _channel = channel;
      await channel.ready;
      if (_stopped || generation != _generation) {
        await channel.sink.close();
        return;
      }
      channel.sink.add(jsonEncode({'token': _token}));
      _sub = channel.stream.listen(
        _handleFrame,
        onError: (Object e) => _onLost(generation, e),
        onDone: () => _onLost(generation, null),
      );
      _connected = true;
      _retries = 0;
      onConnected?.call();
    } on Object catch (e) {
      if (generation == _generation) _onLost(generation, e);
    }
  }

  void _handleFrame(dynamic raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : null;
      if (decoded is Map<String, dynamic>) {
        onMessage(decoded);
        return;
      }
      _reportMalformed(const FormatException('Unexpected WebSocket message'));
    } on FormatException catch (e) {
      _reportMalformed(e);
    }
  }

  void _onLost(int generation, Object? error) {
    if (_stopped || generation != _generation) return;
    _generation++; // ignore the matching onDone/onError that follows
    final wasConnected = _connected;
    _connected = false;
    unawaited(_closeChannel());
    if (error != null) _reportError(error);
    if (wasConnected) onDisconnected?.call();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_retries >= maxRetries) {
      _reportError(WsRetriesExhausted(_retries));
      return;
    }
    final factor = math.pow(2, _retries).toInt();
    final delay = baseDelay * factor;
    _retries++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay > maxDelay ? maxDelay : delay, _open);
  }

  void _reportError(Object error) => onError?.call(error);

  void _reportMalformed(FormatException error) {
    ErrorReporter.report('WebSocket sent a malformed message', error);
    onError?.call(error);
  }

  /// Sends a JSON message. Returns false when the socket is not connected or
  /// the write failed, so callers can tell a dead socket from a delivered one.
  bool send(Map<String, dynamic> data) {
    final channel = _channel;
    if (!_connected || channel == null) return false;
    try {
      channel.sink.add(jsonEncode(data));
      return true;
    } on StateError {
      return false;
    }
  }

  /// Stops reconnecting and closes the socket. No callbacks fire afterwards.
  Future<void> disconnect() async {
    _stopped = true;
    _connected = false;
    _generation++;
    _retryTimer?.cancel();
    await _closeChannel();
  }

  Future<void> _closeChannel() async {
    final sub = _sub;
    final channel = _channel;
    _sub = null;
    _channel = null;
    await sub?.cancel();
    try {
      await channel?.sink.close();
    } on Object catch (e) {
      ErrorReporter.report('WebSocket close failed', e);
    }
  }
}
