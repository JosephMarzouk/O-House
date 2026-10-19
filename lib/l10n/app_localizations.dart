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

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginUseEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email instead'**
  String get loginUseEmail;

  /// No description provided for @loginUsePhone.
  ///
  /// In en, this message translates to:
  /// **'Sign in with phone number instead'**
  String get loginUsePhone;

  /// No description provided for @loginLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong passwords. Try again in 15 minutes.'**
  String get loginLocked;

  /// No description provided for @loginNoAccess.
  ///
  /// In en, this message translates to:
  /// **'This account can\'t use the app. Ask your supervisor.'**
  String get loginNoAccess;

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
  /// **'Incorrect sign-in details or password.'**
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
  /// **'{club} · staff access only'**
  String loginFooter(String club);

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

  /// No description provided for @statusFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get statusFollowUp;

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

  /// No description provided for @answerYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get answerYes;

  /// No description provided for @answerNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get answerNo;

  /// No description provided for @answerPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get answerPass;

  /// No description provided for @answerFail.
  ///
  /// In en, this message translates to:
  /// **'Fail'**
  String get answerFail;

  /// No description provided for @answerNumberHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get answerNumberHint;

  /// No description provided for @answerTextHint.
  ///
  /// In en, this message translates to:
  /// **'Type your answer'**
  String get answerTextHint;

  /// No description provided for @answerRange.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max}'**
  String answerRange(String min, String max);

  /// No description provided for @answerAtLeast.
  ///
  /// In en, this message translates to:
  /// **'≥ {min}'**
  String answerAtLeast(String min);

  /// No description provided for @answerAtMost.
  ///
  /// In en, this message translates to:
  /// **'≤ {max}'**
  String answerAtMost(String max);

  /// No description provided for @followUpNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needs follow-up'**
  String get followUpNeeded;

  /// No description provided for @followUpYouAnswered.
  ///
  /// In en, this message translates to:
  /// **'you answered {answer}'**
  String followUpYouAnswered(String answer);

  /// No description provided for @followUpExpected.
  ///
  /// In en, this message translates to:
  /// **'expected {expected}'**
  String followUpExpected(String expected);

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

  /// No description provided for @successFollowUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Sent — needs follow-up'**
  String get successFollowUpTitle;

  /// No description provided for @successFollowUpBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 answer didn\'t match} other{{count} answers didn\'t match}}'**
  String successFollowUpBody(int count);

  /// No description provided for @successReviewFlagged.
  ///
  /// In en, this message translates to:
  /// **'Review flagged answers'**
  String get successReviewFlagged;

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
  /// **'{count, plural, one{1 change not sent yet} other{{count} changes not sent yet}}'**
  String profileSyncStatus(int count);

  /// No description provided for @profileAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAboutSection;

  /// No description provided for @profileAboutOHouse.
  ///
  /// In en, this message translates to:
  /// **'About {app}'**
  String profileAboutOHouse(String app);

  /// No description provided for @profileAboutOHouseBody.
  ///
  /// In en, this message translates to:
  /// **'{app} is the housekeeping and cleaning record system for {club}. More information about the app will appear here soon.'**
  String profileAboutOHouseBody(String app, String club);

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

  /// No description provided for @syncSending.
  ///
  /// In en, this message translates to:
  /// **'Sending {sent} of {total}'**
  String syncSending(int sent, int total);

  /// No description provided for @syncOfflineUpdated.
  ///
  /// In en, this message translates to:
  /// **'Offline · last updated {time}'**
  String syncOfflineUpdated(String time);

  /// No description provided for @syncNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 change needs attention} other{{count} changes need attention}} · tap to review'**
  String syncNeedsAttention(int count);

  /// No description provided for @parkedTitle.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get parkedTitle;

  /// No description provided for @parkedDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get parkedDismiss;

  /// No description provided for @parkedDismissConfirm.
  ///
  /// In en, this message translates to:
  /// **'Dismiss this change? It will not be sent, and its photo or signature is deleted from this phone.'**
  String get parkedDismissConfirm;

  /// No description provided for @parkedOpAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get parkedOpAnswer;

  /// No description provided for @parkedOpPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get parkedOpPhoto;

  /// No description provided for @parkedOpSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submission'**
  String get parkedOpSubmit;

  /// No description provided for @refusalExpired.
  ///
  /// In en, this message translates to:
  /// **'The time window closed. Ask your supervisor to extend it, then tap Retry.'**
  String get refusalExpired;

  /// No description provided for @refusalClosed.
  ///
  /// In en, this message translates to:
  /// **'This round was already submitted or approved.'**
  String get refusalClosed;

  /// No description provided for @refusalNotFound.
  ///
  /// In en, this message translates to:
  /// **'This round or place no longer exists.'**
  String get refusalNotFound;

  /// No description provided for @refusalNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'This round is no longer assigned to you.'**
  String get refusalNotAuthorized;

  /// No description provided for @refusalTaken.
  ///
  /// In en, this message translates to:
  /// **'Someone else assigned to this round started it first, so it is theirs now.'**
  String get refusalTaken;

  /// No description provided for @itemRecordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record a video'**
  String get itemRecordVideo;

  /// No description provided for @untilDate.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String untilDate(String date);

  /// No description provided for @refusalMissingPhoto.
  ///
  /// In en, this message translates to:
  /// **'An answered place still needs its photo.'**
  String get refusalMissingPhoto;

  /// No description provided for @refusalEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this round was answered.'**
  String get refusalEmpty;

  /// No description provided for @refusalMissingFile.
  ///
  /// In en, this message translates to:
  /// **'The photo or signature is no longer on this phone.'**
  String get refusalMissingFile;

  /// No description provided for @refusalOther.
  ///
  /// In en, this message translates to:
  /// **'The server could not accept this change.'**
  String get refusalOther;

  /// No description provided for @roundGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This checklist is no longer assigned to you'**
  String get roundGoneTitle;

  /// No description provided for @roundGoneBody.
  ///
  /// In en, this message translates to:
  /// **'Someone else may have started it, or it was moved or removed. Anything you did on it stays on this phone and shows under Needs attention.'**
  String get roundGoneBody;

  /// No description provided for @roundGoneBack.
  ///
  /// In en, this message translates to:
  /// **'Back to tasks'**
  String get roundGoneBack;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update the app'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'This version of the app is no longer supported. Install the new version to keep working. Anything not sent yet stays on this phone and is sent after the update.'**
  String get updateBody;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download the update'**
  String get updateDownload;

  /// No description provided for @updateAskSupervisor.
  ///
  /// In en, this message translates to:
  /// **'Ask your supervisor for the new version.'**
  String get updateAskSupervisor;

  /// No description provided for @profileAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version {name} ({code})'**
  String profileAppVersion(String name, int code);

  /// No description provided for @cameraAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access needed'**
  String get cameraAccessTitle;

  /// No description provided for @cameraAccessReason.
  ///
  /// In en, this message translates to:
  /// **'Evidence photos and videos are taken with the camera. Allow camera access, then tap the camera button again. If Android doesn\'t ask any more, turn it on in Settings.'**
  String get cameraAccessReason;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera couldn\'t open on this phone. Try again, or tell your supervisor.'**
  String get cameraUnavailable;

  /// No description provided for @videoPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the video…'**
  String get videoPreparing;

  /// No description provided for @videoPrepareFailed.
  ///
  /// In en, this message translates to:
  /// **'This video couldn\'t be prepared. Record it again, or tell your supervisor.'**
  String get videoPrepareFailed;

  /// No description provided for @refusalStillFailing.
  ///
  /// In en, this message translates to:
  /// **'The server kept failing to accept this change. Tap Retry later, or tell your supervisor.'**
  String get refusalStillFailing;

  /// No description provided for @refusalNoAccess.
  ///
  /// In en, this message translates to:
  /// **'Your account no longer has access. Ask your supervisor.'**
  String get refusalNoAccess;

  /// No description provided for @signOutUnsentTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 change not sent yet} other{{count} changes not sent yet}}'**
  String signOutUnsentTitle(int count);

  /// No description provided for @signOutUnsentBody.
  ///
  /// In en, this message translates to:
  /// **'They stay on this phone and are sent the next time you sign in here.'**
  String get signOutUnsentBody;

  /// No description provided for @signatureNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note for your supervisor (optional)'**
  String get signatureNoteLabel;

  /// No description provided for @taskInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get taskInstructions;

  /// No description provided for @historyStaffNote.
  ///
  /// In en, this message translates to:
  /// **'Staff note: {note}'**
  String historyStaffNote(String note);

  /// No description provided for @successQueuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get successQueuedTitle;

  /// No description provided for @successQueuedBody.
  ///
  /// In en, this message translates to:
  /// **'{task} will be sent automatically as soon as you\'re online.'**
  String successQueuedBody(String task);

  /// No description provided for @zoneChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking your location…'**
  String get zoneChecking;

  /// No description provided for @zoneOutside.
  ///
  /// In en, this message translates to:
  /// **'You\'re {metres} m from the club. Checklists can only be filled inside the club.'**
  String zoneOutside(int metres);

  /// No description provided for @zoneMocked.
  ///
  /// In en, this message translates to:
  /// **'A fake-location app is on. Turn it off to fill checklists.'**
  String get zoneMocked;

  /// No description provided for @zonePermission.
  ///
  /// In en, this message translates to:
  /// **'Checklists can only be filled inside the club. Allow this app to use your precise location.'**
  String get zonePermission;

  /// No description provided for @zoneServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is off. Turn it on to fill checklists inside the club.'**
  String get zoneServiceOff;

  /// No description provided for @zoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find your location. Try again, near a window or outdoors if you can.'**
  String get zoneUnavailable;

  /// No description provided for @zoneOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get zoneOpenSettings;

  /// No description provided for @zoneTurnOnLocation.
  ///
  /// In en, this message translates to:
  /// **'Turn on location'**
  String get zoneTurnOnLocation;

  /// No description provided for @zoneUnknown.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet once to load the club\'s settings.'**
  String get zoneUnknown;

  /// No description provided for @syncServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server — showing saved tasks'**
  String get syncServerUnreachable;

  /// No description provided for @syncLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {time}'**
  String syncLastUpdated(String time);

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

  /// No description provided for @pushPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get pushPermissionTitle;

  /// No description provided for @pushPermissionReason.
  ///
  /// In en, this message translates to:
  /// **'Get a notification when a round is given to you, is about to close, or is sent back.'**
  String get pushPermissionReason;

  /// No description provided for @pushPermissionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get pushPermissionContinue;

  /// No description provided for @pushOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get pushOpen;
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
