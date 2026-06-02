import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import '../../core/providers.dart';

enum _RoleChoice { patient, driver, both }

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _vehicleTypeCtrl = TextEditingController();

  _RoleChoice _choice = _RoleChoice.patient;
  bool _obscure = true;

  bool get _needsDriverFields =>
      _choice == _RoleChoice.driver || _choice == _RoleChoice.both;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _licenseCtrl.dispose();
    _plateCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    super.dispose();
  }

  List<String> get _roles {
    switch (_choice) {
      case _RoleChoice.patient:
        return ['patient'];
      case _RoleChoice.driver:
        return ['driver'];
      case _RoleChoice.both:
        return ['patient', 'driver'];
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final roles = _roles;
    final req = RegisterRequest(
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text,
      fullName: _nameCtrl.text.trim(),
      roles: roles,
      // both → default to the patient portal first
      activeRole: roles.contains('patient') ? 'patient' : 'driver',
      licenseNo: _needsDriverFields ? _licenseCtrl.text.trim() : null,
      vehiclePlate: _needsDriverFields ? _plateCtrl.text.trim() : null,
      vehicleType: _needsDriverFields ? _vehicleTypeCtrl.text.trim() : null,
    );

    await ref.read(authProvider.notifier).registerAccount(req);
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.hasError) {
      final err = auth.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err is AppError ? err.message : 'Sign up failed'),
          backgroundColor: kError,
        ),
      );
    }
    // On success the router redirect sends the user into their portal.
  }

  String? _confirmValidator(String? v) {
    if (v != _passCtrl.text) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider) is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kSpaceLG),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      Validators.required(v, field: 'Full name'),
                ),
                const SizedBox(height: kSpaceLG),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: Validators.phone,
                ),
                const SizedBox(height: kSpaceLG),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: kSpaceLG),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: _confirmValidator,
                ),
                const SizedBox(height: kSpaceXL),
                Text('I want to use SmartRide as a:',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: kSpaceXS),
                SegmentedButton<_RoleChoice>(
                  segments: const [
                    ButtonSegment(
                        value: _RoleChoice.patient,
                        label: Text('Patient'),
                        icon: Icon(Icons.medical_services)),
                    ButtonSegment(
                        value: _RoleChoice.driver,
                        label: Text('Driver'),
                        icon: Icon(Icons.drive_eta)),
                    ButtonSegment(
                        value: _RoleChoice.both,
                        label: Text('Both'),
                        icon: Icon(Icons.swap_horiz)),
                  ],
                  selected: {_choice},
                  onSelectionChanged: (s) =>
                      setState(() => _choice = s.first),
                ),
                if (_needsDriverFields) ...[
                  const SizedBox(height: kSpaceXL),
                  Text('Driver details',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: kSpaceSM),
                  TextFormField(
                    controller: _licenseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'License number',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (v) => _needsDriverFields
                        ? Validators.required(v, field: 'License number')
                        : null,
                  ),
                  const SizedBox(height: kSpaceLG),
                  TextFormField(
                    controller: _plateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle plate',
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                    validator: (v) => _needsDriverFields
                        ? Validators.required(v, field: 'Vehicle plate')
                        : null,
                  ),
                  const SizedBox(height: kSpaceLG),
                  TextFormField(
                    controller: _vehicleTypeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle type (e.g. Sedan, Ambulette)',
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                    validator: (v) => _needsDriverFields
                        ? Validators.required(v, field: 'Vehicle type')
                        : null,
                  ),
                ],
                const SizedBox(height: kSpaceXXL),
                PrimaryButton(
                  label: 'Create account',
                  onPressed: isLoading ? null : _submit,
                  isLoading: isLoading,
                ),
                const SizedBox(height: kSpaceLG),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Log In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
