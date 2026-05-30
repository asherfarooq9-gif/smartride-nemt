import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsClient {
  WsClient({
    required this.onMessage,
    this.onError,
    this.onDone,
  });

  final void Function(Map<String, dynamic>) onMessage;
  final void Function(Object)? onError;
  final VoidCallback? onDone;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Uri? _uri;
  String? _token;
  bool _disposed = false;
  int _backoffSeconds = 1;
  Timer? _reconnectTimer;

  Future<void> connect(Uri uri, String token) async {
    _uri = uri;
    _token = token;
    _disposed = false;
    _backoffSeconds = 1;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(_uri!);
      await _channel!.ready;
      send({'token': _token!});
      _sub = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );
      _backoffSeconds = 1;
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          onMessage(decoded);
        }
      } catch (_) {}
    }
  }

  void _handleError(Object e) {
    onError?.call(e);
    _scheduleReconnect();
  }

  void _handleDone() {
    onDone?.call();
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _backoffSeconds), () {
      if (!_disposed) _doConnect();
    });
    _backoffSeconds = (_backoffSeconds * 2).clamp(1, 32);
  }

  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
  }
}

typedef VoidCallback = void Function();
