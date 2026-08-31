import 'assignment_item.dart';

/// Mirrors public.assignments_v (the view over `submissions`, per §2 of the
/// plan — table name kept as-is so the existing dashboard queries keep
/// working; `effective_status` is the derived, clock-based status and is
/// what the UI must read, never `status`.
class Assignment {
  final String id;
  final String assigneeId;
  final String assigneeName;
  final String titleEn;
  final String titleAr;
  final String? siteNameEn;
  final String? siteNameAr;
  final DateTime? scheduledDate;
  final String? windowStart; // 'HH:mm:ss', as returned by postgrest for `time`
  final String? windowEnd;
  final String status; // raw column
  final String
  effectiveStatus; // pending|in_progress|submitted|approved|rejected|expired
  final bool wasExtended;
  final String? extensionNote;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final bool lateSync;
  final String? signatureUrl;
  final String? reviewNote;
  final List<AssignmentItem> items;

  const Assignment({
    required this.id,
    required this.assigneeId,
    required this.assigneeName,
    required this.titleEn,
    required this.titleAr,
    required this.siteNameEn,
    required this.siteNameAr,
    required this.scheduledDate,
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
  });

  int get doneCount => items.where((i) => i.status == 'done').length;
  bool get canSubmit => items.isNotEmpty && items.every((i) => i.isSatisfied);
  bool get isReadOnly =>
      const {'submitted', 'approved', 'expired'}.contains(effectiveStatus);

  /// Reads a live `assignments_v` row (no `items` key — the repo attaches
  /// them separately via [copyWithItems]) or a cached row round-tripped
  /// through [Assignment.toCacheJson], which embeds them.
  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
    id: json['id'] as String,
    assigneeId: json['inspector_id'] as String,
    assigneeName: json['inspector_name'] as String? ?? '',
    titleEn: json['title_en'] as String? ?? '',
    titleAr: json['title_ar'] as String? ?? '',
    siteNameEn: json['site_name_en'] as String?,
    siteNameAr: json['site_name_ar'] as String?,
    scheduledDate: json['scheduled_date'] == null
        ? null
        : DateTime.parse(json['scheduled_date'] as String),
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
  );
}
