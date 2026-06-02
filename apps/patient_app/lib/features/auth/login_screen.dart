import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartride_core/smartride_core.dart';
import '../../core/providers.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).signIn(_phoneCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.hasError) {
      final err = auth.error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err is AppError ? err.message : 'Login failed'),
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
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: kSpaceXS),
                const Text(
                  'Log in to your SmartRide account',
                  style: TextStyle(fontSize: kFontSM, color: Colors.white54),
                ),
                const SizedBox(height: kSpaceXXL),
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
                  hint: 'Your password',
                  obscureText: _obscure,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                  validator: Validators.password,
                ),
                const SizedBox(height: kSpaceMD),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: kAuthTeal, fontSize: kFontSM),
                    ),
                  ),
                ),
                const SizedBox(height: kSpaceXL),
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
                            'Log In',
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
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.white54, fontSize: kFontSM),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/signup'),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: kAuthTeal,
                          fontSize: kFontSM,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

