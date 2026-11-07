import 'package:patient_app/l10n/l10n.dart';
import 'package:smartride_core/smartride_core.dart' as core;

/// The words for a ride's status, in the language the user chose.
String rideStatusLabel(AppLocalizations l, core.RideStatus status) =>
    switch (status) {
      core.RideStatus.pending => l.statusFinding,
      core.RideStatus.driverAssigned => l.statusAssigned,
      core.RideStatus.driverEnRoute => l.statusEnRoute,
      core.RideStatus.patientPickedUp => l.statusPickedUp,
      core.RideStatus.arrivedAtHospital => l.statusArrived,
      core.RideStatus.completed => l.statusCompleted,
      core.RideStatus.cancelled => l.statusCancelled,
    };
