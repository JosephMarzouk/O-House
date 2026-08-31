/// Mirrors public.assignment_items. Field names match the DB column names
/// (and, in turn, the templates.items JSON keys) exactly on purpose — see
/// §2 of the plan.
class AssignmentItem {
  final String id;
  final String assignmentId;
  final String textEn;
  final String textAr;
  final String type; // currently always 'yesno'
  final bool critical; // display emphasis only — does not gate submission
  final bool requiresPhoto; // this is what submit_assignment() enforces
  final int sortOrder;
  final String status; // pending | done | rejected
  final DateTime? doneAt;
  final String? note;
  final String? rejectNote;
  final List<String> photoPaths;

  const AssignmentItem({
    required this.id,
    required this.assignmentId,
    required this.textEn,
    required this.textAr,
    required this.type,
    required this.critical,
    required this.requiresPhoto,
    required this.sortOrder,
    required this.status,
    required this.doneAt,
    required this.note,
    required this.rejectNote,
    required this.photoPaths,
  });

  bool get isSatisfied =>
      status == 'done' && (!requiresPhoto || photoPaths.isNotEmpty);

  factory AssignmentItem.fromJson(Map<String, dynamic> json) => AssignmentItem(
    id: json['id'] as String,
    assignmentId: json['assignment_id'] as String,
    textEn: json['text_en'] as String? ?? '',
    textAr: json['text_ar'] as String? ?? '',
    type: json['type'] as String? ?? 'yesno',
    critical: json['critical'] as bool? ?? false,
    requiresPhoto: json['requires_photo'] as bool? ?? false,
    sortOrder: json['sort_order'] as int? ?? 0,
    status: json['status'] as String? ?? 'pending',
    doneAt: json['done_at'] == null
        ? null
        : DateTime.parse(json['done_at'] as String),
    note: json['note'] as String?,
    rejectNote: json['reject_note'] as String?,
    photoPaths: (json['photo_paths'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'assignment_id': assignmentId,
    'text_en': textEn,
    'text_ar': textAr,
    'type': type,
    'critical': critical,
    'requires_photo': requiresPhoto,
    'sort_order': sortOrder,
    'status': status,
    'done_at': doneAt?.toIso8601String(),
    'note': note,
    'reject_note': rejectNote,
    'photo_paths': photoPaths,
  };
}
