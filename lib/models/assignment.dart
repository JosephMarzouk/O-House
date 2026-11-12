import 'assignment_item.dart';

/// How long before its window a checklist opens on the phone (decided
/// 12 Nov: a 10:00 checklist opens at 09:55).
const kOpenEarly = Duration(minutes: 5);

/// Mirrors public.assignments_v (the view over `submissions`, per §2 of the
/// plan — table name kept as-is so the existing dashboard queries keep
/// working; `effective_status` is the derived, clock-based status and is
/// what the UI must read, never `status`.
class Assignment {
  final String id;

  /// The owner: the one assignee, or whichever of several acted first. Null
  /// while a task given to several people is still unclaimed.
  final String? assigneeId;
  final String assigneeName;
  final String titleEn;
  final String titleAr;
  final String? siteNameEn;
  final String? siteNameAr;
  final DateTime? scheduledDate;

  /// The last day of a multi-day task; null for a one-day task.
  final DateTime? endDate;
  final String? windowStart; // 'HH:mm:ss', as returned by postgrest for `time`
  final String? windowEnd;
  final String status; // raw column
  final String effectiveStatus; // pending|in_progress|submitted|approved|rejected|expired|follow_up
  final bool wasExtended;
  final String? extensionNote;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final bool lateSync;
  final String? signatureUrl;
  final String? reviewNote;
  final List<AssignmentItem> items;

  /// When the window closes: the view's `deadline` (Cairo time, overnight
  /// windows and extensions included). Null for a round with no window.
  final DateTime? deadline;

  /// The creator's instructions, and the note staff sent with the submit.
  final String? taskNote;
  final String? submitNote;

  /// The zone round this place was scheduled from (0013), via the view's
  /// LEFT JOIN — null for a one-off task or a legacy row. Display only: the
  /// card's kicker and the head of the subtitle. Grouping goes by [groupId],
  /// which covers a round and a one-off multi-place task alike.
  final String? roundTitleEn;
  final String? roundTitleAr;

  /// QR-locked places (20261028123023_qr_places). The place's "Requires QR
  /// scan" switch, copied onto the checklist when it was created, so a
  /// checklist already handed out never starts locking mid-day.
  final bool qrRequired;

  /// The multi-place task this checklist is one place of: the zone round or
  /// the one-off task group (the view's `coalesce(round_id, task_group_id)`).
  /// Null for a single checklist, and for every row from an API that predates
  /// QR places, which is what keeps those looking exactly as before.
  final String? groupId;
  final String? groupTitleEn;
  final String? groupTitleAr;

  /// How many checklists share [groupId] on the server; 1 outside a group.
  final int groupSize;

  /// This place's number in the task's walk order (1, 2, 3 …), as the admin
  /// set it: the New task form's order, or the zone round's. Null outside a
  /// task and from an older API. Walk order is only shown (QF).
  final int? groupPosition;

  /// sha256 of the place's QR code, lowercase hex; null unless [qrRequired].
  /// The phone matches a scan against it offline and never holds the code
  /// itself, so a cached round can't be used to print a working sticker.
  final String? qrHash;

  /// The server has an accepted scan or a supervisor's unlock for it.
  /// applyLocal also sets it while a scan is still queued on this phone.
  final bool unlocked;

  /// When the window starts: the view's `opens_at` (scheduled_date +
  /// window_start, Cairo time; the first day of a multi-day task). Null for a
  /// checklist with no window, and from an API older than 12 Nov: no gate.
  final DateTime? opensAt;

  const Assignment({
    required this.id,
    required this.assigneeId,
    required this.assigneeName,
    required this.titleEn,
    required this.titleAr,
    required this.siteNameEn,
    required this.siteNameAr,
    required this.scheduledDate,
    this.endDate,
    required this.windowStart,
    required this.windowEnd,
    required this.status,
    required this.effectiveStatus,
    required this.wasExtended,
    required this.extensionNote,
    required this.submittedAt,
    required this.completedAt,
    required this.lateSync,
    required this.signatureUrl,
    required this.reviewNote,
    this.items = const [],
    this.roundTitleEn,
    this.roundTitleAr,
    this.deadline,
    this.taskNote,
    this.submitNote,
    this.qrRequired = false,
    this.groupId,
    this.groupTitleEn,
    this.groupTitleAr,
    this.groupSize = 1,
    this.groupPosition,
    this.qrHash,
    this.unlocked = false,
    this.opensAt,
  });

