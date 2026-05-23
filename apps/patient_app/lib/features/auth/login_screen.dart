import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authNotifierProvider.notifier)
        .login(_phoneCtrl.text, _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error.toString()
                  .replaceFirst('ApiException(', '')
                  .replaceAll(')', ''),
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.local_taxi, size: 56, color: Colors.white),
            const SizedBox(height: 12),
            const Text(
              'SmartRide',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const Text(
              'Patient Portal',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D1B3E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your registered phone number',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 28),
                      AppTextField(
                        label: 'Phone Number',
                        hint: '+92300000000',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final trimmed = v?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Phone number is required';
                          if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(trimmed)) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Password',
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        prefixIcon: Icons.lock_outline,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        suffix: GestureDetector(
                          onTap: () => setState(() => _obscurePass = !_obscurePass),
                          child: Icon(
                            _obscurePass
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      AppButton(
                        label: 'Sign In',
                        onPressed: _submit,
                        loading: isLoading,
                        icon: Icons.login,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
