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
  String get fareLabel => 'Fare';

  @override
  String get fareHint =>
      'Pay your driver directly. SmartRide does not take payment in the app.';

  @override
  String get rateDriverAction => 'Rate your driver';

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

  @override
  String get brandTagline => 'Medical transport, always nearby.';

  @override
  String get cityBadge => 'Islamabad · Rawalpindi';

  @override
  String get getStarted => 'Get started';

  @override
  String get getStartedSub =>
      'Trusted medical transport for you and your family.';

  @override
  String get signUpFree => 'Sign Up — It\'s Free';

  @override
  String get logIn => 'Log In';

  @override
  String get emergencyCallPrefix => 'In an emergency, call ';

  @override
  String get back => 'Back';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get loginSubtitle => 'Log in to your SmartRide account';

  @override
  String get phoneNumberLabel => 'PHONE NUMBER';

  @override
  String get passwordLabel => 'PASSWORD';

  @override
  String get passwordHint => 'Your password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordBody =>
      'Password reset is handled by our support team. Please reach us through Help & Support, or call 1122 for ride emergencies.';

  @override
  String get ok => 'OK';

  @override
  String get noAccountPrefix => 'Don\'t have an account? ';

  @override
  String get signUp => 'Sign up';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get signupFailed => 'Sign up failed';

  @override
  String get createAccount => 'Create Account';

  @override
  String get fullNameLabel => 'FULL NAME';

  @override
  String get fullNameHint => 'Your full name';

  @override
  String get passwordMinHint => 'Min. 8 characters';

  @override
  String get confirmPasswordLabel => 'CONFIRM PASSWORD';

  @override
  String get repeatPasswordHint => 'Repeat password';

  @override
  String get passwordsMismatch => 'Passwords do not match';

  @override
  String get iAmA => 'I AM A...';

  @override
  String get driverDetails => 'DRIVER DETAILS';

  @override
  String get licenseLabel => 'LICENSE NUMBER';

  @override
  String get plateLabel => 'VEHICLE PLATE';

  @override
  String get vehicleTypeLabel => 'VEHICLE TYPE';

  @override
  String get haveAccountPrefix => 'Already have an account? ';

  @override
  String get logInLink => 'Log in';

  @override
  String get rolePatient => 'Patient';

  @override
  String get rolePatientSub => 'Book and receive medical rides';

  @override
  String get roleDriver => 'Driver';

  @override
  String get roleDriverSub => 'Drive patients to appointments';

  @override
  String get roleBoth => 'Both';

  @override
  String get roleBothSub => 'Access both patient and driver portals';

  @override
  String get navHome => 'Home';

  @override
  String get navMyRides => 'My Rides';

  @override
  String get navProfile => 'Profile';

  @override
  String get requestEmergencyRide => 'Request emergency ride';

  @override
  String get emergencyCaps => 'EMERGENCY';

  @override
  String get dragToResize => 'Drag to resize';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get staySafe => 'Stay safe. We\'re here for you.';

  @override
  String get activeRide => 'Active Ride';

  @override
  String get bookRideSub => 'Schedule a non-emergency trip';

  @override
  String get recentRides => 'Recent Rides';

  @override
  String get viewTrips => 'View your trips';

  @override
  String get favorites => 'Favorites';

  @override
  String get savedLocations => 'Saved locations';

  @override
  String get safetyTips => 'Safety Tips';

  @override
  String get stayInformed => 'Stay informed';

  @override
  String get couldntLoadRides => 'Couldn\'t load your rides';

  @override
  String get tryAgain => 'Try again';

  @override
  String get noRidesYet => 'No rides yet';

  @override
  String get yourRecentRides => 'Your recent rides';

  @override
  String get openMenu => 'Open menu';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get tapForHelp => 'Tap for immediate help';

  @override
  String get doubleTapHelp => 'Double tap to get immediate help';

  @override
  String get myProfile => 'My Profile';

  @override
  String get edit => 'Edit';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get updateFailed => 'Update failed';

  @override
  String get failedLoadProfile => 'Failed to load profile';

  @override
  String get personalInfo => 'Personal Information';

  @override
  String get fullNameTitle => 'Full Name';

  @override
  String get phoneTitle => 'Phone';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get mobilityNeeds => 'Mobility Needs';

  @override
  String get mobilityNeedsOptional => 'Mobility Needs (optional)';

  @override
  String get emergencyContact => 'Emergency Contact';

  @override
  String get nameTitle => 'Name';

  @override
  String get quickLinks => 'Quick Links';

  @override
  String get savedPlaces => 'Saved Places';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get rideDetails => 'Ride Details';

  @override
  String get pickupTitle => 'Pickup';

  @override
  String get symptomsTitle => 'Symptoms';

  @override
  String get requestedTitle => 'Requested';

  @override
  String get trackLive => 'Track Live';

  @override
  String get cancelRide => 'Cancel Ride';

  @override
  String get keepRide => 'Keep Ride';

  @override
  String get reasonOptional => 'Reason (optional)';

  @override
  String get rideCancelled => 'Ride cancelled';

  @override
  String get couldNotCancel => 'Could not cancel the ride. Please try again.';

  @override
  String get failedLoadRide => 'Failed to load ride';

  @override
  String get rateYourDriverTitle => 'Rate Your Driver';

  @override
  String get howWasRide => 'How was your ride?';

  @override
  String get anyComments => 'Any comments? (optional)';

  @override
  String get submitRating => 'Submit Rating';

  @override
  String get skip => 'Skip';

  @override
  String get thankYou => 'Thank you!';

  @override
  String get feedbackHelps => 'Your feedback helps us improve the service.';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get ratingTerrible => 'Terrible';

  @override
  String get ratingPoor => 'Poor';

  @override
  String get ratingOkay => 'Okay';

  @override
  String get ratingGood => 'Good';

  @override
  String get ratingExcellent => 'Excellent';

  @override
  String get couldNotSubmitRating =>
      'Could not submit your rating. Please try again.';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotificationsYet => 'No notifications yet';

  @override
  String get loadingRides => 'Loading rides...';

  @override
  String get failedToLoad => 'Failed to load';

  @override
  String get noRidesYetDot => 'No rides yet.';

  @override
  String get drvAccountLoading => 'Loading your account';

  @override
  String get drvAccountFailed => 'Your account could not be loaded';

  @override
  String get drvLockUnverified => 'Available once your account is verified';

  @override
  String get drvCheckingStatus => 'Checking your status';

  @override
  String get drvStatusUnavailable => 'Status unavailable';

  @override
  String get drvOnline => 'You\'re Online';

  @override
  String get drvOffline => 'You\'re Offline';

  @override
  String get drvReadyForRequests => 'Ready to receive ride requests';

  @override
  String get drvGoOnlineHint => 'Go online to receive ride requests';

  @override
  String get goOnline => 'Go Online';

  @override
  String get goOffline => 'Go Offline';

  @override
  String get onlineLabel => 'Online';

  @override
  String get rideInProgress => 'You have a ride in progress';

  @override
  String get resume => 'Resume';

  @override
  String get driverStaySafe => 'Stay safe. You\'re on the road.';

  @override
  String get verificationPending => 'Verification pending';

  @override
  String get verificationBody =>
      'You cannot go online until your account is verified.';

  @override
  String get lowBalance => 'Low balance';

  @override
  String get walletBalance => 'Wallet Balance';

  @override
  String get topUp => 'Top Up';

  @override
  String get topUpWalletLabel => 'Top up wallet';

  @override
  String get couldNotLoadAccount => 'Could not load your account';

  @override
  String get couldNotLoad => 'Could not load';

  @override
  String get loadingTitle => 'Loading';

  @override
  String get gettingRequests => 'Getting your ride requests';

  @override
  String get rideRequestsTitle => 'Ride requests';

  @override
  String get noRequests => 'No ride requests right now';

  @override
  String get newRequestsHere => 'New requests will appear here.';

  @override
  String get takenOfflineTitle => 'You were taken offline';

  @override
  String get takenOfflineBody =>
      'A ride request was not answered in time. Go online when you are ready for requests again.';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get assignedHospital => 'Assigned hospital';

  @override
  String get cancelRideConfirm => 'Are you sure you want to cancel this ride?';

  @override
  String get no => 'No';

  @override
  String get yesCancel => 'Yes, Cancel';

  @override
  String get noMapsApp => 'No maps app could be opened';

  @override
  String get rideReassigned =>
      'This ride is no longer yours. It has been reassigned.';

  @override
  String get rideEnded => 'This ride has ended.';

  @override
  String get rideNoLongerAssigned => 'This ride is no longer assigned to you.';

  @override
  String get patientPickup => 'Patient pickup';

  @override
  String get youAreHere => 'You are here';

  @override
  String get startDriving => 'Start Driving';

  @override
  String get patientPickedUp => 'Patient Picked Up';

  @override
  String get arrivedAtHospital => 'Arrived at Hospital';

  @override
  String get completeRide => 'Complete Ride';

  @override
  String get nextStep => 'Next';

  @override
  String get gpsSharing => 'Sharing your location with the patient';

  @override
  String get gpsReconnecting => 'Location sharing interrupted, reconnecting';

  @override
  String get gpsOff => 'Location sharing is off. The patient cannot see you.';

  @override
  String get statusFinding => 'Finding Driver';

  @override
  String get statusAssigned => 'Driver Assigned';

  @override
  String get statusEnRoute => 'Driver En Route';

  @override
  String get statusPickedUp => 'Patient Picked Up';

  @override
  String get statusArrived => 'Arrived at Hospital';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get ecTitle => 'Request emergency help?';

  @override
  String get ecSubtitle =>
      'Check your pickup location, then tell us what is wrong.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get call1122 => 'Call 1122';

  @override
  String get locFinding => 'Finding your location…';

  @override
  String get locUsing => 'Using your current location';

  @override
  String get locNoFix => 'We cannot find you yet';

  @override
  String get locNoFixHelp => 'Move to an open area, or call 1122 now.';

  @override
  String get locNeeded => 'Location is needed to send help';

  @override
  String get locNeededHelp =>
      'Allow location so the nearest ambulance knows where you are.';

  @override
  String get turnOnLocation => 'Turn on location';

  @override
  String get locBlocked => 'Location is blocked';

  @override
  String get locBlockedHelp =>
      'Open settings and allow location for SmartRide.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get locOff => 'Location is switched off';

  @override
  String get locOffHelp =>
      'Turn on location in your phone settings, then try again.';

  @override
  String get dispFinding => 'Finding your driver...';

  @override
  String get dispLocating =>
      'Locating the nearest driver and the right hospital for your needs.';

  @override
  String get dispCalm => 'Please stay calm. Help is on the way.';

  @override
  String get dispConnLost =>
      'Connection lost — we can\'t check your ride status. Check your internet, or call 1122 directly below.';

  @override
  String get dispNoStatus =>
      'We can\'t show this ride\'s status right now. Please call 1122 directly below.';

  @override
  String get backToHomeLower => 'Back to home';

  @override
  String get call1122Directly => 'Call 1122 directly';

  @override
  String get getHelpNow => 'Get Help Now';

  @override
  String get helpArranged =>
      'Help is being arranged. Tell us what\'s happening so we can send the right support.';

  @override
  String get whatsHappening => 'WHAT\'S HAPPENING?';

  @override
  String get anyOtherDetails => 'ANY OTHER DETAILS? (OPTIONAL)';

  @override
  String get detailsHint => 'e.g. patient is conscious, address details...';

  @override
  String get pickupAddressHint =>
      'Pickup address (leave blank for current location)';

  @override
  String get sendForHelp => 'Send for Help';

  @override
  String get orCallDirectly => 'Or call directly: 1122';

  @override
  String get enableLabel => 'Enable';

  @override
  String get symChestPain => 'Chest Pain';

  @override
  String get symBreathing => 'Breathing Trouble';

  @override
  String get symPregnancy => 'Pregnancy';

  @override
  String get symInjury => 'Injury / Accident';

  @override
  String get symChildSick => 'Child Sick';

  @override
  String get symOther => 'Other / Not Sure';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get failedLoadWallet => 'Failed to load wallet';

  @override
  String get retry => 'Retry';

  @override
  String get driverEarningsHistory => 'Driver earnings history →';

  @override
  String get accountBalance => 'ACCOUNT BALANCE';

  @override
  String get lowBalanceChip => '⚠ Low balance';

  @override
  String get allSet => '● All set';

  @override
  String get perCompletedRide => 'per completed ride';

  @override
  String get changePlan => 'Change Plan →';

  @override
  String get commissionPaid => 'Commission paid';

  @override
  String get netEarnings => 'Net earnings';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get noTransactionsYet => 'No transactions yet.';

  @override
  String get myEarnings => 'My Earnings';

  @override
  String get loadingEarnings => 'Loading earnings...';

  @override
  String get failedLoadEarnings => 'Failed to load earnings';

  @override
  String get noCompletedRidesYet => 'No completed rides yet.';

  @override
  String get totalEarned => 'Total Earned';

  @override
  String get tripHistory => 'Trip History';

  @override
  String get failedLoadHistory => 'Failed to load trip history';

  @override
  String get noCompletedTrips =>
      'No completed trips yet.\nAccept a ride to get started.';

  @override
  String get emergencyWord => 'Emergency';

  @override
  String get rideBooked => 'Ride Booked!';

  @override
  String get bookingBody =>
      'Your trip has been scheduled.\nWe\'ll send a reminder before pickup.';

  @override
  String get bookingId => 'Booking ID';

  @override
  String get currentLocation => 'Current location';

  @override
  String get rideTypeLabel => 'Ride type';

  @override
  String get standardLabel => 'Standard';

  @override
  String get viewMyRides => 'View My Rides';

  @override
  String completedRides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completed rides',
      one: '1 completed ride',
    );
    return '$_temp0';
  }

  @override
  String get rateDriverBtn => 'Rate Driver';

  @override
  String get done => 'Done';

  @override
  String get noPhoneApp => 'No phone app available on this device';

  @override
  String get noSmsApp => 'No SMS app available on this device';

  @override
  String get liveTracking => 'Live Tracking';

  @override
  String get connecting => 'Connecting...';

  @override
  String get pickupLocation => 'Pickup location';

  @override
  String get driverLocation => 'Driver location';

  @override
  String get liveUnavailable => 'Live location is unavailable.';

  @override
  String get liveReconnecting =>
      'Reconnecting — driver location may be out of date';

  @override
  String get shareWithFamily => 'Share live location with family';

  @override
  String get helpOnTheWay => 'Help is on the way';

  @override
  String get arrivedDestination => 'You have arrived at your destination.';

  @override
  String get rideHasEnded => 'Your ride has ended.';

  @override
  String get rideCompletedTitle => 'Ride Completed';

  @override
  String get rideEndedTitle => 'Ride Ended';

  @override
  String get enableLocation => 'Enable Location';

  @override
  String get notNow => 'Not Now';

  @override
  String get locationDeniedBody =>
      'Location access was denied. Open app settings to enable it.';

  @override
  String get locationWhyBody =>
      'SmartRide needs your location to find nearby drivers and hospitals.';

  @override
  String get openAppSettings => 'Open App Settings';

  @override
  String get allowAccess => 'Allow Access';

  @override
  String get couldNotOpenDialler =>
      'Could not open dialler — call 1122 manually';

  @override
  String get noDriversTitle => 'No Drivers Available';

  @override
  String get noDriversNearby => 'No drivers nearby';

  @override
  String get noDriversBody =>
      'There are no available drivers in your area right now.';

  @override
  String get keepSearching => 'Keep Searching';

  @override
  String get noConnectionTitle => 'No Connection';

  @override
  String get noInternet => 'No internet connection';

  @override
  String get checkConnection => 'Check your connection and try again.';

  @override
  String get topUpPlans => 'Top Up & Plans';

  @override
  String get removePlace => 'Remove place';

  @override
  String get remove => 'Remove';

  @override
  String get delete => 'Delete';

  @override
  String get noSavedPlaces => 'No saved places yet';

  @override
  String get addFirstPlace => 'Add your first place';

  @override
  String get labelField => 'Label';

  @override
  String get addressField => 'Address';

  @override
  String get fewerRides => 'Fewer rides';

  @override
  String get moreRides => 'More rides';

  @override
  String get couldNotLoadHospitals => 'Could not load hospitals';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get save => 'Save';

  @override
  String get helpTitle => 'Help & FAQ';

  @override
  String get helpBanner =>
      'In a life-threatening emergency, call 1122 immediately.';

  @override
  String get faq1q => 'How do I request an emergency ride?';

  @override
  String get faq1a =>
      'Tap the red EMERGENCY button on the home screen, describe your symptoms, and confirm. The nearest available driver is dispatched automatically.';

  @override
  String get faq2q => 'How do I book a ride for later?';

  @override
  String get faq2a =>
      'On the home screen choose \"Book a Ride\", pick a pickup time and destination, and confirm. You can see it later under your rides.';

  @override
  String get faq3q => 'Can I track my driver?';

  @override
  String get faq3a =>
      'Yes. Once a driver accepts your ride, open the ride to see their live location on the map until they arrive.';

  @override
  String get faq4q => 'How do I cancel a ride?';

  @override
  String get faq4a =>
      'Open the ride from your rides list. Cancellation is available while the ride is still pending or before the driver arrives.';

  @override
  String get faq5q => 'I am also a driver. How do I switch?';

  @override
  String get faq5a =>
      'Use the menu drawer to switch between the patient and driver portals. Both run from the same account.';

  @override
  String get contactTitle => 'Contact Us';

  @override
  String get contactIntro =>
      'We are here to help. For anything that is not an emergency, reach the SmartRide support team:';

  @override
  String get contactEmergency => 'Emergency (Rescue 1122)';

  @override
  String get contactHotline => 'Support hotline';

  @override
  String get contactEmail => 'Email';

  @override
  String get contactHours => 'Hours';

  @override
  String get contactHoursValue =>
      'Support: 8am to 10pm. Emergency dispatch: 24/7.';

  @override
  String copiedMessage(String label) {
    return '$label copied';
  }

  @override
  String get howToTopUp => 'How to top up';

  @override
  String get choosePlan => 'Choose a plan';

  @override
  String get payFrom => 'Pay From';

  @override
  String get mostPopular => 'Most Popular';

  @override
  String get customAmount => 'Custom amount';

  @override
  String get enterAmount => 'Enter amount';

  @override
  String get smartRideName => 'SmartRide';

  @override
  String get driverPortal => 'Driver portal';

  @override
  String get patientPortal => 'Patient portal';

  @override
  String get currentPortal => 'Current portal';

  @override
  String get switchToPatient => 'Switch to Patient';

  @override
  String get switchToDriver => 'Switch to Driver';

  @override
  String get becomePatient => 'Become a Patient';

  @override
  String get becomeDriver => 'Become a Driver';

  @override
  String get profileTitle => 'Profile';

  @override
  String get signOutTitle => 'Sign Out';

  @override
  String get activeRideInProgress => 'Active ride in progress';

  @override
  String get switchWarning =>
      'You are currently driving a ride. Switching portals will keep the ride active in the background. Continue?';

  @override
  String get stay => 'Stay';

  @override
  String get switchLabel => 'Switch';

  @override
  String get couldNotSwitch => 'Could not switch portals. Please try again.';

  @override
  String get signOutDriverBody =>
      'This will stop GPS streaming and sign you out.';

  @override
  String get signOutBody => 'Are you sure you want to sign out?';

  @override
  String get couldNotAddRole => 'Could not add this role. Please try again.';

  @override
  String get addDriverProfile =>
      'Add a driver profile to start accepting rides.';

  @override
  String get addPatientProfile => 'Add a patient profile to request rides.';

  @override
  String get licenseField => 'License number';

  @override
  String get plateField => 'Vehicle plate';

  @override
  String get vehicleTypeField => 'Vehicle type';

  @override
  String get vehicleTypeExample => 'Vehicle type (e.g. Sedan, Ambulette)';

  @override
  String get fullNameField => 'Full name';

  @override
  String get contactName => 'Contact Name';

  @override
  String get contactPhone => 'Contact Phone';

  @override
  String get addPlaceBtn => '＋  Add a place';

  @override
  String get placeHome => 'Home';

  @override
  String get placeWork => 'Work';

  @override
  String get placeHospital => 'Hospital';

  @override
  String get placeOther => 'Other';

  @override
  String get editPlace => 'Edit Place';

  @override
  String get addPlace => 'Add Place';

  @override
  String get required => 'Required';

  @override
  String get patientWord => 'Patient';

  @override
  String get driverWord => 'Driver';

  @override
  String get yourLocation => 'Your location';

  @override
  String get centreOnMe => 'Centre on my location';

  @override
  String get locationIsOff => 'Location is off';

  @override
  String get findingYou => 'Finding you…';

  @override
  String get yourDriver => 'Your Driver';

  @override
  String get enRouteToYou => 'En route to you';

  @override
  String get callDriver => 'Call driver';

  @override
  String get loadingYourRides => 'Loading your rides';

  @override
  String get cancelledByPatient => 'Cancelled by patient';

  @override
  String get demandNotEnough => 'Not enough history yet';

  @override
  String get demandQuiet => 'Quiet for the next few hours';

  @override
  String get demandBasedOn => 'Based on ride requests over the last 4 weeks';

  @override
  String get demandWhenRequests =>
      'Busy hours show up once riders have made requests';

  @override
  String get demandAhead => 'Demand ahead';

  @override
  String get demandForecastTitle => 'Demand Forecast';

  @override
  String get couldNotLoadForecast => 'Could not load the forecast';

  @override
  String get acceptedNoLocation =>
      'Ride accepted, but location sharing is off. Allow location access so the patient can see you.';

  @override
  String get couldNotAcceptRide => 'Could not accept the ride';

  @override
  String get enterAnAmount => 'Enter an amount';

  @override
  String get selectPlanOrAmount => 'Select a plan or amount';

  @override
  String demandBusiest(String hour) {
    return 'Busiest around $hour';
  }

  @override
  String continueAmount(String amount) {
    return 'Continue · PKR $amount';
  }

  @override
  String continuePlan(String plan, String price) {
    return 'Continue · $plan · PKR $price';
  }

  @override
  String topUpInstructions(String amount, String method, String email) {
    return 'Nothing has been charged. Send PKR $amount by $method, then send the receipt to SmartRide support ($email). Your wallet is credited once an admin confirms the payment.';
  }

  @override
  String get locationNeededToBook =>
      'We need your location to book a pickup. Turn on location and try again.';

  @override
  String get bookingFailed => 'Booking failed. Please try again.';

  @override
  String get selectDateTimeSemantic => 'Select date and time';

  @override
  String get emptySymptoms =>
      'Tell us what is happening: choose an option or describe it below. If someone is in immediate danger, call 1122.';

  @override
  String get couldNotSendRequest =>
      'We could not send your request. Please try again, or call 1122.';

  @override
  String get locationNeededToHelp =>
      'We need your location to send help. Turn on location and try again.';

  @override
  String get sendingRequest => 'Sending your request';

  @override
  String get verificationSemantic =>
      'Verification pending. You cannot go online until your account is verified.';

  @override
  String get vehicleModelField => 'Vehicle model';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatWithDriver => 'Message driver';

  @override
  String get chatWithPatient => 'Message patient';

  @override
  String get chatHint => 'Message';

  @override
  String get chatSend => 'Send';

  @override
  String get chatEmpty => 'No messages yet. Say hello.';

  @override
  String get chatPrivacyNote => 'Messages are deleted when the ride ends.';

  @override
  String get chatEnded => 'This chat has ended with the ride.';

  @override
  String get chatSendFailed =>
      'Could not send. Check your connection and try again.';

  @override
  String get chatTooLong => 'A message can be up to 500 characters.';

  @override
  String get chatLoadFailed => 'Could not load the chat.';
}
