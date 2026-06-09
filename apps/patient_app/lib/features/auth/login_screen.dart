import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartride_core/smartride_core.dart';
import 'package:patient_app/core/providers.dart';
import 'package:patient_app/features/auth/auth_widgets.dart';

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
    await ref.read(authProvider.notifier).signIn(
          _phoneCtrl.text.trim(),
          _passCtrl.text,
        );
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
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    size: 16,
                    color: kAuthTeal,
                  ),
                  label: Text(
                    'Back',
                    style: GoogleFonts.dmSans(color: kAuthTeal),
                  ),
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                ),
                const SizedBox(height: kSpaceXL),
                Text(
                  'Welcome back',
                  style: GoogleFonts.dmSans(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: kSpaceXS),
                Text(
                  'Log in to your SmartRide account',
                  style: GoogleFonts.dmSans(
                    fontSize: kFontSmall,
                    color: Colors.white54,
                  ),
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
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
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
                    child: Text(
                      'Forgot password?',
                      style: GoogleFonts.dmSans(
                        color: kAuthTeal,
                        fontSize: kFontSmall,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: kSpaceXL),
                SizedBox(
                  height: kButtonHeight,
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
                        : Text(
                            'Log In',
                            style: GoogleFonts.dmSans(
                              fontSize: kFontBody,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: kSpaceLG),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.dmSans(
                        color: Colors.white54,
                        fontSize: kFontSmall,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/signup'),
                      child: Text(
                        'Sign up',
                        style: GoogleFonts.dmSans(
                          color: kAuthTeal,
                          fontSize: kFontSmall,
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
