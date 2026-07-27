/// Typed message contracts for the two WebSocket endpoints
/// (/ws/driver/{ride_id} and /ws/ride/{ride_id}).
///
/// Mirrored on the backend in backend/app/schemas/ws_messages.py — keep both
/// in sync when this file changes; there is no shared codegen between the
/// two.
library;

/// Reply to a valid location update sent by the driver app.
class DriverLocationAck {
  const DriverLocationAck({required this.lat, required this.lng});

  final double lat;
  final double lng;

  static DriverLocationAck? tryParse(Map<String, dynamic> json) {
    if (json['ack'] != true) return null;
    final lat = json['lat'];
    final lng = json['lng'];
    if (lat is! num || lng is! num) return null;
    return DriverLocationAck(lat: lat.toDouble(), lng: lng.toDouble());
  }
}

/// Sent by either endpoint when the driver/server rejects a frame
/// (bad coordinates, malformed JSON, rate limited, etc).
class WsErrorMessage {
  const WsErrorMessage(this.error);

  final String error;

  static WsErrorMessage? tryParse(Map<String, dynamic> json) {
    final error = json['error'];
    return error is String ? WsErrorMessage(error) : null;
  }
}

/// Live driver position, forwarded to patient/admin watchers.
class LocationBroadcast {
  const LocationBroadcast({required this.lat, required this.lng});

  final double lat;
  final double lng;

  /// Only matches a bare `{lat, lng}` frame — not an ack (`ack: true`) or
  /// any other message shape that happens to carry those keys.
  static LocationBroadcast? tryParse(Map<String, dynamic> json) {
    if (json.containsKey('ack') || json.containsKey('event')) return null;
    final lat = json['lat'];
    final lng = json['lng'];
    if (lat is! num || lng is! num) return null;
    return LocationBroadcast(lat: lat.toDouble(), lng: lng.toDouble());
  }
}

/// Sent once on /ws/ride/{ride_id} when the ride terminates; the server
/// closes the connection right after.
class RideEndedMessage {
  const RideEndedMessage(this.status);

  final String status;

  static RideEndedMessage? tryParse(Map<String, dynamic> json) {
    if (json['event'] != 'ride_ended') return null;
    final status = json['status'];
    return status is String ? RideEndedMessage(status) : null;
  }
}
