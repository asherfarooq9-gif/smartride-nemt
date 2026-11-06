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
