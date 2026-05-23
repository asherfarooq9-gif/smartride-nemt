import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class PatientProfile {
  final String id;
  final String fullName;
  final String phone;
  final String? dateOfBirth;
  final String? mobilityNeeds;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  const PatientProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    this.dateOfBirth,
    this.mobilityNeeds,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> j) => PatientProfile(
    id: j['id'] as String,
    fullName: j['full_name'] as String,
    phone: j['phone'] as String,
    dateOfBirth: j['date_of_birth'] as String?,
    mobilityNeeds: j['mobility_needs'] as String?,
    emergencyContactName: j['emergency_contact_name'] as String?,
    emergencyContactPhone: j['emergency_contact_phone'] as String?,
  );
}

class ProfileNotifier extends AsyncNotifier<PatientProfile?> {
  @override
  Future<PatientProfile?> build() => _fetch();

  Future<PatientProfile?> _fetch() async {
    try {
      final data = await ApiClient.get('/api/v1/patients/me')
          as Map<String, dynamic>;
      return PatientProfile.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, PatientProfile?>(
        ProfileNotifier.new);
