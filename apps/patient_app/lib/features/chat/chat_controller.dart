import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/features/chat/chat_backend.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// The longest message the server accepts.
const kMaxChatMessageLength = 500;

enum ChatStatus {
  /// Reading the history.
  loading,

  /// Talking is possible.
  open,

  /// The ride is over (or no driver has it): nobody can write any more.
  closed,

  /// The history could not be read; try again.
  failed,
}

enum ChatSendError { tooLong, failed }

class ChatState {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.loading,
    this.isSending = false,
    this.sendError,
  });

  final List<core.RideMessage> messages;
  final ChatStatus status;
  final bool isSending;
  final ChatSendError? sendError;

  ChatState copyWith({
    List<core.RideMessage>? messages,
    ChatStatus? status,
    bool? isSending,
    ChatSendError? sendError,
    bool clearSendError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        status: status ?? this.status,
        isSending: isSending ?? this.isSending,
        sendError: clearSendError ? null : (sendError ?? this.sendError),
      );
}

/// One ride's chat: the history, live messages, and sending.
class ChatController extends StateNotifier<ChatState> {
  ChatController(this._backend, this.rideId) : super(const ChatState()) {
    unawaited(_start());
  }

  final ChatBackend _backend;
  final String rideId;
  CloseChat? _closeLive;
  bool _isDisposed = false;

  // 409 means the chat is closed; 403/404 mean this ride is not ours to read.
  static bool _isClosed(Object error) =>
      error is core.AppError &&
      (error.statusCode == 409 ||
          error.statusCode == 403 ||
          error.statusCode == 404);

  Future<void> retry() => _start();

  Future<void> _start() async {
    state = state.copyWith(status: ChatStatus.loading);
    try {
      final history = await _backend.fetch(rideId);
      if (_isDisposed) return;
      state = state.copyWith(
          messages: _merge(const [], history), status: ChatStatus.open);
    } on core.AppError catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        status: _isClosed(e) ? ChatStatus.closed : ChatStatus.failed,
      );
      return;
    }
    final closeLive = await _backend.connect(
      rideId,
      onMessage: _add,
      onClosed: _close,
      onConnected: () => unawaited(_catchUp()),
    );
    if (_isDisposed) {
      await closeLive();
      return;
    }
    _closeLive = closeLive;
  }

  /// Messages that arrived while the live channel was down.
  Future<void> _catchUp() async {
    if (state.status != ChatStatus.open) return;
    final lastId = state.messages.isEmpty ? null : state.messages.last.id;
    try {
      final missed = await _backend.fetch(rideId, afterId: lastId);
      if (!_isDisposed) _addAll(missed);
    } on core.AppError catch (e) {
      if (_isClosed(e)) _close();
      // Any other failure: the live channel or the next reconnect catches up.
    }
  }

  void _add(core.RideMessage message) => _addAll([message]);

  void _addAll(List<core.RideMessage> incoming) {
    if (_isDisposed || incoming.isEmpty) return;
    state = state.copyWith(messages: _merge(state.messages, incoming));
  }

  /// Existing plus new, each id once, oldest first.
  static List<core.RideMessage> _merge(
    List<core.RideMessage> existing,
    List<core.RideMessage> incoming,
  ) {
    final byId = {for (final m in existing) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    return byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  void _close() {
    if (_isDisposed) return;
    state = state.copyWith(status: ChatStatus.closed, isSending: false);
    final closeLive = _closeLive;
    _closeLive = null;
    if (closeLive != null) unawaited(closeLive());
  }

  /// Sends [text]. False when nothing was sent (empty, too long, or it failed);
  /// [ChatState.sendError] says why when the person needs to know.
  Future<bool> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || state.isSending || state.status != ChatStatus.open) {
      return false;
    }
    if (body.length > kMaxChatMessageLength) {
      state = state.copyWith(sendError: ChatSendError.tooLong);
      return false;
    }
    state = state.copyWith(isSending: true, clearSendError: true);
    try {
      final saved = await _backend.send(rideId, body);
      if (_isDisposed) return true;
      state = state.copyWith(
        messages: _merge(state.messages, [saved]),
        isSending: false,
      );
      return true;
    } on core.AppError catch (e) {
      if (_isDisposed) return false;
      if (_isClosed(e)) {
        _close();
      } else {
        state =
            state.copyWith(isSending: false, sendError: ChatSendError.failed);
      }
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    final closeLive = _closeLive;
    _closeLive = null;
    if (closeLive != null) unawaited(closeLive());
    super.dispose();
  }
}

final chatControllerProvider =
    StateNotifierProvider.autoDispose.family<ChatController, ChatState, String>(
  (ref, rideId) => ChatController(ref.watch(chatBackendProvider), rideId),
);
