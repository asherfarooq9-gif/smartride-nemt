import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ur')
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @helpAndFaq.
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get helpAndFaq;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Sign out of all devices'**
  String get signOutEverywhere;

  /// No description provided for @signOutEverywhereBody.
  ///
  /// In en, this message translates to:
  /// **'This signs you out on every phone where you are logged in.'**
  String get signOutEverywhereBody;

  /// No description provided for @signOutEverywhereFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign out of all devices. Check your connection and try again.'**
  String get signOutEverywhereFailed;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'No connection. Trying again…'**
  String get offlineBanner;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @demandForecast.
  ///
  /// In en, this message translates to:
  /// **'Demand Forecast'**
  String get demandForecast;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @rideHistory.
  ///
  /// In en, this message translates to:
  /// **'Ride History'**
  String get rideHistory;

  /// No description provided for @openRides.
  ///
  /// In en, this message translates to:
  /// **'Open rides'**
  String get openRides;

  /// No description provided for @myRides.
  ///
  /// In en, this message translates to:
  /// **'My rides'**
  String get myRides;

  /// No description provided for @reserveThisRide.
  ///
  /// In en, this message translates to:
  /// **'Reserve this ride'**
  String get reserveThisRide;

  /// No description provided for @giveBack.
  ///
  /// In en, this message translates to:
  /// **'Give back'**
  String get giveBack;

  /// No description provided for @noOpenRidesTitle.
  ///
  /// In en, this message translates to:
  /// **'No open rides nearby'**
  String get noOpenRidesTitle;

  /// No description provided for @noOpenRidesBody.
  ///
  /// In en, this message translates to:
  /// **'Booked trips near you show up here. Reserve one to plan your day.'**
  String get noOpenRidesBody;

  /// No description provided for @noReservedTitle.
  ///
  /// In en, this message translates to:
  /// **'No reserved rides'**
  String get noReservedTitle;

  /// No description provided for @noReservedBody.
  ///
  /// In en, this message translates to:
  /// **'Rides you reserve show up here.'**
  String get noReservedBody;

  /// No description provided for @couldNotLoadRides.
  ///
  /// In en, this message translates to:
  /// **'Could not load rides'**
  String get couldNotLoadRides;

  /// No description provided for @checkConnectionPullDown.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and pull down to try again.'**
  String get checkConnectionPullDown;

  /// No description provided for @reservedMessage.
  ///
  /// In en, this message translates to:
  /// **'Reserved. It becomes yours 30 minutes before pickup.'**
  String get reservedMessage;

  /// No description provided for @givenBackMessage.
  ///
  /// In en, this message translates to:
  /// **'Given back.'**
  String get givenBackMessage;

  /// No description provided for @timeToBeConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Time to be confirmed'**
  String get timeToBeConfirmed;

  /// No description provided for @bookARide.
  ///
  /// In en, this message translates to:
  /// **'Book a Ride'**
  String get bookARide;

  /// No description provided for @scheduleInAdvance.
  ///
  /// In en, this message translates to:
  /// **'Schedule a medical trip in advance'**
  String get scheduleInAdvance;

  /// No description provided for @locationsLabel.
  ///
  /// In en, this message translates to:
  /// **'LOCATIONS'**
  String get locationsLabel;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useCurrentLocation;

  /// No description provided for @typePickupAddress.
  ///
  /// In en, this message translates to:
  /// **'Type your pickup address...'**
  String get typePickupAddress;

  /// No description provided for @destinationLabel.
  ///
  /// In en, this message translates to:
  /// **'DESTINATION'**
  String get destinationLabel;

  /// No description provided for @selectHospital.
  ///
  /// In en, this message translates to:
  /// **'Select destination hospital'**
  String get selectHospital;

  /// No description provided for @specialtyLabel.
  ///
  /// In en, this message translates to:
  /// **'SPECIALTY / DEPARTMENT (OPTIONAL)'**
  String get specialtyLabel;

  /// No description provided for @whenLabel.
  ///
  /// In en, this message translates to:
  /// **'WHEN'**
  String get whenLabel;

  /// No description provided for @selectDateTime.
  ///
  /// In en, this message translates to:
  /// **'Select date & time'**
  String get selectDateTime;

  /// No description provided for @confirmBooking.
  ///
  /// In en, this message translates to:
  /// **'Confirm Booking'**
  String get confirmBooking;

  /// No description provided for @chooseDateTime.
  ///
  /// In en, this message translates to:
  /// **'Please choose a date and time'**
  String get chooseDateTime;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Your name, phone number, health details, emergency contact and ride pickup addresses are removed, and you are signed out everywhere. This cannot be undone.\n\nRide and payment records are kept without your details, so drivers’ earnings and statistics stay correct.'**
  String get deleteAccountBody;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to continue.'**
  String get enterPassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @repeatLabel.
  ///
  /// In en, this message translates to:
  /// **'REPEAT'**
  String get repeatLabel;

  /// No description provided for @noRepeat.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get noRepeat;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeatWeekly;

  /// No description provided for @numberOfTrips.
  ///
  /// In en, this message translates to:
  /// **'Number of trips'**
  String get numberOfTrips;

  /// No description provided for @lastTripOn.
  ///
  /// In en, this message translates to:
  /// **'Last trip: {date}'**
  String lastTripOn(String date);

  /// No description provided for @tripsBooked.
  ///
  /// In en, this message translates to:
  /// **'{count} trips booked'**
  String tripsBooked(int count);

  /// No description provided for @payByLabel.
  ///
  /// In en, this message translates to:
  /// **'Pays by'**
  String get payByLabel;

  /// No description provided for @fareLabel.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fareLabel;

  /// No description provided for @fareHint.
  ///
  /// In en, this message translates to:
  /// **'Pay your driver directly. SmartRide does not take payment in the app.'**
  String get fareHint;

  /// No description provided for @rateDriverAction.
  ///
  /// In en, this message translates to:
  /// **'Rate your driver'**
  String get rateDriverAction;

  /// No description provided for @paymentSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'How you take payment'**
  String get paymentSectionTitle;

  /// No description provided for @paymentSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Patients see this once you are assigned. SmartRide does not handle the money.'**
  String get paymentSectionHint;

  /// No description provided for @paymentNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set yet'**
  String get paymentNotSet;

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// No description provided for @paymentEasypaisa.
  ///
  /// In en, this message translates to:
  /// **'Easypaisa'**
  String get paymentEasypaisa;

  /// No description provided for @paymentJazzcash.
  ///
  /// In en, this message translates to:
  /// **'JazzCash'**
  String get paymentJazzcash;

  /// No description provided for @paymentBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get paymentBank;

  /// No description provided for @brandTagline.
  ///
  /// In en, this message translates to:
  /// **'Medical transport, always nearby.'**
  String get brandTagline;

  /// No description provided for @cityBadge.
  ///
  /// In en, this message translates to:
  /// **'Islamabad · Rawalpindi'**
  String get cityBadge;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @getStartedSub.
  ///
  /// In en, this message translates to:
  /// **'Trusted medical transport for you and your family.'**
  String get getStartedSub;

  /// No description provided for @signUpFree.
  ///
  /// In en, this message translates to:
  /// **'Sign Up — It\'s Free'**
  String get signUpFree;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get logIn;

  /// No description provided for @emergencyCallPrefix.
  ///
  /// In en, this message translates to:
  /// **'In an emergency, call '**
  String get emergencyCallPrefix;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to your SmartRide account'**
  String get loginSubtitle;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'PHONE NUMBER'**
  String get phoneNumberLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Password reset is handled by our support team. Please reach us through Help & Support, or call 1122 for ride emergencies.'**
  String get resetPasswordBody;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @noAccountPrefix.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccountPrefix;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @signupFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed'**
  String get signupFailed;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'FULL NAME'**
  String get fullNameLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get fullNameHint;

  /// No description provided for @passwordMinHint.
  ///
  /// In en, this message translates to:
  /// **'Min. 8 characters'**
  String get passwordMinHint;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PASSWORD'**
  String get confirmPasswordLabel;

  /// No description provided for @repeatPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get repeatPasswordHint;

  /// No description provided for @passwordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsMismatch;

  /// No description provided for @iAmA.
  ///
  /// In en, this message translates to:
  /// **'I AM A...'**
  String get iAmA;

  /// No description provided for @driverDetails.
  ///
  /// In en, this message translates to:
  /// **'DRIVER DETAILS'**
  String get driverDetails;

  /// No description provided for @licenseLabel.
  ///
  /// In en, this message translates to:
  /// **'LICENSE NUMBER'**
  String get licenseLabel;

  /// No description provided for @plateLabel.
  ///
  /// In en, this message translates to:
  /// **'VEHICLE PLATE'**
  String get plateLabel;

  /// No description provided for @vehicleTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'VEHICLE TYPE'**
  String get vehicleTypeLabel;

  /// No description provided for @haveAccountPrefix.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get haveAccountPrefix;

  /// No description provided for @logInLink.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logInLink;

  /// No description provided for @rolePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get rolePatient;

  /// No description provided for @rolePatientSub.
  ///
  /// In en, this message translates to:
  /// **'Book and receive medical rides'**
  String get rolePatientSub;

  /// No description provided for @roleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get roleDriver;

  /// No description provided for @roleDriverSub.
  ///
  /// In en, this message translates to:
  /// **'Drive patients to appointments'**
  String get roleDriverSub;

  /// No description provided for @roleBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get roleBoth;

  /// No description provided for @roleBothSub.
  ///
  /// In en, this message translates to:
  /// **'Access both patient and driver portals'**
  String get roleBothSub;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMyRides.
  ///
  /// In en, this message translates to:
  /// **'My Rides'**
  String get navMyRides;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @requestEmergencyRide.
  ///
  /// In en, this message translates to:
  /// **'Request emergency ride'**
  String get requestEmergencyRide;

  /// No description provided for @emergencyCaps.
  ///
  /// In en, this message translates to:
  /// **'EMERGENCY'**
  String get emergencyCaps;

  /// No description provided for @dragToResize.
  ///
  /// In en, this message translates to:
  /// **'Drag to resize'**
  String get dragToResize;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @staySafe.
  ///
  /// In en, this message translates to:
  /// **'Stay safe. We\'re here for you.'**
  String get staySafe;

  /// No description provided for @activeRide.
  ///
  /// In en, this message translates to:
  /// **'Active Ride'**
  String get activeRide;

  /// No description provided for @bookRideSub.
  ///
  /// In en, this message translates to:
  /// **'Schedule a non-emergency trip'**
  String get bookRideSub;

  /// No description provided for @recentRides.
  ///
  /// In en, this message translates to:
  /// **'Recent Rides'**
  String get recentRides;

  /// No description provided for @viewTrips.
  ///
  /// In en, this message translates to:
  /// **'View your trips'**
  String get viewTrips;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @savedLocations.
  ///
  /// In en, this message translates to:
  /// **'Saved locations'**
  String get savedLocations;

  /// No description provided for @safetyTips.
  ///
  /// In en, this message translates to:
  /// **'Safety Tips'**
  String get safetyTips;

  /// No description provided for @stayInformed.
  ///
  /// In en, this message translates to:
  /// **'Stay informed'**
  String get stayInformed;

  /// No description provided for @couldntLoadRides.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your rides'**
  String get couldntLoadRides;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @noRidesYet.
  ///
  /// In en, this message translates to:
  /// **'No rides yet'**
  String get noRidesYet;

  /// No description provided for @yourRecentRides.
  ///
  /// In en, this message translates to:
  /// **'Your recent rides'**
  String get yourRecentRides;

  /// No description provided for @openMenu.
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get openMenu;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @tapForHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap for immediate help'**
  String get tapForHelp;

  /// No description provided for @doubleTapHelp.
  ///
  /// In en, this message translates to:
  /// **'Double tap to get immediate help'**
  String get doubleTapHelp;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @failedLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get failedLoadProfile;

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInfo;

  /// No description provided for @fullNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameTitle;

  /// No description provided for @phoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneTitle;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @mobilityNeeds.
  ///
  /// In en, this message translates to:
  /// **'Mobility Needs'**
  String get mobilityNeeds;

  /// No description provided for @mobilityNeedsOptional.
  ///
  /// In en, this message translates to:
  /// **'Mobility Needs (optional)'**
  String get mobilityNeedsOptional;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact'**
  String get emergencyContact;

  /// No description provided for @nameTitle.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameTitle;

  /// No description provided for @quickLinks.
  ///
  /// In en, this message translates to:
  /// **'Quick Links'**
  String get quickLinks;

  /// No description provided for @savedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Saved Places'**
  String get savedPlaces;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @rideDetails.
  ///
  /// In en, this message translates to:
  /// **'Ride Details'**
  String get rideDetails;

  /// No description provided for @pickupTitle.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickupTitle;

  /// No description provided for @symptomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get symptomsTitle;

  /// No description provided for @requestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requestedTitle;

  /// No description provided for @trackLive.
  ///
  /// In en, this message translates to:
  /// **'Track Live'**
  String get trackLive;

  /// No description provided for @cancelRide.
  ///
  /// In en, this message translates to:
  /// **'Cancel Ride'**
  String get cancelRide;

  /// No description provided for @keepRide.
  ///
  /// In en, this message translates to:
  /// **'Keep Ride'**
  String get keepRide;

  /// No description provided for @reasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reasonOptional;

  /// No description provided for @rideCancelled.
  ///
  /// In en, this message translates to:
  /// **'Ride cancelled'**
  String get rideCancelled;

  /// No description provided for @couldNotCancel.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel the ride. Please try again.'**
  String get couldNotCancel;

  /// No description provided for @failedLoadRide.
  ///
  /// In en, this message translates to:
  /// **'Failed to load ride'**
  String get failedLoadRide;

  /// No description provided for @rateYourDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate Your Driver'**
  String get rateYourDriverTitle;

  /// No description provided for @howWasRide.
  ///
  /// In en, this message translates to:
  /// **'How was your ride?'**
  String get howWasRide;

  /// No description provided for @anyComments.
  ///
  /// In en, this message translates to:
  /// **'Any comments? (optional)'**
  String get anyComments;

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get submitRating;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @thankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get thankYou;

  /// No description provided for @feedbackHelps.
  ///
  /// In en, this message translates to:
  /// **'Your feedback helps us improve the service.'**
  String get feedbackHelps;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @ratingTerrible.
  ///
  /// In en, this message translates to:
  /// **'Terrible'**
  String get ratingTerrible;

  /// No description provided for @ratingPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get ratingPoor;

  /// No description provided for @ratingOkay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get ratingOkay;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// No description provided for @ratingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingExcellent;

  /// No description provided for @couldNotSubmitRating.
  ///
  /// In en, this message translates to:
  /// **'Could not submit your rating. Please try again.'**
  String get couldNotSubmitRating;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @loadingRides.
  ///
  /// In en, this message translates to:
  /// **'Loading rides...'**
  String get loadingRides;

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get failedToLoad;

  /// No description provided for @noRidesYetDot.
  ///
  /// In en, this message translates to:
  /// **'No rides yet.'**
  String get noRidesYetDot;

  /// No description provided for @drvAccountLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your account'**
  String get drvAccountLoading;

  /// No description provided for @drvAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Your account could not be loaded'**
  String get drvAccountFailed;

  /// No description provided for @drvLockUnverified.
  ///
  /// In en, this message translates to:
  /// **'Available once your account is verified'**
  String get drvLockUnverified;

  /// No description provided for @drvCheckingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking your status'**
  String get drvCheckingStatus;

  /// No description provided for @drvStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get drvStatusUnavailable;

  /// No description provided for @drvOnline.
  ///
  /// In en, this message translates to:
  /// **'You\'re Online'**
  String get drvOnline;

  /// No description provided for @drvOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re Offline'**
  String get drvOffline;

  /// No description provided for @drvReadyForRequests.
  ///
  /// In en, this message translates to:
  /// **'Ready to receive ride requests'**
  String get drvReadyForRequests;

  /// No description provided for @drvGoOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'Go online to receive ride requests'**
  String get drvGoOnlineHint;

  /// No description provided for @goOnline.
  ///
  /// In en, this message translates to:
  /// **'Go Online'**
  String get goOnline;

  /// No description provided for @goOffline.
  ///
  /// In en, this message translates to:
  /// **'Go Offline'**
  String get goOffline;

  /// No description provided for @onlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get onlineLabel;

  /// No description provided for @rideInProgress.
  ///
  /// In en, this message translates to:
  /// **'You have a ride in progress'**
  String get rideInProgress;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @driverStaySafe.
  ///
  /// In en, this message translates to:
  /// **'Stay safe. You\'re on the road.'**
  String get driverStaySafe;

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification pending'**
  String get verificationPending;

  /// No description provided for @verificationBody.
  ///
  /// In en, this message translates to:
  /// **'You cannot go online until your account is verified.'**
  String get verificationBody;

  /// No description provided for @lowBalance.
  ///
  /// In en, this message translates to:
  /// **'Low balance'**
  String get lowBalance;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalance;

  /// No description provided for @topUp.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get topUp;

  /// No description provided for @topUpWalletLabel.
  ///
  /// In en, this message translates to:
  /// **'Top up wallet'**
  String get topUpWalletLabel;

  /// No description provided for @couldNotLoadAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not load your account'**
  String get couldNotLoadAccount;

  /// No description provided for @couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load'**
  String get couldNotLoad;

  /// No description provided for @loadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingTitle;

  /// No description provided for @gettingRequests.
  ///
  /// In en, this message translates to:
  /// **'Getting your ride requests'**
  String get gettingRequests;

  /// No description provided for @rideRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride requests'**
  String get rideRequestsTitle;

  /// No description provided for @noRequests.
  ///
  /// In en, this message translates to:
  /// **'No ride requests right now'**
  String get noRequests;

  /// No description provided for @newRequestsHere.
  ///
  /// In en, this message translates to:
  /// **'New requests will appear here.'**
  String get newRequestsHere;

  /// No description provided for @takenOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You were taken offline'**
  String get takenOfflineTitle;

  /// No description provided for @takenOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'A ride request was not answered in time. Go online when you are ready for requests again.'**
  String get takenOfflineBody;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @assignedHospital.
  ///
  /// In en, this message translates to:
  /// **'Assigned hospital'**
  String get assignedHospital;

  /// No description provided for @cancelRideConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this ride?'**
  String get cancelRideConfirm;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, Cancel'**
  String get yesCancel;

  /// No description provided for @noMapsApp.
  ///
  /// In en, this message translates to:
  /// **'No maps app could be opened'**
  String get noMapsApp;

  /// No description provided for @rideReassigned.
  ///
  /// In en, this message translates to:
  /// **'This ride is no longer yours. It has been reassigned.'**
  String get rideReassigned;

  /// No description provided for @rideEnded.
  ///
  /// In en, this message translates to:
  /// **'This ride has ended.'**
  String get rideEnded;

  /// No description provided for @rideNoLongerAssigned.
  ///
  /// In en, this message translates to:
  /// **'This ride is no longer assigned to you.'**
  String get rideNoLongerAssigned;

  /// No description provided for @patientPickup.
  ///
  /// In en, this message translates to:
  /// **'Patient pickup'**
  String get patientPickup;

  /// No description provided for @youAreHere.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get youAreHere;

  /// No description provided for @startDriving.
  ///
  /// In en, this message translates to:
  /// **'Start Driving'**
  String get startDriving;

  /// No description provided for @patientPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Patient Picked Up'**
  String get patientPickedUp;

  /// No description provided for @arrivedAtHospital.
  ///
  /// In en, this message translates to:
  /// **'Arrived at Hospital'**
  String get arrivedAtHospital;

  /// No description provided for @completeRide.
  ///
  /// In en, this message translates to:
  /// **'Complete Ride'**
  String get completeRide;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextStep;

  /// No description provided for @gpsSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing your location with the patient'**
  String get gpsSharing;

  /// No description provided for @gpsReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Location sharing interrupted, reconnecting'**
  String get gpsReconnecting;

  /// No description provided for @gpsOff.
  ///
  /// In en, this message translates to:
  /// **'Location sharing is off. The patient cannot see you.'**
  String get gpsOff;

  /// No description provided for @statusFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding Driver'**
  String get statusFinding;

  /// No description provided for @statusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Driver Assigned'**
  String get statusAssigned;

  /// No description provided for @statusEnRoute.
  ///
  /// In en, this message translates to:
  /// **'Driver En Route'**
  String get statusEnRoute;

  /// No description provided for @statusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Patient Picked Up'**
  String get statusPickedUp;

  /// No description provided for @statusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived at Hospital'**
  String get statusArrived;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @ecTitle.
  ///
  /// In en, this message translates to:
  /// **'Request emergency help?'**
  String get ecTitle;

  /// No description provided for @ecSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your pickup location, then tell us what is wrong.'**
  String get ecSubtitle;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @call1122.
  ///
  /// In en, this message translates to:
  /// **'Call 1122'**
  String get call1122;

  /// No description provided for @locFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get locFinding;

  /// No description provided for @locUsing.
  ///
  /// In en, this message translates to:
  /// **'Using your current location'**
  String get locUsing;

  /// No description provided for @locNoFix.
  ///
  /// In en, this message translates to:
  /// **'We cannot find you yet'**
  String get locNoFix;

  /// No description provided for @locNoFixHelp.
  ///
  /// In en, this message translates to:
  /// **'Move to an open area, or call 1122 now.'**
  String get locNoFixHelp;

  /// No description provided for @locNeeded.
  ///
  /// In en, this message translates to:
  /// **'Location is needed to send help'**
  String get locNeeded;

  /// No description provided for @locNeededHelp.
  ///
  /// In en, this message translates to:
  /// **'Allow location so the nearest ambulance knows where you are.'**
  String get locNeededHelp;

  /// No description provided for @turnOnLocation.
  ///
  /// In en, this message translates to:
  /// **'Turn on location'**
  String get turnOnLocation;

  /// No description provided for @locBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked'**
  String get locBlocked;

  /// No description provided for @locBlockedHelp.
  ///
  /// In en, this message translates to:
  /// **'Open settings and allow location for SmartRide.'**
  String get locBlockedHelp;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @locOff.
  ///
  /// In en, this message translates to:
  /// **'Location is switched off'**
  String get locOff;

  /// No description provided for @locOffHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn on location in your phone settings, then try again.'**
  String get locOffHelp;

  /// No description provided for @dispFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding your driver...'**
  String get dispFinding;

  /// No description provided for @dispLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating the nearest driver and the right hospital for your needs.'**
  String get dispLocating;

  /// No description provided for @dispCalm.
  ///
  /// In en, this message translates to:
  /// **'Please stay calm. Help is on the way.'**
  String get dispCalm;

  /// No description provided for @dispConnLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost — we can\'t check your ride status. Check your internet, or call 1122 directly below.'**
  String get dispConnLost;

  /// No description provided for @dispNoStatus.
  ///
  /// In en, this message translates to:
  /// **'We can\'t show this ride\'s status right now. Please call 1122 directly below.'**
  String get dispNoStatus;

  /// No description provided for @backToHomeLower.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHomeLower;

  /// No description provided for @call1122Directly.
  ///
  /// In en, this message translates to:
  /// **'Call 1122 directly'**
  String get call1122Directly;

  /// No description provided for @getHelpNow.
  ///
  /// In en, this message translates to:
  /// **'Get Help Now'**
  String get getHelpNow;

  /// No description provided for @helpArranged.
  ///
  /// In en, this message translates to:
  /// **'Help is being arranged. Tell us what\'s happening so we can send the right support.'**
  String get helpArranged;

  /// No description provided for @whatsHappening.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S HAPPENING?'**
  String get whatsHappening;

  /// No description provided for @anyOtherDetails.
  ///
  /// In en, this message translates to:
  /// **'ANY OTHER DETAILS? (OPTIONAL)'**
  String get anyOtherDetails;

  /// No description provided for @detailsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. patient is conscious, address details...'**
  String get detailsHint;

  /// No description provided for @pickupAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Pickup address (leave blank for current location)'**
  String get pickupAddressHint;

  /// No description provided for @sendForHelp.
  ///
  /// In en, this message translates to:
  /// **'Send for Help'**
  String get sendForHelp;

  /// No description provided for @orCallDirectly.
  ///
  /// In en, this message translates to:
  /// **'Or call directly: 1122'**
  String get orCallDirectly;

  /// No description provided for @enableLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enableLabel;

  /// No description provided for @symChestPain.
  ///
  /// In en, this message translates to:
  /// **'Chest Pain'**
  String get symChestPain;

  /// No description provided for @symBreathing.
  ///
  /// In en, this message translates to:
  /// **'Breathing Trouble'**
  String get symBreathing;

  /// No description provided for @symPregnancy.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get symPregnancy;

  /// No description provided for @symInjury.
  ///
  /// In en, this message translates to:
  /// **'Injury / Accident'**
  String get symInjury;

  /// No description provided for @symChildSick.
  ///
  /// In en, this message translates to:
  /// **'Child Sick'**
  String get symChildSick;

  /// No description provided for @symOther.
  ///
  /// In en, this message translates to:
  /// **'Other / Not Sure'**
  String get symOther;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @failedLoadWallet.
  ///
  /// In en, this message translates to:
  /// **'Failed to load wallet'**
  String get failedLoadWallet;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @driverEarningsHistory.
  ///
  /// In en, this message translates to:
  /// **'Driver earnings history →'**
  String get driverEarningsHistory;

  /// No description provided for @accountBalance.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT BALANCE'**
  String get accountBalance;

  /// No description provided for @lowBalanceChip.
  ///
  /// In en, this message translates to:
  /// **'⚠ Low balance'**
  String get lowBalanceChip;

  /// No description provided for @allSet.
  ///
  /// In en, this message translates to:
  /// **'● All set'**
  String get allSet;

  /// No description provided for @perCompletedRide.
  ///
  /// In en, this message translates to:
  /// **'per completed ride'**
  String get perCompletedRide;

  /// No description provided for @changePlan.
  ///
  /// In en, this message translates to:
  /// **'Change Plan →'**
  String get changePlan;

  /// No description provided for @commissionPaid.
  ///
  /// In en, this message translates to:
  /// **'Commission paid'**
  String get commissionPaid;

  /// No description provided for @netEarnings.
  ///
  /// In en, this message translates to:
  /// **'Net earnings'**
  String get netEarnings;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get noTransactionsYet;

  /// No description provided for @myEarnings.
  ///
  /// In en, this message translates to:
  /// **'My Earnings'**
  String get myEarnings;

  /// No description provided for @loadingEarnings.
  ///
  /// In en, this message translates to:
  /// **'Loading earnings...'**
  String get loadingEarnings;

  /// No description provided for @failedLoadEarnings.
  ///
  /// In en, this message translates to:
  /// **'Failed to load earnings'**
  String get failedLoadEarnings;

  /// No description provided for @noCompletedRidesYet.
  ///
  /// In en, this message translates to:
  /// **'No completed rides yet.'**
  String get noCompletedRidesYet;

  /// No description provided for @totalEarned.
  ///
  /// In en, this message translates to:
  /// **'Total Earned'**
  String get totalEarned;

  /// No description provided for @tripHistory.
  ///
  /// In en, this message translates to:
  /// **'Trip History'**
  String get tripHistory;

  /// No description provided for @failedLoadHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to load trip history'**
  String get failedLoadHistory;

  /// No description provided for @noCompletedTrips.
  ///
  /// In en, this message translates to:
  /// **'No completed trips yet.\nAccept a ride to get started.'**
  String get noCompletedTrips;

  /// No description provided for @emergencyWord.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergencyWord;

  /// No description provided for @rideBooked.
  ///
  /// In en, this message translates to:
  /// **'Ride Booked!'**
  String get rideBooked;

  /// No description provided for @bookingBody.
  ///
  /// In en, this message translates to:
  /// **'Your trip has been scheduled.\nWe\'ll send a reminder before pickup.'**
  String get bookingBody;

  /// No description provided for @bookingId.
  ///
  /// In en, this message translates to:
  /// **'Booking ID'**
  String get bookingId;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// No description provided for @rideTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Ride type'**
  String get rideTypeLabel;

  /// No description provided for @standardLabel.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standardLabel;

  /// No description provided for @viewMyRides.
  ///
  /// In en, this message translates to:
  /// **'View My Rides'**
  String get viewMyRides;

  /// No description provided for @completedRides.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 completed ride} other{{count} completed rides}}'**
  String completedRides(int count);

  /// No description provided for @rateDriverBtn.
  ///
  /// In en, this message translates to:
  /// **'Rate Driver'**
  String get rateDriverBtn;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @noPhoneApp.
  ///
  /// In en, this message translates to:
  /// **'No phone app available on this device'**
  String get noPhoneApp;

  /// No description provided for @noSmsApp.
  ///
  /// In en, this message translates to:
  /// **'No SMS app available on this device'**
  String get noSmsApp;

  /// No description provided for @liveTracking.
  ///
  /// In en, this message translates to:
  /// **'Live Tracking'**
  String get liveTracking;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @pickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup location'**
  String get pickupLocation;

  /// No description provided for @driverLocation.
  ///
  /// In en, this message translates to:
  /// **'Driver location'**
  String get driverLocation;

  /// No description provided for @liveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live location is unavailable.'**
  String get liveUnavailable;

  /// No description provided for @liveReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting — driver location may be out of date'**
  String get liveReconnecting;

  /// No description provided for @shareWithFamily.
  ///
  /// In en, this message translates to:
  /// **'Share live location with family'**
  String get shareWithFamily;

  /// No description provided for @helpOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Help is on the way'**
  String get helpOnTheWay;

  /// No description provided for @arrivedDestination.
  ///
  /// In en, this message translates to:
  /// **'You have arrived at your destination.'**
  String get arrivedDestination;

  /// No description provided for @rideHasEnded.
  ///
  /// In en, this message translates to:
  /// **'Your ride has ended.'**
  String get rideHasEnded;

  /// No description provided for @rideCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride Completed'**
  String get rideCompletedTitle;

  /// No description provided for @rideEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride Ended'**
  String get rideEndedTitle;

  /// No description provided for @enableLocation.
  ///
  /// In en, this message translates to:
  /// **'Enable Location'**
  String get enableLocation;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @locationDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Location access was denied. Open app settings to enable it.'**
  String get locationDeniedBody;

  /// No description provided for @locationWhyBody.
  ///
  /// In en, this message translates to:
  /// **'SmartRide needs your location to find nearby drivers and hospitals.'**
  String get locationWhyBody;

  /// No description provided for @openAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open App Settings'**
  String get openAppSettings;

  /// No description provided for @allowAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow Access'**
  String get allowAccess;

  /// No description provided for @couldNotOpenDialler.
  ///
  /// In en, this message translates to:
  /// **'Could not open dialler — call 1122 manually'**
  String get couldNotOpenDialler;

  /// No description provided for @noDriversTitle.
  ///
  /// In en, this message translates to:
  /// **'No Drivers Available'**
  String get noDriversTitle;

  /// No description provided for @noDriversNearby.
  ///
  /// In en, this message translates to:
  /// **'No drivers nearby'**
  String get noDriversNearby;

  /// No description provided for @noDriversBody.
  ///
  /// In en, this message translates to:
  /// **'There are no available drivers in your area right now.'**
  String get noDriversBody;

  /// No description provided for @keepSearching.
  ///
  /// In en, this message translates to:
  /// **'Keep Searching'**
  String get keepSearching;

  /// No description provided for @noConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'No Connection'**
  String get noConnectionTitle;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternet;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkConnection;

  /// No description provided for @topUpPlans.
  ///
  /// In en, this message translates to:
  /// **'Top Up & Plans'**
  String get topUpPlans;

  /// No description provided for @removePlace.
  ///
  /// In en, this message translates to:
  /// **'Remove place'**
  String get removePlace;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet'**
  String get noSavedPlaces;

  /// No description provided for @addFirstPlace.
  ///
  /// In en, this message translates to:
  /// **'Add your first place'**
  String get addFirstPlace;

  /// No description provided for @labelField.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get labelField;

  /// No description provided for @addressField.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressField;

  /// No description provided for @fewerRides.
  ///
  /// In en, this message translates to:
  /// **'Fewer rides'**
  String get fewerRides;

  /// No description provided for @moreRides.
  ///
  /// In en, this message translates to:
  /// **'More rides'**
  String get moreRides;

  /// No description provided for @couldNotLoadHospitals.
  ///
  /// In en, this message translates to:
  /// **'Could not load hospitals'**
  String get couldNotLoadHospitals;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get helpTitle;

  /// No description provided for @helpBanner.
  ///
  /// In en, this message translates to:
  /// **'In a life-threatening emergency, call 1122 immediately.'**
  String get helpBanner;

  /// No description provided for @faq1q.
  ///
  /// In en, this message translates to:
  /// **'How do I request an emergency ride?'**
  String get faq1q;

  /// No description provided for @faq1a.
  ///
  /// In en, this message translates to:
  /// **'Tap the red EMERGENCY button on the home screen, describe your symptoms, and confirm. The nearest available driver is dispatched automatically.'**
  String get faq1a;

  /// No description provided for @faq2q.
  ///
  /// In en, this message translates to:
  /// **'How do I book a ride for later?'**
  String get faq2q;

  /// No description provided for @faq2a.
  ///
  /// In en, this message translates to:
  /// **'On the home screen choose \"Book a Ride\", pick a pickup time and destination, and confirm. You can see it later under your rides.'**
  String get faq2a;

  /// No description provided for @faq3q.
  ///
  /// In en, this message translates to:
  /// **'Can I track my driver?'**
  String get faq3q;

  /// No description provided for @faq3a.
  ///
  /// In en, this message translates to:
  /// **'Yes. Once a driver accepts your ride, open the ride to see their live location on the map until they arrive.'**
  String get faq3a;

  /// No description provided for @faq4q.
  ///
  /// In en, this message translates to:
  /// **'How do I cancel a ride?'**
  String get faq4q;

  /// No description provided for @faq4a.
  ///
  /// In en, this message translates to:
  /// **'Open the ride from your rides list. Cancellation is available while the ride is still pending or before the driver arrives.'**
  String get faq4a;

  /// No description provided for @faq5q.
  ///
  /// In en, this message translates to:
  /// **'I am also a driver. How do I switch?'**
  String get faq5q;

  /// No description provided for @faq5a.
  ///
  /// In en, this message translates to:
  /// **'Use the menu drawer to switch between the patient and driver portals. Both run from the same account.'**
  String get faq5a;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactTitle;

  /// No description provided for @contactIntro.
  ///
  /// In en, this message translates to:
  /// **'We are here to help. For anything that is not an emergency, reach the SmartRide support team:'**
  String get contactIntro;

  /// No description provided for @contactEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency (Rescue 1122)'**
  String get contactEmergency;

  /// No description provided for @contactHotline.
  ///
  /// In en, this message translates to:
  /// **'Support hotline'**
  String get contactHotline;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactEmail;

  /// No description provided for @contactHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get contactHours;

  /// No description provided for @contactHoursValue.
  ///
  /// In en, this message translates to:
  /// **'Support: 8am to 10pm. Emergency dispatch: 24/7.'**
  String get contactHoursValue;

  /// No description provided for @copiedMessage.
  ///
  /// In en, this message translates to:
  /// **'{label} copied'**
  String copiedMessage(String label);

  /// No description provided for @howToTopUp.
  ///
  /// In en, this message translates to:
  /// **'How to top up'**
  String get howToTopUp;

  /// No description provided for @choosePlan.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get choosePlan;

  /// No description provided for @payFrom.
  ///
  /// In en, this message translates to:
  /// **'Pay From'**
  String get payFrom;

  /// No description provided for @mostPopular.
  ///
  /// In en, this message translates to:
  /// **'Most Popular'**
  String get mostPopular;

  /// No description provided for @customAmount.
  ///
  /// In en, this message translates to:
  /// **'Custom amount'**
  String get customAmount;

  /// No description provided for @enterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get enterAmount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
