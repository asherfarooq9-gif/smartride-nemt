import 'package:patient_app/features/chat/chat_backend.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// A chat server in memory: keeps the messages, lets a test play the live
/// channel (a message arriving, the chat closing, the socket reconnecting).
class FakeChatBackend implements ChatBackend {
  FakeChatBackend({List<core.RideMessage>? history}) : history = [...?history];

  final List<core.RideMessage> history;
  Object? fetchError;
  Object? sendError;
  final List<String> sentBodies = [];
  int connectCalls = 0;
  int closeCalls = 0;
  final List<int?> fetchAfterIds = [];

  void Function(core.RideMessage)? _onMessage;
  void Function()? _onClosed;
  void Function()? _onConnected;

  static core.RideMessage message(
    int id,
    core.ChatSender sender,
    String body, {
    String rideId = 'ride-1',
  }) =>
      core.RideMessage(
        id: id,
        rideId: rideId,
        sender: sender,
        body: body,
        createdAt: DateTime.utc(2026, 11, 8, 10, id),
      );

  /// A message arriving over the live channel.
  void emit(core.RideMessage m) {
    history.add(m);
    _onMessage?.call(m);
  }

  void emitClosed() => _onClosed?.call();
  void emitConnected() => _onConnected?.call();

  @override
  Future<List<core.RideMessage>> fetch(String rideId, {int? afterId}) async {
    fetchAfterIds.add(afterId);
    final error = fetchError;
    if (error != null) throw error;
    return [
      for (final m in history)
        if (afterId == null || m.id > afterId) m,
    ];
  }

  @override
  Future<core.RideMessage> send(String rideId, String body) async {
    final error = sendError;
    if (error != null) throw error;
    sentBodies.add(body);
    final saved = message(
      history.length + 1,
      core.ChatSender.patient,
      body,
      rideId: rideId,
    );
    history.add(saved);
    return saved;
  }

  @override
  Future<CloseChat> connect(
    String rideId, {
    required void Function(core.RideMessage) onMessage,
    required void Function() onClosed,
    required void Function() onConnected,
  }) async {
    connectCalls++;
    _onMessage = onMessage;
    _onClosed = onClosed;
    _onConnected = onConnected;
    return () async {
      closeCalls++;
    };
  }
}