  int get doneCount => items.where((i) => i.status == 'done').length;
  bool get canSubmit => items.isNotEmpty && items.every((i) => i.isSatisfied);

  /// follow_up is deliberately absent here and from [terminalStatuses]: a
  /// round in follow_up is both editable and outstanding — it was sent, but
  /// its flagged answers are this person's to fix, and it never expires.
  bool get isReadOnly =>
      const {'submitted', 'approved', 'expired'}.contains(effectiveStatus);

  /// Statuses past which the assignment needs no more work from the
  /// inspector. Distinct from [isReadOnly], which is about whether the
  /// *form* accepts edits — a rejected task is editable but not outstanding.
  static const terminalStatuses = {
    'submitted',
    'approved',
    'rejected',
    'expired',
  };

  bool get isTerminal => terminalStatuses.contains(effectiveStatus);

  /// Waiting for its place's QR: the items stay read-only until it is
  /// scanned (or a supervisor unlocks it on the portal). A checklist that can
  /// no longer be filled is only read, so it never shows as locked.
  bool get isLocked => qrRequired && !unlocked && !isReadOnly;

  /// When the phone opens it: [kOpenEarly] before the window starts.
  DateTime? get openTime => opensAt?.subtract(kOpenEarly);

  /// Not open yet at [now] — the server-corrected clock, so a phone set
  /// ahead can't open it early. Nothing can be done before [openTime], not
  /// even a QR scan. Only work still to start waits: a sent-back or finished
  /// checklist is never held back.
  bool isNotOpenAt(DateTime now) {
    final open = openTime;
    return open != null &&
        const {'pending', 'in_progress'}.contains(effectiveStatus) &&
        now.isBefore(open);
  }

  /// "09:55": [openTime] on the club's clock, the way the card shows the
  /// window (from window_start, so it never depends on the phone's time zone).
  String? get openClock {
    final s = windowStart;
    if (s == null || s.length < 5) return null;
    final m =
        (int.parse(s.substring(0, 2)) * 60 +
            int.parse(s.substring(3, 5)) -
            kOpenEarly.inMinutes) %
        1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:'
        '${(m % 60).toString().padLeft(2, '0')}';
  }

  /// One place of a task over several places: the Tasks list shows the task
  /// as one card and the places on /groups/:id. A group of one is just a
  /// checklist, and renders as one.
  bool get isGrouped => groupId != null && groupSize > 1;

  /// A place of a task counts as done once it is sent (QB: each place is
  /// submitted as it is finished). follow_up and rejected are sent back, so
  /// still to do.
  bool get isSent => effectiveStatus == 'submitted' || effectiveStatus == 'approved';

  bool get isToday => isTodayAt(DateTime.now());

  /// Today's work at [now]: on one of its days, or from an earlier day and
  /// still open. The second is an overnight window (22:00 → 01:00) after
  /// midnight: by day it is yesterday's, yet it can still be filled, so it
  /// must not drop into History until its [deadline] passes.
  bool isTodayAt(DateTime now) {
    if (isOnDay(now)) return true;
    final d = scheduledDate;
    final close = deadline;
    return d != null &&
        close != null &&
        !isTerminal &&
        close.isAfter(now) &&
        !DateTime(
          d.year,
          d.month,
          d.day,
        ).isAfter(DateTime(now.year, now.month, now.day));
  }

  /// [now]'s day falls between the first and the last day — one day, unless
  /// the task runs over several.
  bool isOnDay(DateTime now) {
    final d = scheduledDate;
    if (d == null) return false;
    final day = DateTime(now.year, now.month, now.day);
    final end = endDate ?? d;
    return !day.isBefore(DateTime(d.year, d.month, d.day)) &&
        !day.isAfter(DateTime(end.year, end.month, end.day));
  }

