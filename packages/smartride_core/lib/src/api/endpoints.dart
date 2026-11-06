import '../models/user.dart';
import '../models/patient.dart';
import '../models/demand.dart';
import '../models/driver.dart';
import '../models/hospital.dart';
import '../models/ride.dart';
import 'api_client.dart';

final _c = ApiClient.instance;

Future<TokenResponse> login(String phone, String password,
    {String? activeRole}) async {
  final data = await _c.post(
    '/api/v1/auth/login',
    {
      'phone': phone,
      'password': password,
      if (activeRole != null) 'active_role': activeRole,
    },
  );
  return TokenResponse.fromJson(data);
}

Future<TokenResponse> register(RegisterRequest req) async {
  final data = await _c.post('/api/v1/auth/register', req.toJson());
  return TokenResponse.fromJson(data);
}

/// POST /auth/switch-role — flip the active portal; returns a fresh token.
Future<TokenResponse> switchRole(String activeRole) async {
  final data =
      await _c.post('/api/v1/auth/switch-role', {'active_role': activeRole});
  return TokenResponse.fromJson(data);
}

/// POST /auth/add-role — "Become a driver/patient"; returns a fresh token.
Future<TokenResponse> addRole(AddRoleRequest req) async {
  final data = await _c.post('/api/v1/auth/add-role', req.toJson());
  return TokenResponse.fromJson(data);
}

/// Ends the session on the server. Pass [token] when local credentials were
/// already cleared, so the request still authenticates. Throws [AppError]; the
/// caller decides whether a failed logout matters.
Future<void> logout({String? token}) async {
  await _c.post(
    '/api/v1/auth/logout',
    {},
    headers: token == null ? null : {'Authorization': 'Bearer $token'},
  );
}

/// POST /auth/logout-all — ends every session of this account on every device.
/// Throws [AppError].
Future<void> logoutAll() async {
  await _c.post('/api/v1/auth/logout-all', {});
}

/// POST /auth/delete-account — anonymizes the signed-in account and ends every
/// session. Throws [AppError]: 403 for a wrong password, 409 while a ride is
/// still active.
Future<void> deleteAccount(String password) async {
  await _c.post('/api/v1/auth/delete-account', {'password': password});
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
  // Backend defines POST /drivers/location (not PATCH).
  await _c.post('/api/v1/drivers/location', {'lat': lat, 'lng': lng});
}

Future<DriverResponse> updateDriverMe(DriverUpdate update) async {
  final data = await _c.patch('/api/v1/drivers/me', update.toJson());
  return DriverResponse.fromJson(data);
}

/// [idempotencyKey] lets the server collapse a double submit (double tap,
/// retry after a timeout) into one ride.
Future<RideResponse> createEmergencyRide(
  EmergencyRideRequest req, {
  String? idempotencyKey,
}) async {
  final data = await _c.post(
    '/api/v1/rides/emergency',
    req.toJson(),
    headers:
        idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
  );
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
  // /detail returns nested patient/driver/hospital/triage objects.
  final data = await _c.get('/api/v1/rides/$rideId/detail');
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

Future<RideResponse> rateRide(String rideId, double rating,
    {String? comment}) async {
  final data = await _c.post('/api/v1/rides/$rideId/rate', {
    'rating': rating,
    if (comment != null && comment.isNotEmpty) 'comment': comment,
  });
  return RideResponse.fromJson(data);
}

/// [idempotencyKey] makes a retry (double tap, timeout) return the first
/// booking instead of creating a second one.
Future<RideResponse> createScheduledRide(
  ScheduledRideRequest req, {
  String? idempotencyKey,
}) async {
  final data = await _c.post(
    '/api/v1/rides/scheduled',
    req.toJson(),
    headers:
        idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
  );
  return RideResponse.fromJson(data);
}

/// Booked rides near the driver that nobody has reserved yet, soonest first.
Future<List<RideResponse>> getOpenScheduledRides() async {
  final data = await _c.get('/api/v1/rides/scheduled/open');
  return RideListResponse.fromJson(data).items;
}

/// The booked rides this driver reserved, soonest first.
Future<List<RideResponse>> getClaimedRides() async {
  final data = await _c.get('/api/v1/rides/scheduled/claimed');
  return RideListResponse.fromJson(data).items;
}

/// Reserves a booked ride. Throws [AppError] (409) if another driver got it
/// first or the driver is at the limit; the message says which.
Future<RideResponse> claimRide(String rideId) async {
  final data = await _c.post('/api/v1/rides/$rideId/claim', {});
  return RideResponse.fromJson(data);
}

/// Gives a reserved ride back. Throws [AppError] (409) when pickup is too close.
Future<RideResponse> releaseRide(String rideId) async {
  final data = await _c.post('/api/v1/rides/$rideId/release', {});
  return RideResponse.fromJson(data);
}

/// Books the same trip every day ("daily") or week ("weekly"), [occurrences]
/// times (2-12), in one request. [idempotencyKey] makes a retry return the same
/// run instead of booking it twice. Returns the rides, soonest first.
Future<List<RideResponse>> createScheduledSeries(
  ScheduledRideRequest req, {
  required String repeat,
  required int occurrences,
  String? idempotencyKey,
}) async {
  final data = await _c.post(
    '/api/v1/rides/scheduled/series',
    {...req.toJson(), 'repeat': repeat, 'occurrences': occurrences},
    headers:
        idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey},
  );
  return RideListResponse.fromJson(data).items;
}

Future<List<HospitalResponse>> getHospitals() async {
  final data = await _c.get('/api/v1/hospitals');
  final items = data['items'] as List<dynamic>? ?? [];
  return items
      .map((e) => HospitalResponse.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<Map<String, dynamic>> getDriverEarnings() async {
  return _c.get('/api/v1/drivers/earnings');
}

/// Throws [AppError] on failure so callers can retry or report it.
Future<void> registerFcmToken(String token) async {
  await _c.post('/api/v1/auth/fcm-token', {'fcm_token': token});
}

Future<Map<String, dynamic>> getDriverWallet() async {
  return _c.get('/api/v1/drivers/wallet');
}

/// Busy hours ahead for a driver (GET /drivers/demand-forecast).
Future<DemandForecast> getDemandForecast({int hoursAhead = 6}) async {
  final data = await _c.get(
    '/api/v1/drivers/demand-forecast',
    queryParams: {'hours_ahead': hoursAhead},
  );
  return DemandForecast.fromJson(data);
}
