// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'O House';

  @override
  String get loginSubtitle => 'Housekeeping & cleaning record';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginPhoneLabel => 'Phone number';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginForgotPassword => 'Forgotten password? Ask your supervisor.';

  @override
  String get loginError => 'Incorrect phone number or password.';

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
  String get loginFooter => 'O West Sports Club · staff access only';

  @override
  String get setPasswordTitle => 'Set a new password';

  @override
  String get setPasswordLabel => 'New password';

  @override
  String get setPasswordConfirmLabel => 'Confirm password';

  @override
  String get setPasswordButton => 'Save and continue';

  @override
  String get setPasswordMismatch => 'Passwords don\'t match.';

  @override
  String get setPasswordError => 'Couldn\'t save your new password. Try again.';

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
  String get profileAboutOHouse => 'About O-House';

  @override
  String get profileAboutOHouseBody =>
      'O House is the housekeeping and cleaning record system for O West Sports Club. More information about the app will appear here soon.';

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
  String get refusalMissingPhoto => 'An answered place still needs its photo.';

  @override
  String get refusalEmpty => 'Nothing on this round was answered.';

  @override
  String get refusalMissingFile =>
      'The photo or signature is no longer on this phone.';

  @override
  String get refusalOther => 'The server could not accept this change.';

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
  String get clubCodeTitle => 'Enter your club code';

  @override
  String get clubCodeHint => 'Club code';

  @override
  String get clubCodeContinue => 'Continue';

  @override
  String get clubCodeUnknown =>
      'No club with that code. Check it with your supervisor.';

  @override
  String get clubCodeConnection =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get profileSwitchClub => 'Switch club';

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
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';
}
