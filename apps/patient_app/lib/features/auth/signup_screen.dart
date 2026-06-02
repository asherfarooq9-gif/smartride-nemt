import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import '../../core/providers.dart';
import 'auth_widgets.dart';

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
      case _RoleChoice.patient: return ['patient'];
      case _RoleChoice.driver:  return ['driver'];
      case _RoleChoice.both:    return ['patient', 'driver'];
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final roles = _roles;
    await ref.read(authProvider.notifier).registerAccount(RegisterRequest(
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text,
      fullName: _nameCtrl.text.trim(),
      roles: roles,
      activeRole: roles.contains('patient') ? 'patient' : 'driver',
      licenseNo: _needsDriverFields ? _licenseCtrl.text.trim() : null,
      vehiclePlate: _needsDriverFields ? _plateCtrl.text.trim() : null,
      vehicleType: _needsDriverFields ? _vehicleTypeCtrl.text.trim() : null,
    ));
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.hasError) {
      final err = auth.error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err is AppError ? err.message : 'Sign up failed'),
        backgroundColor: kError,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider) is AsyncLoading;

    return Scaffold(
      backgroundColor: kAuthDarkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: kSpaceXL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kSpaceLG),
                TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios, size: 16, color: kAuthTeal),
                  label: const Text('Back', style: TextStyle(color: kAuthTeal)),
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                ),
                const SizedBox(height: kSpaceXL),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: kSpaceXXL),
                DarkField(
                  controller: _nameCtrl,
                  label: 'FULL NAME',
                  hint: 'Your full name',
                  validator: (v) => Validators.required(v, field: 'Full name'),
                ),
                const SizedBox(height: kSpaceLG),
                DarkField(
                  controller: _phoneCtrl,
                  label: 'PHONE NUMBER',
                  hint: '+92 3XX XXX XXXX',
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: kSpaceLG),
                DarkField(
                  controller: _passCtrl,
                  label: 'PASSWORD',
                  hint: 'Min. 8 characters',
                  obscureText: _obscure,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: kSpaceLG),
                DarkField(
                  controller: _confirmCtrl,
                  label: 'CONFIRM PASSWORD',
                  hint: 'Repeat password',
                  obscureText: _obscure,
                  validator: (v) =>
                      v != _passCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: kSpaceXL),
                const Text(
                  'I AM A...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: kSpaceMD),
                _RoleSelector(
                  selected: _choice,
                  onChanged: (c) => setState(() => _choice = c),
                ),
                if (_needsDriverFields) ...[
                  const SizedBox(height: kSpaceXL),
                  const Text(
                    'DRIVER DETAILS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white38,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: kSpaceMD),
                  DarkField(
                    controller: _licenseCtrl,
                    label: 'LICENSE NUMBER',
                    hint: 'e.g. LHR-DL-12345',
                    validator: (v) => _needsDriverFields
                        ? Validators.required(v, field: 'License number')
                        : null,
                  ),
                  const SizedBox(height: kSpaceLG),
                  DarkField(
                    controller: _plateCtrl,
                    label: 'VEHICLE PLATE',
                    hint: 'e.g. ABC-123',
                    validator: (v) => _needsDriverFields
                        ? Validators.required(v, field: 'Vehicle plate')
                        : null,
                  ),
                  const SizedBox(height: kSpaceLG),
                  DarkField(
                    controller: _vehicleTypeCtrl,
                    label: 'VEHICLE TYPE',
                    hint: 'e.g. Sedan, Ambulette, Van',
                    validator: (v) => _needsDriverFields
                        ? Validators.required(v, field: 'Vehicle type')
                        : null,
                  ),
                ],
                const SizedBox(height: kSpaceXXL),
                SizedBox(
                  height: kMinTapTarget,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAuthTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusLG),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: kFontMD,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: kSpaceLG),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: Colors.white54, fontSize: kFontSM),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: kAuthTeal,
                          fontSize: kFontSM,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kSpaceXXL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.selected, required this.onChanged});

  final _RoleChoice selected;
  final ValueChanged<_RoleChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RoleCard(
          value: _RoleChoice.patient,
          selected: selected,
          icon: Icons.personal_injury_outlined,
          title: 'Patient',
          subtitle: 'Receive rides',
          onTap: () => onChanged(_RoleChoice.patient),
        ),
        const SizedBox(height: kSpaceSM),
        _RoleCard(
          value: _RoleChoice.driver,
          selected: selected,
          icon: Icons.add_circle_outline,
          title: 'Driver',
          subtitle: 'Give rides',
          onTap: () => onChanged(_RoleChoice.driver),
        ),
        const SizedBox(height: kSpaceSM),
        _RoleCard(
          value: _RoleChoice.both,
          selected: selected,
          icon: Icons.people_outline,
          title: 'Both',
          subtitle: 'Both portals',
          onTap: () => onChanged(_RoleChoice.both),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.value,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final _RoleChoice value;
  final _RoleChoice selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: kSpaceLG,
          vertical: kSpaceMD,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? kAuthTeal.withValues(alpha: 0.15)
              : kDarkFieldBg,
          borderRadius: BorderRadius.circular(kRadiusMD),
          border: Border.all(
            color: isSelected ? kAuthTeal : kDarkFieldBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? kAuthTeal : Colors.white38, size: 22),
            const SizedBox(width: kSpaceLG),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: kFontMD,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: kFontXS,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: kAuthTeal, size: 20),
          ],
        ),
      ),
    );
  }
}
