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
