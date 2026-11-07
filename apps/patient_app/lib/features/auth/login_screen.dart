import 'package:patient_app/l10n/l10n.dart';
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
        content: Text(err is AppError ? err.message : context.l10n.loginFailed),
        backgroundColor: kError,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider) is AsyncLoading;

    return Scaffold(
      backgroundColor: kAuthLightBg,
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
                    color: kAuthAccent,
                  ),
                  label: Text(
                    context.l10n.back,
                    style: GoogleFonts.dmSans(color: kAuthAccent),
                  ),
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                ),
                const SizedBox(height: kSpaceXL),
                Text(
                  context.l10n.welcomeBack,
                  style: GoogleFonts.dmSans(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kAuthText,
                  ),
                ),
                const SizedBox(height: kSpaceXS),
                Text(
                  context.l10n.loginSubtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: kFontSmall,
                    color: kAuthMuted,
                  ),
                ),
                const SizedBox(height: kSpaceXXL),
                AuthField(
                  controller: _phoneCtrl,
                  label: context.l10n.phoneNumberLabel,
                  hint: '+92 3XX XXX XXXX',
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: kSpaceLG),
                AuthField(
                  controller: _passCtrl,
                  label: context.l10n.passwordLabel,
                  hint: context.l10n.passwordHint,
                  obscureText: _obscure,
                  suffixIcon: IconButton(
                    tooltip: _obscure
                        ? context.l10n.showPassword
                        : context.l10n.hidePassword,
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: kAuthMuted,
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
                    // No self-service reset endpoint exists yet — direct the
                    // user to support instead of a button that does nothing.
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.l10n.resetPasswordTitle),
                        content: Text(context.l10n.resetPasswordBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(context.l10n.ok),
                          ),
                        ],
                      ),
                    ),
                    child: Text(
                      context.l10n.forgotPassword,
                      style: GoogleFonts.dmSans(
                        color: kAuthAccent,
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
                      backgroundColor: kAuthAccent,
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
                            context.l10n.logIn,
                            style: GoogleFonts.dmSans(
                              fontSize: kFontBody,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: kSpaceLG),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.noAccountPrefix,
                      style: GoogleFonts.dmSans(
                        color: kAuthMuted,
                        fontSize: kFontSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
                      ),
                      child: Text(
                        context.l10n.signUp,
                        style: GoogleFonts.dmSans(
                          color: kAuthAccent,
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
