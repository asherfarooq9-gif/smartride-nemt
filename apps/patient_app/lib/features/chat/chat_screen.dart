import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patient_app/features/chat/chat_controller.dart';
import 'package:patient_app/l10n/l10n.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// The in-ride chat between the patient and their driver, styled like iMessage:
/// your messages on the right in blue, theirs on the left in grey. Messages are
/// deleted by the server when the ride ends, and the screen says so.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.rideId, required this.me});

  final String rideId;

  /// Which side the person using this screen is on.
  final core.ChatSender me;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _hasText => _text.text.trim().isNotEmpty;

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final typed = _text.text;
    final sent = await ref
        .read(chatControllerProvider(widget.rideId).notifier)
        .send(typed);
    if (!mounted || !sent) return;
    HapticFeedback.selectionClick();
    // Keep anything typed while the message was on its way.
    if (_text.text == typed) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = chatControllerProvider(widget.rideId);
    final state = ref.watch(provider);

    ref.listen(provider, (previous, next) {
      if (next.messages.length != previous?.messages.length) _scrollToEnd();
      final error = next.sendError;
      if (error != null && error != previous?.sendError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error == ChatSendError.tooLong
                  ? l10n.chatTooLong
                  : l10n.chatSendFailed,
            ),
          ),
        );
      }
    });

    final other = widget.me == core.ChatSender.patient
        ? l10n.roleDriver
        : l10n.rolePatient;

    return Scaffold(
      appBar: AppBar(title: Text(other)),
      body: switch (state.status) {
        ChatStatus.loading =>
          const Center(child: CupertinoActivityIndicator(radius: 14)),
        ChatStatus.failed => core.ErrorState(
            message: l10n.chatLoadFailed,
            onRetry: () => ref.read(provider.notifier).retry(),
          ),
        ChatStatus.open || ChatStatus.closed => Column(
            children: [
              Expanded(child: _messages(context, state)),
              if (state.status == ChatStatus.closed)
                _EndedNote(text: l10n.chatEnded)
              else
                _inputBar(context, state),
            ],
          ),
      },
    );
  }

  Widget _messages(BuildContext context, ChatState state) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final hint =
        scheme.brightness == Brightness.dark ? core.kDarkText3 : core.kText400;
    final note = Padding(
      padding: const EdgeInsets.symmetric(vertical: core.kSpaceMD),
      child: Text(
        l10n.chatPrivacyNote,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: hint),
      ),
    );
    if (state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.chatEmpty,
              style: TextStyle(
                fontSize: core.kFontBody,
                color: scheme.onSurfaceVariant,
              ),
            ),
            note,
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(
        horizontal: core.kSpaceLG,
        vertical: core.kSpaceSM,
      ),
      itemCount: state.messages.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return note;
        final message = state.messages[i - 1];
        return _Bubble(message: message, isMine: message.sender == widget.me);
      },
    );
  }

  Widget _inputBar(BuildContext context, ChatState state) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final canSend = _hasText && !state.isSending;
    OutlineInputBorder pill() => OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            core.kSpaceMD,
            core.kSpaceSM,
            core.kSpaceSM,
            core.kSpaceSM,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: kMaxChatMessageLength,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  // The limit is enforced by the field; a counter would only nag.
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      null,
                  decoration: InputDecoration(
                    hintText: l10n.chatHint,
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: core.kSpaceLG,
                      vertical: core.kSpaceMD,
                    ),
                    border: pill(),
                    enabledBorder: pill(),
                    focusedBorder: pill(),
                  ),
                ),
              ),
              const SizedBox(width: core.kSpaceSM),
              IconButton.filled(
                key: const ValueKey('chat-send'),
                tooltip: l10n.chatSend,
                onPressed: canSend ? _send : null,
                icon: state.isSending
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One message. Mine hugs the end edge in blue, theirs the start edge in grey,
/// so the sides flip correctly in right-to-left Urdu.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final core.RideMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isMine ? scheme.primary : scheme.surfaceContainerHighest;
    final foreground = isMine ? Colors.white : scheme.onSurface;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(message.createdAt.toLocal()),
    );
    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  message.body,
                  style: TextStyle(
                    fontSize: core.kFontBody,
                    height: 1.3,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: foreground.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the text box once the ride is over.
class _EndedNote extends StatelessWidget {
  const _EndedNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(core.kSpaceLG),
        color: scheme.surfaceContainerHighest,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: core.kSpaceSM),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
