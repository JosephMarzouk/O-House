import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'O House'**
  String get appName;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping & cleaning record'**
  String get loginSubtitle;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get loginPhoneLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgotten password? Ask your supervisor.'**
  String get loginForgotPassword;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect phone number or password.'**
  String get loginError;

  /// No description provided for @loginConnectionError.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and try again.'**
  String get loginConnectionError;

  /// No description provided for @loginMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number and password.'**
  String get loginMissingFields;

  /// No description provided for @loginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

  /// No description provided for @loginFooter.
  ///
  /// In en, this message translates to:
  /// **'O West Sports Club · staff access only'**
  String get loginFooter;

  /// No description provided for @setPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get setPasswordTitle;

  /// No description provided for @setPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get setPasswordLabel;

  /// No description provided for @setPasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get setPasswordConfirmLabel;

  /// No description provided for @setPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get setPasswordButton;

  /// No description provided for @setPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match.'**
  String get setPasswordMismatch;

  /// No description provided for @setPasswordError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your new password. Try again.'**
  String get setPasswordError;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeToDo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get homeToDo;

  /// No description provided for @homeInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get homeInProgress;

  /// No description provided for @homeSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get homeSubmitted;

  /// No description provided for @homeOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get homeOverdue;

  /// No description provided for @homeOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'Working offline — {count} changes pending'**
  String homeOfflineBanner(int count);

  /// No description provided for @homeNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get homeNextUp;

  /// No description provided for @homeNothingUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Nothing upcoming right now'**
  String get homeNothingUpcoming;

  /// No description provided for @homeRoundSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 assignment} other{{count} assignments}} · {start} – {end}'**
  String homeRoundSummary(int count, String start, String end);

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @tasksTitle.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get tasksTitle;

  /// No description provided for @tasksTabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tasksTabToday;

  /// No description provided for @tasksTabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tasksTabUpcoming;

  /// No description provided for @tasksTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tasksTabHistory;

  /// No description provided for @tasksSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tasksSearchHint;

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks here yet.'**
  String get tasksEmpty;

  /// No description provided for @tasksProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} done'**
  String tasksProgress(int done, int total);

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get statusSubmitted;

  /// No description provided for @statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusExtended.
  ///
  /// In en, this message translates to:
  /// **'Extended'**
  String get statusExtended;

  /// No description provided for @statusExtendedDetail.
  ///
  /// In en, this message translates to:
  /// **'Extended — original window closed {time}'**
  String statusExtendedDetail(String time);

  /// No description provided for @taskDetailProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get taskDetailProgressLabel;

  /// No description provided for @taskDetailPhotosMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 place still needs a photo} other{{count} places still need a photo}}'**
  String taskDetailPhotosMissing(int count);

  /// No description provided for @taskDetailSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit & Sign'**
  String get taskDetailSubmitButton;

  /// No description provided for @taskDetailExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Window closed — ask your supervisor to extend.'**
  String get taskDetailExpiredMessage;

  /// No description provided for @taskDetailPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Photo required'**
  String get taskDetailPhotoRequired;

  /// No description provided for @taskDetailRejectedReason.
  ///
  /// In en, this message translates to:
  /// **'Rejected: {reason}'**
  String taskDetailRejectedReason(String reason);

  /// No description provided for @itemSheetTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get itemSheetTakePhoto;

  /// No description provided for @signatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get signatureTitle;

  /// No description provided for @signatureClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get signatureClear;

  /// No description provided for @signatureSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get signatureSubmit;

  /// No description provided for @successTitle.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get successTitle;

  /// No description provided for @successDetail.
  ///
  /// In en, this message translates to:
  /// **'{task}, signed at {time}. Your supervisor will approve or return it.'**
  String successDetail(String task, String time);

  /// No description provided for @successBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back to my tasks'**
  String get successBackButton;

  /// No description provided for @successViewSubmission.
  ///
  /// In en, this message translates to:
  /// **'View submission'**
  String get successViewSubmission;

  /// No description provided for @historyDetailChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist · {done} of {total}'**
  String historyDetailChecklist(int done, int total);

  /// No description provided for @historyDetailReviewer.
  ///
  /// In en, this message translates to:
  /// **'Reviewer'**
  String get historyDetailReviewer;

  /// No description provided for @historyDetailReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Reviewer note: {note}'**
  String historyDetailReviewNote(String note);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountSection;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePassword;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileSyncStatus.
  ///
  /// In en, this message translates to:
  /// **'{count} photos pending upload'**
  String profileSyncStatus(int count);

  /// No description provided for @profileAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAboutSection;

  /// No description provided for @profileAboutOHouse.
  ///
  /// In en, this message translates to:
  /// **'About O-House'**
  String get profileAboutOHouse;

  /// No description provided for @profileAboutOHouseBody.
  ///
  /// In en, this message translates to:
  /// **'O House is the housekeeping and cleaning record system for O West Sports Club. More information about the app will appear here soon.'**
  String get profileAboutOHouseBody;

  /// No description provided for @profilePolicies.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get profilePolicies;

  /// No description provided for @profilePoliciesBody.
  ///
  /// In en, this message translates to:
  /// **'Club and workplace policies will appear here soon. Ask your supervisor if you need them sooner.'**
  String get profilePoliciesBody;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogout;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
