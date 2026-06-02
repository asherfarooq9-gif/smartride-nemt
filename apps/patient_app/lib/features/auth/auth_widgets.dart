import 'package:flutter/material.dart';
import 'package:smartride_core/smartride_core.dart';

class DarkField extends StatelessWidget {
  const DarkField({
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: kSpaceXS),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: kFontMD),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: kDarkFieldBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMD),
              borderSide: const BorderSide(color: kDarkFieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMD),
              borderSide: const BorderSide(color: kDarkFieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMD),
              borderSide: const BorderSide(color: kAuthTeal, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kRadiusMD),
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
