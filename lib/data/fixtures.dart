import '../models/assignment.dart';
import '../models/assignment_item.dart';

/// Dummy data for the widget tests and main_dev_preview.dart, which inject it
/// through provider overrides. The app itself never reads it.
///
/// Fixtures mirror artboard 1c of the design handoff so the screens can be
/// compared against it side by side: one assignment per status tag.

DateTime _day(int offsetDays) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offsetDays);
}

/// `done` items come first so a partially-finished round reads naturally.
List<AssignmentItem> _items(
  String assignmentId,
  List<(String, String)> texts, {
  required int done,
  Set<int> photoRequired = const {},
  Set<int> critical = const {},
  String? rejectedNote,
}) => [
  for (var i = 0; i < texts.length; i++)
    AssignmentItem(
      id: '$assignmentId-i$i',
      assignmentId: assignmentId,
      textEn: texts[i].$1,
      textAr: texts[i].$2,
      type: 'yesno',
      critical: critical.contains(i),
      requiresPhoto: photoRequired.contains(i),
      sortOrder: i,
      status: i < done
          ? 'done'
          : (rejectedNote != null && i == done ? 'rejected' : 'pending'),
      doneAt: i < done ? DateTime.now() : null,
      note: null,
      rejectNote: rejectedNote != null && i == done ? rejectedNote : null,
      photoPaths: const [],
    ),
];

Assignment _assignment({
  required String id,
  required String titleEn,
  required String titleAr,
  required String siteEn,
  required String siteAr,
  required DateTime date,
  required String windowStart,
  required String windowEnd,
  required String status,
  required List<AssignmentItem> items,
  String? reviewNote,
}) => Assignment(
  id: id,
  assigneeId: 'demo-user',
  assigneeName: 'Joseph Marzouk',
  titleEn: titleEn,
  titleAr: titleAr,
  siteNameEn: siteEn,
  siteNameAr: siteAr,
  scheduledDate: date,
  windowStart: windowStart,
  windowEnd: windowEnd,
  status: status == 'expired' ? 'in_progress' : status,
  effectiveStatus: status,
  wasExtended: false,
  extensionNote: null,
  submittedAt: status == 'submitted' || status == 'approved'
      ? DateTime.now()
      : null,
  completedAt: null,
  lateSync: false,
  signatureUrl: null,
  reviewNote: reviewNote,
  items: items,
);

List<Assignment> demoAssignments() => [
  _assignment(
    id: 'demo-1',
    titleEn: 'Morning round',
    titleAr: 'الجولة الصباحية',
    siteEn: 'Swimming pool',
    siteAr: 'حمام السباحة',
    date: _day(0),
    windowStart: '07:00:00',
    windowEnd: '11:00:00',
    status: 'in_progress',
    items: _items(
      'demo-1',
      const [
        ('Pool deck', 'حافة المسبح'),
        ('Changing rooms', 'غرف تغيير الملابس'),
        ('Showers', 'الاستحمام'),
        ('Sun loungers', 'كراسي التشمس'),
        ('Towel station', 'محطة المناشف'),
        ('Pool water check', 'فحص مياه المسبح'),
        ('Waste bins', 'صناديق النفايات'),
      ],
      done: 3,
      photoRequired: const {3, 5},
      critical: const {5},
    ),
  ),
  _assignment(
    id: 'demo-2',
    titleEn: 'Court turnover',
    titleAr: 'تجهيز الملعب',
    siteEn: 'Padel court',
    siteAr: 'ملعب البادل',
    date: _day(0),
    windowStart: '08:00:00',
    windowEnd: '09:30:00',
    status: 'expired',
    items: _items(
      'demo-2',
      const [
        ('Sweep the court', 'كنس الملعب'),
        ('Wipe the benches', 'تنظيف المقاعد'),
        ('Restock water', 'تعبئة المياه'),
        ('Check the net', 'فحص الشبكة'),
        ('Empty the bins', 'إفراغ الصناديق'),
      ],
      done: 0,
      photoRequired: const {0},
    ),
  ),
  _assignment(
    id: 'demo-3',
    titleEn: 'Midday wipe-down',
    titleAr: 'تنظيف منتصف اليوم',
    siteEn: 'Outdoor GYM',
    siteAr: 'الصالة الخارجية',
    date: _day(0),
    windowStart: '11:30:00',
    windowEnd: '13:00:00',
    status: 'rejected',
    reviewNote: '1 place returned by Joseph Marzouk',
    items: _items(
      'demo-3',
      const [
        ('Treadmills', 'أجهزة الجري'),
        ('Free weights', 'الأوزان الحرة'),
        ('Benches', 'المقاعد'),
        ('Mats', 'الحصائر'),
        ('Mirrors', 'المرايا'),
        ('Water fountain', 'نافورة المياه'),
      ],
      done: 5,
      photoRequired: const {5},
      rejectedNote: 'Streaks left on the glass — please redo.',
    ),
  ),
  _assignment(
    id: 'demo-4',
    titleEn: 'Evening close',
    titleAr: 'إغلاق المساء',
    siteEn: 'Squash court',
    siteAr: 'ملعب الاسكواش',
    date: _day(0),
    windowStart: '13:30:00',
    windowEnd: '15:00:00',
    status: 'submitted',
    items: _items('demo-4', const [
      ('Sweep the floor', 'كنس الأرضية'),
      ('Wipe the walls', 'تنظيف الجدران'),
      ('Check the lights', 'فحص الإضاءة'),
      ('Lock up', 'الإغلاق'),
    ], done: 4),
  ),
  _assignment(
    id: 'demo-5',
    titleEn: 'Lobby deep clean',
    titleAr: 'تنظيف عميق للبهو',
    siteEn: 'Main lobby',
    siteAr: 'البهو الرئيسي',
    date: _day(1),
    windowStart: '06:00:00',
    windowEnd: '09:00:00',
    status: 'pending',
    items: _items(
      'demo-5',
      const [
        ('Glass doors', 'الأبواب الزجاجية'),
        ('Reception desk', 'مكتب الاستقبال'),
        ('Seating area', 'منطقة الجلوس'),
        ('Floor polish', 'تلميع الأرضية'),
      ],
      done: 0,
      photoRequired: const {3},
    ),
  ),
  _assignment(
    id: 'demo-6',
    titleEn: 'Sauna reset',
    titleAr: 'تجهيز الساونا',
    siteEn: 'Spa',
    siteAr: 'المنتجع الصحي',
    date: _day(-6),
    windowStart: '16:00:00',
    windowEnd: '18:00:00',
    status: 'approved',
    items: _items('demo-6', const [
      ('Wooden benches', 'المقاعد الخشبية'),
      ('Stone tray', 'صينية الأحجار'),
      ('Floor drain', 'مصرف الأرضية'),
    ], done: 3),
  ),
];
