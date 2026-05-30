class Validators {
  Validators._();

  static final RegExp _phoneRe = RegExp(r'^\+?[0-9]{10,15}$');

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    if (!_phoneRe.hasMatch(value.trim())) {
      return 'Enter a valid phone number (10-15 digits)';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? symptomText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please describe your symptoms';
    }
    if (value.length > 2000) {
      return 'Symptom description must be under 2000 characters';
    }
    return null;
  }
}
