// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get profile => 'Profile';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get language => 'Language';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get support => 'Support';

  @override
  String get helpAndFaq => 'Help & FAQ';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get about => 'About';

  @override
  String get appVersion => 'App Version';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signOutEverywhere => 'Sign out of all devices';

  @override
  String get signOutEverywhereBody =>
      'This signs you out on every phone where you are logged in.';

  @override
  String get signOutEverywhereFailed =>
      'Could not sign out of all devices. Check your connection and try again.';

  @override
  String get offlineBanner => 'No connection. Trying again…';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get cancel => 'Cancel';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get earnings => 'Earnings';

  @override
  String get demandForecast => 'Demand Forecast';

  @override
  String get wallet => 'Wallet';

  @override
  String get rideHistory => 'Ride History';

  @override
  String get openRides => 'Open rides';

  @override
  String get myRides => 'My rides';

  @override
  String get reserveThisRide => 'Reserve this ride';

  @override
  String get giveBack => 'Give back';

  @override
  String get noOpenRidesTitle => 'No open rides nearby';

  @override
  String get noOpenRidesBody =>
      'Booked trips near you show up here. Reserve one to plan your day.';

  @override
  String get noReservedTitle => 'No reserved rides';

  @override
  String get noReservedBody => 'Rides you reserve show up here.';

  @override
  String get couldNotLoadRides => 'Could not load rides';

  @override
  String get checkConnectionPullDown =>
      'Check your connection and pull down to try again.';

  @override
  String get reservedMessage =>
      'Reserved. It becomes yours 30 minutes before pickup.';

  @override
  String get givenBackMessage => 'Given back.';

  @override
  String get timeToBeConfirmed => 'Time to be confirmed';

  @override
  String get bookARide => 'Book a Ride';

  @override
  String get scheduleInAdvance => 'Schedule a medical trip in advance';

  @override
  String get locationsLabel => 'LOCATIONS';

  @override
  String get useCurrentLocation => 'Use my current location';

  @override
  String get typePickupAddress => 'Type your pickup address...';

  @override
  String get destinationLabel => 'DESTINATION';

  @override
  String get selectHospital => 'Select destination hospital';

  @override
  String get specialtyLabel => 'SPECIALTY / DEPARTMENT (OPTIONAL)';

  @override
  String get whenLabel => 'WHEN';

  @override
  String get selectDateTime => 'Select date & time';

  @override
  String get confirmBooking => 'Confirm Booking';

  @override
  String get chooseDateTime => 'Please choose a date and time';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountBody =>
      'Your name, phone number, health details, emergency contact and ride pickup addresses are removed, and you are signed out everywhere. This cannot be undone.\n\nRide and payment records are kept without your details, so drivers’ earnings and statistics stay correct.';

  @override
  String get password => 'Password';

  @override
  String get enterPassword => 'Enter your password to continue.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get repeatLabel => 'REPEAT';

  @override
  String get noRepeat => 'Does not repeat';

  @override
  String get repeatDaily => 'Every day';

  @override
  String get repeatWeekly => 'Every week';

  @override
  String get numberOfTrips => 'Number of trips';

  @override
  String lastTripOn(String date) {
    return 'Last trip: $date';
  }

  @override
  String tripsBooked(int count) {
    return '$count trips booked';
  }

  @override
  String get payByLabel => 'Pays by';

  @override
  String get paymentSectionTitle => 'How you take payment';

  @override
  String get paymentSectionHint =>
      'Patients see this once you are assigned. SmartRide does not handle the money.';

  @override
  String get paymentNotSet => 'Not set yet';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentEasypaisa => 'Easypaisa';

  @override
  String get paymentJazzcash => 'JazzCash';

  @override
  String get paymentBank => 'Bank transfer';
}
