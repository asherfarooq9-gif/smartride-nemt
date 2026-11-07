class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.tokenType,
    required this.roles,
    required this.activeRole,
    required this.userId,
  });

  final String accessToken;
  final String tokenType;
  final List<String> roles;
  final String activeRole;
  final String userId;

  /// Legacy alias — the active role.
  String get role => activeRole;

  bool get hasPatient => roles.contains('patient');
  bool get hasDriver => roles.contains('driver');
  bool get hasBoth => hasPatient && hasDriver;

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final roles = rawRoles is List
        ? rawRoles.map((e) => e.toString()).toList()
        : <String>[if (json['role'] != null) json['role'].toString()];
    final active = (json['active_role'] ?? json['role'] ?? (roles.isNotEmpty ? roles.first : '')).toString();
    return TokenResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      roles: roles,
      activeRole: active,
      userId: json['user_id'].toString(),
    );
  }
}

class RegisterRequest {
  const RegisterRequest({
    required this.phone,
    required this.password,
    required this.roles,
    this.fullName,
    this.activeRole,
    this.licenseNo,
    this.vehiclePlate,
    this.vehicleType,
  });

  final String phone;
  final String password;
  final List<String> roles;
  final String? fullName;
  final String? activeRole;
  // driver-only fields
  final String? licenseNo;
  final String? vehiclePlate;
  final String? vehicleType;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'password': password,
        'roles': roles,
        if (activeRole != null) 'active_role': activeRole,
        if (fullName != null) 'full_name': fullName,
        if (licenseNo != null) 'license_no': licenseNo,
        if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
        if (vehicleType != null) 'vehicle_type': vehicleType,
      };
}

/// Body for POST /auth/add-role ("Become a driver/patient").
class AddRoleRequest {
  const AddRoleRequest({
    required this.role,
    this.licenseNo,
    this.vehiclePlate,
    this.vehicleType,
  });

  final String role;
  final String? licenseNo;
  final String? vehiclePlate;
  final String? vehicleType;

  Map<String, dynamic> toJson() => {
        'role': role,
        if (licenseNo != null) 'license_no': licenseNo,
        if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
        if (vehicleType != null) 'vehicle_type': vehicleType,
      };
}
