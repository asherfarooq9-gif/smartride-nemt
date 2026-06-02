import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import '../../core/providers.dart';

/// "Become a Driver" / "Become a Patient" — adds a role to the current account.
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppError ? e.message : 'Could not add role'),
          backgroundColor: kError,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isDriver ? 'Become a Driver' : 'Become a Patient')),
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
                      ? 'Add a driver profile to start accepting rides.'
                      : 'Add a patient profile to request rides.',
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
                    decoration: const InputDecoration(
                      labelText: 'License number',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (v) =>
                        Validators.required(v, field: 'License number'),
                  ),
                  const SizedBox(height: kSpaceLG),
                  TextFormField(
                    controller: _plateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle plate',
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                    validator: (v) =>
                        Validators.required(v, field: 'Vehicle plate'),
                  ),
                  const SizedBox(height: kSpaceLG),
                  TextFormField(
                    controller: _vehicleTypeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle type (e.g. Sedan, Ambulette)',
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                    validator: (v) =>
                        Validators.required(v, field: 'Vehicle type'),
                  ),
                  const SizedBox(height: kSpaceXXL),
                ],
                PrimaryButton(
                  label: _isDriver ? 'Become a Driver' : 'Become a Patient',
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
