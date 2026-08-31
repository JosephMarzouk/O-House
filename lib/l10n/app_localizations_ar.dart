// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'او هاوس';

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
  String get loginFooter => 'نادي أو ويست الرياضي · للموظفين فقط';

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
  String get statusExtended => 'تم التمديد';

  @override
  String statusExtendedDetail(String time) {
    return 'تم التمديد — الموعد الأصلي انتهى في $time';
  }

  @override
  String taskDetailWindow(String start, String end) {
    return 'الفترة الزمنية: $start–$end';
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
  String get itemSheetNote => 'ملاحظة (اختياري)';

  @override
  String get itemSheetTakePhoto => 'التقاط صورة';

  @override
  String get itemSheetMarkDone => 'تحديد كمكتمل';

  @override
  String get signatureTitle => 'التوقيع';

  @override
  String get signatureClear => 'مسح';

  @override
  String get signatureSubmit => 'إرسال';

  @override
  String get successTitle => 'تم الإرسال';

  @override
  String get successMessage => 'طلبك بانتظار مراجعة المشرف.';

  @override
  String get successBackButton => 'العودة إلى مهامي';

  @override
  String get historyDetailTitle => 'سجل المهمة';

  @override
  String historyDetailReviewNote(String note) {
    return 'ملاحظة المراجع: $note';
  }

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileChangePassword => 'تغيير كلمة المرور';

  @override
  String get profileLanguage => 'اللغة';

  @override
  String profileSyncStatus(int count) {
    return '$count صور بانتظار الرفع';
  }

  @override
  String get profileLogout => 'تسجيل الخروج';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonSave => 'حفظ';
}
