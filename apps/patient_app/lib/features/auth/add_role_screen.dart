import 'package:patient_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';

/// context.l10n.becomeDriver / context.l10n.becomePatient — adds a role to the current account.
class AddRoleScreen extends ConsumerStatefulWidget {
  const AddRoleScreen({super.key, required this.role});

  /// 'driver' or 'patient'
  final String role;

  @override
  ConsumerState<AddRoleScreen> createState() => _AddRoleScreenState();
}

class _AddRoleScreenState extends ConsumerState<AddRoleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _vehicleTypeCtrl = TextEditingController();
  bool _busy = false;

  bool get _isDriver => widget.role == 'driver';

  @override
  void dispose() {
    _licenseCtrl.dispose();
    _plateCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).addRole(
            AddRoleRequest(
              role: widget.role,
              licenseNo: _isDriver ? _licenseCtrl.text.trim() : null,
              vehiclePlate: _isDriver ? _plateCtrl.text.trim() : null,
              vehicleType: _isDriver ? _vehicleTypeCtrl.text.trim() : null,
            ),
          );
      if (!mounted) return;
      context.go(_isDriver ? '/driver' : '/');
    } on AppError catch (e) {
      _showError(e.message);
    } on Exception catch (e, st) {
      ErrorReporter.report('Adding a role failed', e, st);
      _showError(context.l10n.couldNotAddRole);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kError),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isDriver
              ? context.l10n.becomeDriver
              : context.l10n.becomePatient)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kSpaceLG),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(_isDriver ? Icons.drive_eta : Icons.medical_services,
                    size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: kSpaceLG),
                Text(
                  _isDriver
                      ? context.l10n.addDriverProfile
                      : context.l10n.addPatientProfile,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: kTextSecondary),
                ),
                const SizedBox(height: kSpaceXXL),
                if (_isDriver) ...[
                  TextFormField(
                    controller: _licenseCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.licenseField,
                      prefixIcon: const Icon(Icons.badge),
                    ),
                    validator: (v) =>
                        Validators.required(v, field: 'License number'),
                  ),
                  const SizedBox(height: kSpaceLG),
                  TextFormField(
                    controller: _plateCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.plateField,
                      prefixIcon: const Icon(Icons.confirmation_number),
                    ),
                    validator: (v) =>
                        Validators.required(v, field: 'Vehicle plate'),
                  ),
                  const SizedBox(height: kSpaceLG),
                  TextFormField(
                    controller: _vehicleTypeCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.vehicleTypeExample,
                      prefixIcon: const Icon(Icons.directions_car),
                    ),
                    validator: (v) =>
                        Validators.required(v, field: 'Vehicle type'),
                  ),
                  const SizedBox(height: kSpaceXXL),
                ],
                PrimaryButton(
                  label: _isDriver
                      ? context.l10n.becomeDriver
                      : context.l10n.becomePatient,
                  onPressed: _busy ? null : _submit,
                  isLoading: _busy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
