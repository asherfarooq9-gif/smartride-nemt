class PatientResponse {
  const PatientResponse({
    required this.id,
    required this.phone,
    this.fullName,
    this.dateOfBirth,
    this.mobilityNeeds,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.createdAt,
    this.totalRides = 0,
  });

  final String id;
  final String phone;
  final String? fullName;
  final String? dateOfBirth;
  final String? mobilityNeeds;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? createdAt;
  final int totalRides;

  factory PatientResponse.fromJson(Map<String, dynamic> json) =>
      PatientResponse(
        id: json['id'].toString(),
        phone: json['phone'] as String,
        fullName: json['full_name'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        mobilityNeeds: json['mobility_needs'] as String?,
        emergencyContactName: json['emergency_contact_name'] as String?,
        emergencyContactPhone: json['emergency_contact_phone'] as String?,
        createdAt: json['created_at'] as String?,
        totalRides: (json['total_rides'] as num?)?.toInt() ?? 0,
      );

  PatientResponse copyWith({
    String? fullName,
    String? dateOfBirth,
    String? mobilityNeeds,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) =>
      PatientResponse(
        id: id,
        phone: phone,
        fullName: fullName ?? this.fullName,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        mobilityNeeds: mobilityNeeds ?? this.mobilityNeeds,
        emergencyContactName: emergencyContactName ?? this.emergencyContactName,
        emergencyContactPhone:
            emergencyContactPhone ?? this.emergencyContactPhone,
        createdAt: createdAt,
        totalRides: totalRides,
      );
}

class PatientUpdate {
  const PatientUpdate({
    this.fullName,
    this.dateOfBirth,
    this.mobilityNeeds,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String? fullName;
  final String? dateOfBirth;
  final String? mobilityNeeds;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  Map<String, dynamic> toJson() => {
        if (fullName != null) 'full_name': fullName,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (mobilityNeeds != null) 'mobility_needs': mobilityNeeds,
        if (emergencyContactName != null)
          'emergency_contact_name': emergencyContactName,
        if (emergencyContactPhone != null)
          'emergency_contact_phone': emergencyContactPhone,
      };
}
