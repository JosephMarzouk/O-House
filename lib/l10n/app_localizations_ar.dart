// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get loginSubtitle => 'سجل النظافة والإشراف الداخلي';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginPhoneLabel => 'رقم الهاتف';

  @override
  String get loginPasswordLabel => 'كلمة المرور';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get loginForgotPassword => 'نسيت كلمة المرور؟ اسأل المشرف.';

  @override
  String get loginError => 'رقم الهاتف أو كلمة المرور غير صحيحة.';

  @override
  String get loginConnectionError =>
      'لا يوجد اتصال. تحقق من الشبكة وحاول مرة أخرى.';

  @override
  String get loginMissingFields => 'أدخل رقم الهاتف وكلمة المرور.';

  @override
  String get loginShowPassword => 'إظهار كلمة المرور';

  @override
  String get loginHidePassword => 'إخفاء كلمة المرور';

  @override
  String loginFooter(String club) {
    return '$club · للموظفين فقط';
  }

  @override
  String get setPasswordTitle => 'تعيين كلمة مرور جديدة';

  @override
  String get setPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get setPasswordConfirmLabel => 'تأكيد كلمة المرور';

  @override
  String get setPasswordButton => 'حفظ ومتابعة';

  @override
  String get setPasswordMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get setPasswordError =>
      'تعذّر حفظ كلمة المرور الجديدة. حاول مرة أخرى.';

  @override
  String homeGreeting(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get homeToDo => 'قيد الانتظار';

  @override
  String get homeInProgress => 'قيد التنفيذ';

  @override
  String get homeSubmitted => 'تم الإرسال';

  @override
  String get homeOverdue => 'متأخرة';

  @override
  String homeOfflineBanner(int count) {
    return 'العمل دون اتصال — $count تغييرات بانتظار المزامنة';
  }

  @override
  String get homeNextUp => 'التالي';

  @override
  String get homeNothingUpcoming => 'لا يوجد مهام قادمة حتى الآن';

  @override
  String homeRoundSummary(int count, String start, String end) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مهمة',
      few: '$count مهام',
      two: 'مهمتان',
      one: 'مهمة واحدة',
    );
    return '$_temp0 · $start – $end';
  }

  @override
  String get navHome => 'الرئيسية';

  @override
  String get tasksTitle => 'مهامي';

  @override
  String get tasksTabToday => 'اليوم';

  @override
  String get tasksTabUpcoming => 'القادمة';

  @override
  String get tasksTabHistory => 'السجل';

  @override
  String get tasksSearchHint => 'بحث';

  @override
  String get tasksEmpty => 'لا توجد مهام هنا بعد.';

  @override
  String tasksProgress(int done, int total) {
    return '$done/$total مكتملة';
  }

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusInProgress => 'قيد التنفيذ';

  @override
  String get statusSubmitted => 'تم الإرسال';

  @override
  String get statusApproved => 'معتمدة';

  @override
  String get statusRejected => 'مرفوضة';

  @override
  String get statusExpired => 'منتهية';

  @override
  String get statusFollowUp => 'بحاجة إلى متابعة';

  @override
  String get statusExtended => 'تم التمديد';

  @override
  String statusExtendedDetail(String time) {
    return 'تم التمديد — الموعد الأصلي انتهى في $time';
  }

  @override
  String get taskDetailProgressLabel => 'التقدم';

  @override
  String taskDetailPhotosMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مكانًا ما زال يحتاج صورة',
      few: '$count أماكن ما زالت تحتاج صورة',
      two: 'مكانان ما زالا يحتاجان صورة',
      one: 'مكان واحد ما زال يحتاج صورة',
    );
    return '$_temp0';
  }

  @override
  String get taskDetailSubmitButton => 'إرسال وتوقيع';

  @override
  String get taskDetailExpiredMessage =>
      'انتهت الفترة الزمنية — يرجى التواصل مع المشرف للتمديد.';

  @override
  String get taskDetailPhotoRequired => 'الصورة مطلوبة';

  @override
  String taskDetailRejectedReason(String reason) {
    return 'مرفوضة: $reason';
  }

  @override
  String get answerYes => 'نعم';

  @override
  String get answerNo => 'لا';

  @override
  String get answerPass => 'ناجح';

  @override
  String get answerFail => 'راسب';

  @override
  String get answerNumberHint => 'أدخل رقمًا';

  @override
  String get answerTextHint => 'اكتب إجابتك';

  @override
  String answerRange(String min, String max) {
    return 'من $min إلى $max';
  }

  @override
  String answerAtLeast(String min) {
    return '$min أو أكثر';
  }

  @override
  String answerAtMost(String max) {
    return '$max أو أقل';
  }

  @override
  String get followUpNeeded => 'بحاجة إلى متابعة';

  @override
  String followUpYouAnswered(String answer) {
    return 'إجابتك: $answer';
  }

  @override
  String followUpExpected(String expected) {
    return 'المتوقع: $expected';
  }

  @override
  String get itemSheetTakePhoto => 'التقاط صورة';

  @override
  String get signatureTitle => 'التوقيع';

  @override
  String get signatureClear => 'مسح';

  @override
  String get signatureSubmit => 'إرسال';

  @override
  String get successTitle => 'تم الإرسال للمراجعة';

  @override
  String successDetail(String task, String time) {
    return '$task، تم التوقيع في $time. سيقوم المشرف بالاعتماد أو الإرجاع.';
  }

  @override
  String get successBackButton => 'العودة إلى مهامي';

  @override
  String get successViewSubmission => 'عرض الإرسال';

  @override
  String get successFollowUpTitle => 'تم الإرسال — بحاجة إلى متابعة';

  @override
  String successFollowUpBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إجابة غير مطابقة',
      few: '$count إجابات غير مطابقة',
      two: 'إجابتان غير مطابقتين',
      one: 'إجابة واحدة غير مطابقة',
    );
    return '$_temp0';
  }

  @override
  String get successReviewFlagged => 'مراجعة الإجابات غير المطابقة';

  @override
  String historyDetailChecklist(int done, int total) {
    return 'قائمة التحقق · $done من $total';
  }

  @override
  String get historyDetailReviewer => 'المراجع';

  @override
  String historyDetailReviewNote(String note) {
    return 'ملاحظة المراجع: $note';
  }

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileAccountSection => 'الحساب';

  @override
  String get profileChangePassword => 'تغيير كلمة المرور';

  @override
  String get profileLanguage => 'اللغة';

  @override
  String profileSyncStatus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغييرات لم تُرسل بعد',
      one: 'تغيير واحد لم يُرسل بعد',
    );
    return '$_temp0';
  }

  @override
  String get profileAboutSection => 'حول';

  @override
  String profileAboutOHouse(String app) {
    return 'عن $app';
  }

  @override
  String profileAboutOHouseBody(String app, String club) {
    return '$app هو نظام سجل النظافة والإشراف الداخلي لـ$club. سيتم إضافة مزيد من المعلومات عن التطبيق هنا قريبًا.';
  }

  @override
  String get profilePolicies => 'السياسات';

  @override
  String get profilePoliciesBody =>
      'ستظهر سياسات النادي والعمل هنا قريبًا. يرجى سؤال المشرف إذا احتجتها قبل ذلك.';

  @override
  String get profileLogout => 'تسجيل الخروج';

  @override
  String syncSending(int sent, int total) {
    return 'جارٍ الإرسال $sent من $total';
  }

  @override
  String syncOfflineUpdated(String time) {
    return 'دون اتصال · آخر تحديث $time';
  }

  @override
  String syncNeedsAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغييرات تحتاج انتباهك',
      one: 'تغيير واحد يحتاج انتباهك',
    );
    return '$_temp0 · اضغط للمراجعة';
  }

  @override
  String get parkedTitle => 'يحتاج انتباهك';

  @override
  String get parkedDismiss => 'تجاهل';

  @override
  String get parkedDismissConfirm =>
      'تجاهل هذا التغيير؟ لن يتم إرساله، وستُحذف صورته أو توقيعه من هذا الهاتف.';

  @override
  String get parkedOpAnswer => 'إجابة';

  @override
  String get parkedOpPhoto => 'صورة';

  @override
  String get parkedOpSubmit => 'إرسال الجولة';

  @override
  String get refusalExpired =>
      'انتهت الفترة الزمنية. اطلب من مشرفك تمديدها ثم اضغط إعادة المحاولة.';

  @override
  String get refusalClosed => 'تم إرسال هذه الجولة أو اعتمادها بالفعل.';

  @override
  String get refusalNotFound => 'هذه الجولة أو هذا المكان لم يعد موجودًا.';

  @override
  String get refusalNotAuthorized => 'هذه الجولة لم تعد مسندة إليك.';

  @override
  String get refusalMissingPhoto =>
      'مكان تمت الإجابة عليه ما زال يحتاج إلى صورة.';

  @override
  String get refusalEmpty => 'لم تتم الإجابة على أي شيء في هذه الجولة.';

  @override
  String get refusalMissingFile =>
      'الصورة أو التوقيع لم يعد موجودًا على هذا الهاتف.';

  @override
  String get refusalOther => 'تعذّر على الخادم قبول هذا التغيير.';

  @override
  String signOutUnsentTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغييرات لم تُرسل بعد',
      one: 'تغيير واحد لم يُرسل بعد',
    );
    return '$_temp0';
  }

  @override
  String get signOutUnsentBody =>
      'ستبقى على هذا الهاتف وتُرسل في المرة القادمة التي تسجّل فيها الدخول هنا.';

  @override
  String get signatureNoteLabel => 'ملاحظة لمشرفك (اختياري)';

  @override
  String get taskInstructions => 'التعليمات';

  @override
  String historyStaffNote(String note) {
    return 'ملاحظة الموظف: $note';
  }

  @override
  String get successQueuedTitle => 'تم الحفظ على هذا الهاتف';

  @override
  String successQueuedBody(String task) {
    return 'سيتم إرسال $task تلقائيًا فور اتصالك بالإنترنت.';
  }

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonSave => 'حفظ';
}
