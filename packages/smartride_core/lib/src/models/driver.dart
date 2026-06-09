enum DriverStatus { available, busy, offline }

extension DriverStatusX on DriverStatus {
  String get value {
    switch (this) {
      case DriverStatus.available:
        return 'available';
      case DriverStatus.busy:
        return 'busy';
      case DriverStatus.offline:
        return 'offline';
    }
  }

  static DriverStatus fromString(String s) {
    switch (s) {
      case 'available':
        return DriverStatus.available;
      case 'busy':
        return DriverStatus.busy;
      default:
        return DriverStatus.offline;
    }
  }
}

class DriverResponse {
  const DriverResponse({
    required this.id,
    required this.phone,
    required this.status,
    this.fullName,
    this.licenseNumber,
    this.vehicleModel,
    this.vehiclePlate,
    this.currentLat,
    this.currentLng,
    this.totalRides = 0,
    this.rating,
    this.isVerified = false,
    this.walletBalancePkr = 0.0,
  });

  final String id;
  final String phone;
  final DriverStatus status;
  final String? fullName;
  final String? licenseNumber;
  final String? vehicleModel;
  final String? vehiclePlate;
  final double? currentLat;
  final double? currentLng;
  final int totalRides;
  final double? rating;
  final bool isVerified;
  final double walletBalancePkr;

  bool get isOnline => status != DriverStatus.offline;
  bool get isLowBalance => walletBalancePkr < 500;

  factory DriverResponse.fromJson(Map<String, dynamic> json) => DriverResponse(
        id: json['id'].toString(),
        phone: json['phone'] as String,
        status: DriverStatusX.fromString(json['status'] as String? ?? ''),
        fullName: json['full_name'] as String?,
        licenseNumber: (json['license_no'] ?? json['license_number']) as String?,
        vehicleModel: (json['vehicle_type'] ?? json['vehicle_model']) as String?,
        vehiclePlate: json['vehicle_plate'] as String?,
        currentLat: (json['current_lat'] as num?)?.toDouble(),
        currentLng: (json['current_lng'] as num?)?.toDouble(),
        totalRides: (json['total_rides'] as num?)?.toInt() ?? 0,
        rating: (json['rating'] as num?)?.toDouble(),
        isVerified: json['is_verified'] as bool? ?? false,
        walletBalancePkr: (json['wallet_balance_pkr'] as num?)?.toDouble() ?? 0.0,
      );
}

class DriverUpdate {
  const DriverUpdate({
    this.fullName,
    this.licenseNumber,
    this.vehicleModel,
    this.vehiclePlate,
  });

  final String? fullName;
  final String? licenseNumber;
  final String? vehicleModel;
  final String? vehiclePlate;

  Map<String, dynamic> toJson() => {
        // Backend DriverUpdate accepts only full_name and vehicle_type.
        if (fullName != null) 'full_name': fullName,
        if (vehicleModel != null) 'vehicle_type': vehicleModel,
      };
}

class LocationUpdate {
  const LocationUpdate({required this.lat, required this.lng});

  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}
