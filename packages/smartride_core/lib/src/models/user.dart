class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.tokenType,
    required this.role,
    required this.userId,
  });

  final String accessToken;
  final String tokenType;
  final String role;
  final String userId;

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
        role: json['role'] as String,
        userId: json['user_id'].toString(),
      );
}

class RegisterRequest {
  const RegisterRequest({
    required this.phone,
    required this.password,
    required this.role,
    this.fullName,
  });

  final String phone;
  final String password;
  final String role;
  final String? fullName;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'password': password,
        'role': role,
        if (fullName != null) 'full_name': fullName,
      };
}
