// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loginSubtitle => 'Housekeeping & cleaning record';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginPhoneLabel => 'Phone number';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginUseEmail => 'Sign in with email instead';

  @override
  String get loginUsePhone => 'Sign in with phone number instead';

  @override
  String get loginLocked =>
      'Too many wrong passwords. Try again in 15 minutes.';

  @override
  String get loginNoAccess =>
      'This account can\'t use the app. Ask your supervisor.';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginForgotPassword => 'Forgotten password? Ask your supervisor.';

  @override
  String get loginError => 'Incorrect sign-in details or password.';

  @override
  String get loginConnectionError =>
      'No connection. Check your network and try again.';

  @override
  String get loginMissingFields => 'Enter your phone number and password.';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String loginFooter(String club) {
    return '$club · staff access only';
  }

  @override
  String homeGreeting(String name) {
    return 'Welcome, $name';
  }

  @override
  String get homeToDo => 'To do';

  @override
  String get homeInProgress => 'In progress';

  @override
  String get homeSubmitted => 'Submitted';

  @override
  String get homeOverdue => 'Overdue';

  @override
  String homeOfflineBanner(int count) {
    return 'Working offline — $count changes pending';
  }

  @override
  String get homeNextUp => 'Next up';

  @override
  String get homeNothingUpcoming => 'Nothing upcoming right now';

  @override
  String homeRoundSummary(int count, String start, String end) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assignments',
      one: '1 assignment',
    );
    return '$_temp0 · $start – $end';
  }

  @override
  String get navHome => 'Home';

  @override
  String get tasksTitle => 'My Tasks';

  @override
  String get tasksTabToday => 'Today';

  @override
  String get tasksTabUpcoming => 'Upcoming';

  @override
  String get tasksTabHistory => 'History';

  @override
  String get tasksSearchHint => 'Search';

  @override
  String get tasksEmpty => 'No tasks here yet.';

  @override
  String tasksProgress(int done, int total) {
    return '$done/$total done';
  }

  @override
  String get statusPending => 'Pending';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusSubmitted => 'Submitted';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusFollowUp => 'Follow-up';

  @override
  String get statusExtended => 'Extended';

  @override
  String statusExtendedDetail(String time) {
    return 'Extended — original window closed $time';
  }

  @override
  String get taskDetailProgressLabel => 'Progress';

  @override
  String taskDetailPhotosMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places still need a photo',
      one: '1 place still needs a photo',
    );
    return '$_temp0';
  }

  @override
  String get taskDetailSubmitButton => 'Submit & Sign';

  @override
  String get taskDetailExpiredMessage =>
      'Window closed — ask your supervisor to extend.';

  @override
  String get taskDetailPhotoRequired => 'Photo required';

  @override
  String taskDetailRejectedReason(String reason) {
    return 'Rejected: $reason';
  }

  @override
  String get answerYes => 'Yes';

  @override
  String get answerNo => 'No';

  @override
  String get answerPass => 'Pass';

  @override
  String get answerFail => 'Fail';

  @override
  String get answerNumberHint => 'Enter a number';

  @override
  String get answerTextHint => 'Type your answer';

  @override
  String answerRange(String min, String max) {
    return '$min–$max';
  }

  @override
  String answerAtLeast(String min) {
    return '≥ $min';
  }

  @override
  String answerAtMost(String max) {
    return '≤ $max';
  }

  @override
  String get followUpNeeded => 'Needs follow-up';

  @override
  String followUpYouAnswered(String answer) {
    return 'you answered $answer';
  }

  @override
  String followUpExpected(String expected) {
    return 'expected $expected';
  }

  @override
  String get itemSheetTakePhoto => 'Take photo';

  @override
  String get signatureTitle => 'Signature';

  @override
  String get signatureClear => 'Clear';

  @override
  String get signatureSubmit => 'Submit';

  @override
  String get successTitle => 'Submitted for review';

  @override
  String successDetail(String task, String time) {
    return '$task, signed at $time. Your supervisor will approve or return it.';
  }

  @override
  String get successBackButton => 'Back to my tasks';

  @override
  String get successViewSubmission => 'View submission';

  @override
  String get successFollowUpTitle => 'Sent — needs follow-up';

  @override
  String successFollowUpBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count answers didn\'t match',
      one: '1 answer didn\'t match',
    );
    return '$_temp0';
  }

  @override
  String get successReviewFlagged => 'Review flagged answers';

  @override
  String historyDetailChecklist(int done, int total) {
    return 'Checklist · $done of $total';
  }

  @override
  String get historyDetailReviewer => 'Reviewer';

  @override
  String historyDetailReviewNote(String note) {
    return 'Reviewer note: $note';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAccountSection => 'Account';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileLanguage => 'Language';

  @override
  String profileSyncStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes not sent yet',
      one: '1 change not sent yet',
    );
    return '$_temp0';
  }

  @override
  String get profileAboutSection => 'About';

  @override
  String profileAboutOHouse(String app) {
    return 'About $app';
  }

  @override
  String profileAboutOHouseBody(String app, String club) {
    return '$app is the housekeeping and cleaning record system for $club. More information about the app will appear here soon.';
  }

  @override
  String get profilePolicies => 'Policies';

  @override
  String get profilePoliciesBody =>
      'Club and workplace policies will appear here soon. Ask your supervisor if you need them sooner.';

  @override
  String get profileLogout => 'Log out';

  @override
  String syncSending(int sent, int total) {
    return 'Sending $sent of $total';
  }

  @override
  String syncOfflineUpdated(String time) {
    return 'Offline · last updated $time';
  }

  @override
  String syncNeedsAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes need attention',
      one: '1 change needs attention',
    );
    return '$_temp0 · tap to review';
  }

  @override
  String get parkedTitle => 'Needs attention';

  @override
  String get parkedDismiss => 'Dismiss';

  @override
  String get parkedDismissConfirm =>
      'Dismiss this change? It will not be sent, and its photo or signature is deleted from this phone.';

  @override
  String get parkedOpAnswer => 'Answer';

  @override
  String get parkedOpPhoto => 'Photo';

  @override
  String get parkedOpSubmit => 'Submission';

  @override
  String get refusalExpired =>
      'The time window closed. Ask your supervisor to extend it, then tap Retry.';

  @override
  String get refusalClosed => 'This round was already submitted or approved.';

  @override
  String get refusalNotFound => 'This round or place no longer exists.';

  @override
  String get refusalNotAuthorized => 'This round is no longer assigned to you.';

  @override
  String get refusalTaken =>
      'Someone else assigned to this round started it first, so it is theirs now.';

  @override
  String get itemRecordVideo => 'Record a video';

  @override
  String untilDate(String date) {
    return 'Until $date';
  }

  @override
  String get refusalMissingPhoto => 'An answered place still needs its photo.';

  @override
  String get refusalEmpty => 'Nothing on this round was answered.';

  @override
  String get refusalMissingFile =>
      'The photo or signature is no longer on this phone.';

  @override
  String get refusalOther => 'The server could not accept this change.';

  @override
  String get updateTitle => 'Update the app';

  @override
  String get updateBody =>
      'This version of the app is no longer supported. Install the new version to keep working. Anything not sent yet stays on this phone and is sent after the update.';

  @override
  String get updateDownload => 'Download the update';

  @override
  String get updateAskSupervisor => 'Ask your supervisor for the new version.';

  @override
  String profileAppVersion(String name, int code) {
    return 'App version $name ($code)';
  }

  @override
  String get cameraAccessTitle => 'Camera access needed';

  @override
  String get cameraAccessReason =>
      'Evidence photos and videos are taken with the camera. Allow camera access, then tap the camera button again. If Android doesn\'t ask any more, turn it on in Settings.';

  @override
  String get cameraUnavailable =>
      'The camera couldn\'t open on this phone. Try again, or tell your supervisor.';

  @override
  String get refusalStillFailing =>
      'The server kept failing to accept this change. Tap Retry later, or tell your supervisor.';

  @override
  String get refusalNoAccess =>
      'Your account no longer has access. Ask your supervisor.';

  @override
  String signOutUnsentTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes not sent yet',
      one: '1 change not sent yet',
    );
    return '$_temp0';
  }

  @override
  String get signOutUnsentBody =>
      'They stay on this phone and are sent the next time you sign in here.';

  @override
  String get signatureNoteLabel => 'Note for your supervisor (optional)';

  @override
  String get taskInstructions => 'Instructions';

  @override
  String historyStaffNote(String note) {
    return 'Staff note: $note';
  }

  @override
  String get successQueuedTitle => 'Saved on this phone';

  @override
  String successQueuedBody(String task) {
    return '$task will be sent automatically as soon as you\'re online.';
  }

  @override
  String get zoneChecking => 'Checking your location…';

  @override
  String zoneOutside(int metres) {
    return 'You\'re $metres m from the club. Checklists can only be filled inside the club.';
  }

  @override
  String get zoneMocked =>
      'A fake-location app is on. Turn it off to fill checklists.';

  @override
  String get zonePermission =>
      'Checklists can only be filled inside the club. Allow this app to use your precise location.';

  @override
  String get zoneServiceOff =>
      'Location is off. Turn it on to fill checklists inside the club.';

  @override
  String get zoneUnavailable =>
      'Couldn\'t find your location. Try again, near a window or outdoors if you can.';

  @override
  String get zoneOpenSettings => 'Open settings';

  @override
  String get zoneTurnOnLocation => 'Turn on location';

  @override
  String get zoneUnknown =>
      'Connect to the internet once to load the club\'s settings.';

  @override
  String get syncServerUnreachable =>
      'Can\'t reach the server — showing saved tasks';

  @override
  String syncLastUpdated(String time) {
    return 'Last updated $time';
  }

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get pushPermissionTitle => 'Notifications';

  @override
  String get pushPermissionReason =>
      'Get a notification when a round is given to you, is about to close, or is sent back.';

  @override
  String get pushPermissionContinue => 'Continue';

  @override
  String get pushOpen => 'Open';
}
