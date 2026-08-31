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
  String get statusExtended => 'Extended';

  @override
  String statusExtendedDetail(String time) {
    return 'Extended — original window closed $time';
  }

  @override
  String taskDetailWindow(String start, String end) {
    return 'Window: $start–$end';
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
  String get itemSheetNote => 'Note (optional)';

  @override
  String get itemSheetTakePhoto => 'Take photo';

  @override
  String get itemSheetMarkDone => 'Mark done';

  @override
  String get signatureTitle => 'Signature';

  @override
  String get signatureClear => 'Clear';

  @override
  String get signatureSubmit => 'Submit';

  @override
  String get successTitle => 'Submitted';

  @override
  String get successMessage => 'Your submission is pending admin review.';

  @override
  String get successBackButton => 'Back to my tasks';

  @override
  String get historyDetailTitle => 'Task history';

  @override
  String historyDetailReviewNote(String note) {
    return 'Reviewer note: $note';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileLanguage => 'Language';

  @override
  String profileSyncStatus(int count) {
    return '$count photos pending upload';
  }

  @override
  String get profileLogout => 'Log out';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';
}
