import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartride_core/smartride_core.dart';

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: kFontSmall,
            fontWeight: FontWeight.w700,
            color: kAuthMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: kSpaceXS),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: GoogleFonts.dmSans(
            color: kAuthText,
            fontSize: kFontBody,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kAuthMuted),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: kAuthFieldBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusLG),
              borderSide: const BorderSide(color: kAuthFieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusLG),
              borderSide: const BorderSide(color: kAuthFieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusLG),
              borderSide: const BorderSide(color: kAuthTeal, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusLG),
              borderSide: const BorderSide(color: kError),
            ),
            errorStyle: const TextStyle(color: kError),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: kSpaceLG,
              vertical: kSpaceMD,
            ),
          ),
        ),
      ],
    );
  }
}
