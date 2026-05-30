class HospitalResponse {
  const HospitalResponse({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.phone,
    this.specialties = const [],
    this.edCapacity,
    this.currentLoad,
  });

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? phone;
  final List<String> specialties;
  final int? edCapacity;
  final int? currentLoad;

  double? get loadFraction =>
      (edCapacity != null && edCapacity! > 0 && currentLoad != null)
          ? currentLoad! / edCapacity!
          : null;

  factory HospitalResponse.fromJson(Map<String, dynamic> json) =>
      HospitalResponse(
        id: json['id'].toString(),
        name: json['name'] as String,
        address: json['address'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        phone: json['phone'] as String?,
        specialties: (json['specialties'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        edCapacity: (json['ed_capacity'] as num?)?.toInt(),
        currentLoad: (json['current_load'] as num?)?.toInt(),
      );
}
