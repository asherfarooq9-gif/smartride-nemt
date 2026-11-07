import 'package:smartride_core/smartride_core.dart' as core;

/// True when the server says over the driver's GPS socket that the ride has ended
/// (the patient or an admin cancelled it, or it was completed elsewhere).
bool isRideEndedMessage(Map<String, dynamic> message) =>
    message['event'] == 'ride_ended';

/// A finished ride: nothing more to do and nothing to stream to.
bool rideHasEnded(core.RideStatus status) =>
    status == core.RideStatus.completed || status == core.RideStatus.cancelled;

/// The ride is no longer this driver's to drive: it ended, or it went back to the
/// queue (a cancel before pickup, or the server taking it back).
bool rideLeftThisDriver(core.RideStatus status) =>
    rideHasEnded(status) || status == core.RideStatus.pending;
