import '../models/user.dart';
import '../models/patient.dart';
import '../models/driver.dart';
import '../models/ride.dart';
import 'api_client.dart';

final _c = ApiClient.instance;

Future<TokenResponse> login(String phone, String password) async {
  final data = await _c.post(
    '/api/v1/auth/login',
    {'phone': phone, 'password': password},
  );
  return TokenResponse.fromJson(data);
}

Future<TokenResponse> register(RegisterRequest req) async {
  final data = await _c.post('/api/v1/auth/register', req.toJson());
  return TokenResponse.fromJson(data);
}

Future<void> logout() async {
  try {
    await _c.post('/api/v1/auth/logout', {});
  } catch (_) {}
}

Future<PatientResponse> getPatientMe() async {
  final data = await _c.get('/api/v1/patients/me');
  return PatientResponse.fromJson(data);
}

Future<PatientResponse> updatePatientMe(PatientUpdate update) async {
  final data = await _c.patch('/api/v1/patients/me', update.toJson());
  return PatientResponse.fromJson(data);
}

Future<DriverResponse> getDriverMe() async {
  final data = await _c.get('/api/v1/drivers/me');
  return DriverResponse.fromJson(data);
}

Future<void> updateDriverStatus(DriverStatus status) async {
  await _c.patch('/api/v1/drivers/status', {'status': status.value});
}

Future<void> updateDriverLocation(double lat, double lng) async {
  await _c.patch('/api/v1/drivers/location', {'lat': lat, 'lng': lng});
}

Future<DriverResponse> updateDriverMe(DriverUpdate update) async {
  final data = await _c.patch('/api/v1/drivers/me', update.toJson());
  return DriverResponse.fromJson(data);
}

Future<RideResponse> createEmergencyRide(EmergencyRideRequest req) async {
  final data = await _c.post('/api/v1/rides/emergency', req.toJson());
  return RideResponse.fromJson(data);
}

Future<RideListResponse> getMyRides({int page = 1, int pageSize = 20}) async {
  final data = await _c.get(
    '/api/v1/rides/mine',
    queryParams: {'page': page, 'page_size': pageSize},
  );
  return RideListResponse.fromJson(data);
}

Future<List<RideResponse>> getDriverPendingRides() async {
  final data = await _c.get('/api/v1/rides/pending');
  final items = data['items'] as List<dynamic>? ?? [data];
  return items
      .map((e) => RideResponse.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<RideDetailResponse> getRideDetail(String rideId) async {
  final data = await _c.get('/api/v1/rides/$rideId');
  return RideDetailResponse.fromJson(data);
}

Future<void> updateRideStatus(
  String rideId,
  RideStatus status, {
  String? cancelReason,
}) async {
  await _c.patch('/api/v1/rides/$rideId/status', {
    'status': status.value,
    if (cancelReason != null) 'cancel_reason': cancelReason,
  });
}

Future<void> acceptRide(String rideId) async {
  await _c.post('/api/v1/rides/$rideId/accept', {});
}
