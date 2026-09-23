/// Mirrors public.assignment_items. Field names match the DB column names
/// (and, in turn, the templates.items JSON keys) exactly on purpose — see
/// §2 of the plan.
class AssignmentItem {
  final String id;
  final String assignmentId;
  final String textEn;
  final String textAr;

  /// yesno | pass_fail | number | text. Picks the answer control
  /// (subtask_tile.dart) and the answer's wire shape (normalizeAnswer).
  final String type;
  final bool critical; // display emphasis only — does not gate submission
  final bool requiresPhoto; // this is what submit_assignment() enforces
  final int sortOrder;

  /// pending | done | rejected | follow_up. follow_up is mark_item_done()'s
  /// verdict on an answer that missed [correct] (0013): answered, but wrong.
  final String status;
  final DateTime? doneAt;
  final String? note;
  final String? rejectNote;
  final List<String> photoPaths;

  /// The latest answer given — 'yes'|'no', 'pass'|'fail', a number as text,
  /// or free text. Null on anything ticked before 0013 captured answers.
  final String? answer;

  /// `{"eq": ...}` or `{"min": n, "max": n}`, or null for no rule. Judged
  /// server-side only (answer_ok() in 0013); the app reads it for one thing,
  /// telling a flagged item what was expected (formatCorrect).
  final Map<String, dynamic>? correct;

  /// The first wrong answer and when it was given. Kept after a re-answer
  /// clears the flag, as the history of what was fixed.
  final String? flaggedAnswer;
  final DateTime? flaggedAt;

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
    this.answer,
    this.correct,
    this.flaggedAnswer,
    this.flaggedAt,
  });

  bool get isSatisfied =>
      status == 'done' && (!requiresPhoto || photoPaths.isNotEmpty);

  /// Answered wrong against [correct]. Open for a new answer again, and what
  /// holds the round in follow_up until it is re-answered right.
  bool get isFollowUp => status == 'follow_up';

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
    answer: json['answer'] as String?,
    // A rule that is not an object is malformed, and answer_ok() never flags
    // on one — so it reads as no rule here too, rather than a failed cast
    // throwing inside refreshFromServer and blanking the whole task list.
    correct: json['correct'] is Map
        ? Map<String, dynamic>.from(json['correct'] as Map)
        : null,
    flaggedAnswer: json['flagged_answer'] as String?,
    flaggedAt: json['flagged_at'] == null
        ? null
        : DateTime.parse(json['flagged_at'] as String),
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
    'answer': answer,
    'correct': correct,
    'flagged_answer': flaggedAnswer,
    'flagged_at': flaggedAt?.toIso8601String(),
  };
}
