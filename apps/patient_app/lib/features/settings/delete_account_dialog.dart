import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartride_core/smartride_core.dart' as core;
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
      setState(() => _error = 'Enter your password to continue.');
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
    return AlertDialog(
      title: const Text('Delete account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your name, phone number, health details, emergency contact and '
              'ride pickup addresses are removed, and you are signed out '
              'everywhere. This cannot be undone.\n\n'
              'Ride and payment records are kept without your details, so '
              'drivers’ earnings and statistics stay correct.',
            ),
            const SizedBox(height: core.kSpaceMD),
            TextField(
              controller: _password,
              obscureText: _isHidden,
              enabled: !_isBusy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _error,
                errorMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: _isHidden ? 'Show password' : 'Hide password',
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
          child: const Text('Cancel'),
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
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
