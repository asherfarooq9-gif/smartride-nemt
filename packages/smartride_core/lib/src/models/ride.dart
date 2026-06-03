enum RideStatus {
  pending,
  driverAssigned,
  driverEnRoute,
  patientPickedUp,
  arrivedAtHospital,
  completed,
  cancelled,
}

extension RideStatusX on RideStatus {
  String get value {
    switch (this) {
      case RideStatus.pending:
        return 'pending';
      case RideStatus.driverAssigned:
        return 'driver_assigned';
      case RideStatus.driverEnRoute:
        return 'driver_en_route';
      case RideStatus.patientPickedUp:
        return 'patient_picked_up';
      case RideStatus.arrivedAtHospital:
        return 'arrived_at_hospital';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayLabel {
    switch (this) {
      case RideStatus.pending:
        return 'Finding Driver';
      case RideStatus.driverAssigned:
        return 'Driver Assigned';
      case RideStatus.driverEnRoute:
        return 'Driver En Route';
      case RideStatus.patientPickedUp:
        return 'Patient Picked Up';
      case RideStatus.arrivedAtHospital:
        return 'Arrived at Hospital';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
    }
  }

  static RideStatus fromString(String s) {
    switch (s) {
      case 'pending':
        return RideStatus.pending;
      case 'driver_assigned':
        return RideStatus.driverAssigned;
      case 'driver_en_route':
        return RideStatus.driverEnRoute;
      case 'patient_picked_up':
        return RideStatus.patientPickedUp;
      case 'arrived_at_hospital':
        return RideStatus.arrivedAtHospital;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
        return RideStatus.cancelled;
      default:
        return RideStatus.pending;
    }
  }
}

enum RideType { emergency, scheduled }

extension RideTypeX on RideType {
  String get value => this == RideType.emergency ? 'emergency' : 'scheduled';

  static RideType fromString(String s) =>
      s == 'emergency' ? RideType.emergency : RideType.scheduled;
}

class RideResponse {
  const RideResponse({
    required this.id,
    required this.status,
    required this.rideType,
    required this.pickupAddress,
    this.patientId,
    this.driverId,
    this.hospitalId,
    this.pickupLat,
    this.pickupLng,
    this.scheduledAt,
    this.createdAt,
    this.cancelReason,
    this.symptomText,
  });

  final String id;
  final RideStatus status;
  final RideType rideType;
  final String pickupAddress;
  final String? patientId;
  final String? driverId;
  final String? hospitalId;
  final double? pickupLat;
  final double? pickupLng;
  final String? scheduledAt;
  final String? createdAt;
  final String? cancelReason;
  final String? symptomText;

  bool get isActive =>
      status != RideStatus.completed && status != RideStatus.cancelled;

  bool get isTrackable =>
      status == RideStatus.driverAssigned ||
      status == RideStatus.driverEnRoute ||
      status == RideStatus.patientPickedUp;

  factory RideResponse.fromJson(Map<String, dynamic> json) => RideResponse(
        id: json['id'].toString(),
        status: RideStatusX.fromString(json['status'] as String? ?? ''),
        rideType: RideTypeX.fromString(json['ride_type'] as String? ?? ''),
        pickupAddress: json['pickup_address'] as String? ?? '',
        patientId: json['patient_id']?.toString(),
        driverId: json['driver_id']?.toString(),
        hospitalId: json['hospital_id']?.toString(),
        pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
        pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
        scheduledAt: (json['scheduled_for'] ?? json['scheduled_at']) as String?,
        createdAt: (json['requested_at'] ?? json['created_at']) as String?,
        cancelReason: json['cancel_reason'] as String?,
        symptomText: json['symptom_text'] as String?,
      );
}

class RideDetailResponse extends RideResponse {
  const RideDetailResponse({
    required super.id,
    required super.status,
    required super.rideType,
    required super.pickupAddress,
    super.patientId,
    super.driverId,
    super.hospitalId,
    super.pickupLat,
    super.pickupLng,
    super.scheduledAt,
    super.createdAt,
    super.cancelReason,
    super.symptomText,
    this.patient,
    this.driver,
    this.hospital,
    this.triage,
  });

  final Map<String, dynamic>? patient;
  final Map<String, dynamic>? driver;
  final Map<String, dynamic>? hospital;
  final Map<String, dynamic>? triage;

  factory RideDetailResponse.fromJson(Map<String, dynamic> json) {
    final base = RideResponse.fromJson(json);
    return RideDetailResponse(
      id: base.id,
      status: base.status,
      rideType: base.rideType,
      pickupAddress: base.pickupAddress,
      patientId: base.patientId,
      driverId: base.driverId,
      hospitalId: base.hospitalId,
      pickupLat: base.pickupLat,
      pickupLng: base.pickupLng,
      scheduledAt: base.scheduledAt,
      createdAt: base.createdAt,
      cancelReason: base.cancelReason,
      symptomText: base.symptomText,
      patient: json['patient'] as Map<String, dynamic>?,
      driver: json['driver'] as Map<String, dynamic>?,
      hospital: json['hospital'] as Map<String, dynamic>?,
      triage: json['triage'] as Map<String, dynamic>?,
    );
  }
}

class RideListResponse {
  const RideListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<RideResponse> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  factory RideListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return RideListResponse(
      items: rawItems
          .map((e) => RideResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? rawItems.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? rawItems.length,
    );
  }
}

class ScheduledRideRequest {
  const ScheduledRideRequest({
    required this.pickupAddress,
    required this.scheduledFor,
    this.pickupLat,
    this.pickupLng,
    this.hospitalId,
  });

  final String pickupAddress;
  final DateTime scheduledFor;
  final double? pickupLat;
  final double? pickupLng;
  final String? hospitalId;

  Map<String, dynamic> toJson() => {
        'pickup_address': pickupAddress,
        'scheduled_for': scheduledFor.toUtc().toIso8601String(),
        if (pickupLat != null) 'pickup_lat': pickupLat,
        if (pickupLng != null) 'pickup_lng': pickupLng,
      };
}

class EmergencyRideRequest {
  const EmergencyRideRequest({
    required this.pickupAddress,
    required this.symptomText,
    this.pickupLat,
    this.pickupLng,
  });

  final String pickupAddress;
  final String symptomText;
  final double? pickupLat;
  final double? pickupLng;

  Map<String, dynamic> toJson() => {
        'pickup_address': pickupAddress,
        'symptom_text': symptomText,
        if (pickupLat != null) 'pickup_lat': pickupLat,
        if (pickupLng != null) 'pickup_lng': pickupLng,
      };
}
