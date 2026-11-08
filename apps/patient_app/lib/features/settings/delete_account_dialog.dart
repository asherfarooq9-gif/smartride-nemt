import 'package:patient_app/shared/apple_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;
import 'package:patient_app/l10n/l10n.dart';
import 'package:patient_app/core/providers.dart';

/// Asks for the password, then deletes the account. Returns true once the
/// account is gone (the session is already cleared), false or null if the user
/// backed out. A wrong password or an active ride is shown inside the dialog,
/// which stays open so they can fix it.
Future<bool?> showDeleteAccountDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _isBusy = false;
  bool _isHidden = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = context.l10n.enterPassword);
      return;
    }
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).deleteAccount(_password.text);
      if (mounted) Navigator.pop(context, true);
    } on core.AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppleAlertDialog(
      title: Text(context.l10n.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.deleteAccountBody),
            const SizedBox(height: core.kSpaceMD),
            TextField(
              controller: _password,
              obscureText: _isHidden,
              enabled: !_isBusy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.password,
                errorText: _error,
                errorMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: _isHidden
                      ? context.l10n.showPassword
                      : context.l10n.hidePassword,
                  icon: Icon(
                    _isHidden ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _isHidden = !_isHidden),
                ),
              ),
              onSubmitted: (_) => _isBusy ? null : _delete(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: _isBusy ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: core.kError),
          child: _isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.deleteAccountTitle),
        ),
      ],
    );
  }
}
