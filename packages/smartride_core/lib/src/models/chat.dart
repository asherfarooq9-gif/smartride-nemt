/// Which side of a ride sent a chat message.
enum ChatSender { patient, driver }

/// One message in a ride's chat. The server deletes them when the ride ends.
class RideMessage {
  const RideMessage({
    required this.id,
    required this.rideId,
    required this.sender,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String rideId;
  final ChatSender sender;
  final String body;
  final DateTime createdAt;

  factory RideMessage.fromJson(Map<String, dynamic> json) {
    final sender = switch (json['sender']) {
      'patient' => ChatSender.patient,
      'driver' => ChatSender.driver,
      final other => throw FormatException('Unknown chat sender: $other'),
    };
    return RideMessage(
      id: (json['id'] as num).toInt(),
      rideId: json['ride_id'].toString(),
      sender: sender,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // The server numbers messages, so the id alone identifies one.
  @override
  bool operator ==(Object other) => other is RideMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
