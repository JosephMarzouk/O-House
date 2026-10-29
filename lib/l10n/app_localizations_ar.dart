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
  String get loginEmailLabel => 'البريد الإلكتروني';

  @override
  String get loginUseEmail => 'الدخول بالبريد الإلكتروني بدلًا من ذلك';

  @override
  String get loginUsePhone => 'الدخول برقم الهاتف بدلًا من ذلك';

  @override
  String get loginLocked => 'محاولات خاطئة كثيرة. حاول مرة أخرى بعد ١٥ دقيقة.';

  @override
  String get loginNoAccess => 'هذا الحساب لا يستخدم التطبيق. اسأل مشرفك.';

  @override
  String get loginPasswordLabel => 'كلمة المرور';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get loginForgotPassword => 'نسيت كلمة المرور؟ اسأل المشرف.';

  @override
  String get loginError => 'بيانات الدخول أو كلمة المرور غير صحيحة.';

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
  String get refusalTaken =>
      'بدأ زميل آخر مُسند إلى هذه الجولة العمل عليها أولًا، فأصبحت له.';

  @override
  String get itemRecordVideo => 'تسجيل فيديو';

  @override
  String untilDate(String date) {
    return 'حتى $date';
  }

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
  String get roundGoneTitle => 'هذه القائمة لم تعد مسندة إليك';

  @override
  String get roundGoneBody =>
      'ربما بدأها شخص آخر، أو نُقلت أو حُذفت. أي عمل قمت به عليها يبقى على هذا الهاتف ويظهر تحت «يحتاج إلى انتباه».';

  @override
  String get roundGoneBack => 'العودة إلى المهام';

  @override
  String get updateTitle => 'حدّث التطبيق';

  @override
  String get updateBody =>
      'هذا الإصدار من التطبيق لم يعد مدعوماً. ثبّت الإصدار الجديد لمتابعة العمل. ما لم يُرسل بعد يبقى على هذا الهاتف ويُرسل بعد التحديث.';

  @override
  String get updateDownload => 'تنزيل التحديث';

  @override
  String get updateAskSupervisor => 'اطلب الإصدار الجديد من مشرفك.';

  @override
  String profileAppVersion(String name, int code) {
    return 'إصدار التطبيق $name ($code)';
  }

  @override
  String get cameraAccessTitle => 'مطلوب إذن الكاميرا';

  @override
  String get cameraAccessReason =>
      'صور وفيديوهات الإثبات تُلتقط بالكاميرا. اسمح بالوصول إلى الكاميرا ثم اضغط زر الكاميرا مرة أخرى. إذا لم يعد أندرويد يطلب الإذن، فعّله من الإعدادات.';

  @override
  String get cameraUnavailable =>
      'تعذّر فتح الكاميرا على هذا الهاتف. حاول مرة أخرى أو أبلغ مشرفك.';

  @override
  String get videoPreparing => 'جارٍ تجهيز الفيديو…';

  @override
  String get videoPrepareFailed =>
      'تعذّر تجهيز هذا الفيديو. سجّله مرة أخرى أو أبلغ مشرفك.';

  @override
  String get refusalStillFailing =>
      'تعذّر على الخادم قبول هذا التغيير بعد محاولات كثيرة. اضغط إعادة المحاولة لاحقاً أو أبلغ مشرفك.';

  @override
  String get refusalNoAccess => 'لم يعد لحسابك صلاحية الدخول. تواصل مع مشرفك.';

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
  String get zoneChecking => 'جارٍ التحقق من موقعك…';

  @override
  String zoneOutside(int metres) {
    return 'أنت على بُعد $metres متر من النادي. لا يمكن تعبئة قوائم التحقق إلا داخل النادي.';
  }

  @override
  String get zoneMocked =>
      'يوجد تطبيق يزيّف الموقع قيد التشغيل. أوقفه لتتمكن من تعبئة قوائم التحقق.';

  @override
  String get zonePermission =>
      'لا يمكن تعبئة قوائم التحقق إلا داخل النادي. اسمح لهذا التطبيق باستخدام موقعك الدقيق.';

  @override
  String get zoneServiceOff =>
      'خدمة الموقع متوقفة. شغّلها لتعبئة قوائم التحقق داخل النادي.';

  @override
  String get zoneUnavailable =>
      'تعذّر تحديد موقعك. حاول مرة أخرى، ويُفضَّل بالقرب من نافذة أو في مكان مفتوح.';

  @override
  String get zoneOpenSettings => 'فتح الإعدادات';

  @override
  String get zoneTurnOnLocation => 'تشغيل الموقع';

  @override
  String get zoneUnknown => 'اتصل بالإنترنت مرة واحدة لتحميل إعدادات النادي.';

  @override
  String get syncServerUnreachable =>
      'تعذّر الوصول إلى الخادم — تُعرض المهام المحفوظة';

  @override
  String syncLastUpdated(String time) {
    return 'آخر تحديث $time';
  }

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonSave => 'حفظ';

  @override
  String get pushPermissionTitle => 'الإشعارات';

  @override
  String get pushPermissionReason =>
      'تصلك إشعارات عندما تُسند إليك جولة، أو يقترب موعد إغلاقها، أو تُعاد إليك للتعديل.';

  @override
  String get pushPermissionContinue => 'متابعة';

  @override
  String get pushOpen => 'فتح';

  @override
  String get parkedOpScan => 'مسح رمز QR';

  @override
  String get qrScanButton => 'مسح رمز QR';

  @override
  String qrScanToStart(String place) {
    return 'امسح رمز QR في $place للبدء';
  }

  @override
  String get qrScanTitle => 'امسح رمز QR للمكان';

  @override
  String get qrScanHint => 'وجّه الكاميرا نحو ملصق رمز QR في المكان.';

  @override
  String get qrWrongClub => 'رمز QR هذا تابع لنادٍ آخر.';

  @override
  String get qrNotInTask => 'رمز QR هذا ليس من أماكن هذه المهمة.';

  @override
  String get qrCameraReason =>
      'مسح رمز QR للمكان يحتاج إلى الكاميرا. اسمح بالوصول إلى الكاميرا ثم حاول مرة أخرى. إذا لم يعد أندرويد يطلب الإذن، فعّله من الإعدادات.';

  @override
  String get qrLocked => 'مقفل';

  @override
  String get groupPlacesLabel => 'الأماكن';

  @override
  String groupPlacesDone(int done, int total) {
    return 'الأماكن المنجزة: $done من $total';
  }

  @override
  String groupLockedCount(int count) {
    return 'المقفلة: $count';
  }

  @override
  String get signatureUseSaved => 'استخدم توقيعي';
}