  /// Reads a live `assignments_v` row (no `items` key — the repo attaches
  /// them separately via [copyWithItems]) or a cached row round-tripped
  /// through [Assignment.toCacheJson], which embeds them.
  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
    id: json['id'] as String,
    assigneeId: json['inspector_id'] as String?,
    assigneeName: json['inspector_name'] as String? ?? '',
    titleEn: json['title_en'] as String? ?? '',
    titleAr: json['title_ar'] as String? ?? '',
    siteNameEn: json['site_name_en'] as String?,
    siteNameAr: json['site_name_ar'] as String?,
    scheduledDate: json['scheduled_date'] == null
        ? null
        : DateTime.parse(json['scheduled_date'] as String),
    endDate: json['end_date'] == null
        ? null
        : DateTime.parse(json['end_date'] as String),
    windowStart: json['window_start'] as String?,
    windowEnd: json['window_end'] as String?,
    status: json['status'] as String? ?? 'pending',
    effectiveStatus: json['effective_status'] as String? ?? 'pending',
    wasExtended: json['was_extended'] as bool? ?? false,
    extensionNote: json['extension_note'] as String?,
    submittedAt: json['submitted_at'] == null
        ? null
        : DateTime.parse(json['submitted_at'] as String),
    completedAt: json['completed_at'] == null
        ? null
        : DateTime.parse(json['completed_at'] as String),
    lateSync: json['late_sync'] as bool? ?? false,
    signatureUrl: json['signature_url'] as String?,
    reviewNote: json['review_note'] as String?,
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((e) => AssignmentItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    roundTitleEn: json['round_title_en'] as String?,
    roundTitleAr: json['round_title_ar'] as String?,
    deadline: json['deadline'] == null
        ? null
        : DateTime.parse(json['deadline'] as String),
    taskNote: json['task_note'] as String?,
    submitNote: json['submit_note'] as String?,
    // Absent from an API (or a cached row) older than QR places: all off.
    qrRequired: json['qr_required'] as bool? ?? false,
    groupId: json['group_id'] as String?,
    groupTitleEn: json['group_title_en'] as String?,
    groupTitleAr: json['group_title_ar'] as String?,
    groupSize: (json['group_size'] as num?)?.toInt() ?? 1,
    groupPosition: (json['group_position'] as num?)?.toInt(),
    qrHash: json['qr_hash'] as String?,
    unlocked: json['unlocked'] as bool? ?? false,
    opensAt: json['opens_at'] == null
        ? null
        : DateTime.parse(json['opens_at'] as String),
  );

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'inspector_id': assigneeId,
    'inspector_name': assigneeName,
    'title_en': titleEn,
    'title_ar': titleAr,
    'site_name_en': siteNameEn,
    'site_name_ar': siteNameAr,
    'scheduled_date': scheduledDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'window_start': windowStart,
    'window_end': windowEnd,
    'status': status,
    'effective_status': effectiveStatus,
    'was_extended': wasExtended,
    'extension_note': extensionNote,
    'submitted_at': submittedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'late_sync': lateSync,
    'signature_url': signatureUrl,
    'review_note': reviewNote,
    'items': items.map((i) => i.toJson()).toList(),
    'round_title_en': roundTitleEn,
    'round_title_ar': roundTitleAr,
    'deadline': deadline?.toIso8601String(),
    'task_note': taskNote,
    'submit_note': submitNote,
    'qr_required': qrRequired,
    'group_id': groupId,
    'group_title_en': groupTitleEn,
    'group_title_ar': groupTitleAr,
    'group_size': groupSize,
    'group_position': groupPosition,
    'qr_hash': qrHash,
    'unlocked': unlocked,
    'opens_at': opensAt?.toIso8601String(),
  };

  Assignment copyWithItems(List<AssignmentItem> items) => Assignment(
    id: id,
    assigneeId: assigneeId,
    assigneeName: assigneeName,
    titleEn: titleEn,
    titleAr: titleAr,
    siteNameEn: siteNameEn,
    siteNameAr: siteNameAr,
    scheduledDate: scheduledDate,
    endDate: endDate,
    windowStart: windowStart,
    windowEnd: windowEnd,
    status: status,
    effectiveStatus: effectiveStatus,
    wasExtended: wasExtended,
    extensionNote: extensionNote,
    submittedAt: submittedAt,
    completedAt: completedAt,
    lateSync: lateSync,
    signatureUrl: signatureUrl,
    reviewNote: reviewNote,
    items: items,
    roundTitleEn: roundTitleEn,
    roundTitleAr: roundTitleAr,
    deadline: deadline,
    taskNote: taskNote,
    submitNote: submitNote,
    qrRequired: qrRequired,
    groupId: groupId,
    groupTitleEn: groupTitleEn,
    groupTitleAr: groupTitleAr,
    groupSize: groupSize,
    groupPosition: groupPosition,
    qrHash: qrHash,
    unlocked: unlocked,
    opensAt: opensAt,
  );
}
