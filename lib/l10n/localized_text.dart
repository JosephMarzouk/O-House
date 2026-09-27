import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';
import 'app_localizations.dart';

/// Bilingual DB columns (title_en/title_ar, site_name_en/site_name_ar) come
/// back as a pair and either side can be empty. Prefer the current locale,
/// then fall back to the other language — rendering an empty string because
/// the Arabic column was never filled in is worse than showing English.
String pickLocalized(BuildContext context, String? arabic, String? english) {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
  final preferred = isAr ? arabic : english;
  if (preferred != null && preferred.isNotEmpty) return preferred;
  return (isAr ? english : arabic) ?? '';
}

/// `time` columns arrive from postgrest as 'HH:mm:ss'. The design shows a bare
/// '07:00 – 11:00' range with a clock icon rather than a labelled field, so
/// there is nothing here to translate.
String? formatWindow(String? start, String? end) {
  if (start == null || end == null) return null;
  return '${start.substring(0, 5)} – ${end.substring(0, 5)}';
}

/// 'Zone 1 Morning · Swimming pool · Wed 26 Aug · 07:00 – 11:00' — the line
/// under the title on both the task detail and the submission review headers.
/// The round leads because it is the outer context: a task is one place
/// inside it. Parts that are missing — a one-off task has no round — drop out
/// rather than leaving a dangling separator.
String assignmentSubtitle(BuildContext context, Assignment a) {
  final locale = Localizations.localeOf(context).toString();
  return <String>[
    pickLocalized(context, a.roundTitleAr, a.roundTitleEn),
    pickLocalized(context, a.siteNameAr, a.siteNameEn),
    if (a.scheduledDate != null)
      a.endDate == null
          ? DateFormat('EEE d MMM', locale).format(a.scheduledDate!)
          // A multi-day task: "Wed 23 Sep – Fri 25 Sep".
          : '${DateFormat('EEE d MMM', locale).format(a.scheduledDate!)}'
                ' – ${DateFormat('EEE d MMM', locale).format(a.endDate!)}',
    ?formatWindow(a.windowStart, a.windowEnd),
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// An answer the way a person should read it. yes/no and pass/fail are stored
/// as those English keywords whatever the app's language, so they are
/// translated here; a number or free text is shown exactly as given.
String formatAnswer(BuildContext context, String answer) {
  final t = AppLocalizations.of(context)!;
  return switch (answer.trim().toLowerCase()) {
    'yes' => t.answerYes,
    'no' => t.answerNo,
    'pass' => t.answerPass,
    'fail' => t.answerFail,
    _ => answer,
  };
}

/// An item's `correct` rule, phrased as the expected answer: `{"eq": v}`
/// reads as [formatAnswer] reads v; a range as 1–3, ≥ 1 or ≤ 3 (in words in
/// Arabic); an exact value (min = max) as the bare number.
///
/// Null for no rule, and for a rule answer_ok() ignores — one with neither an
/// `eq` string nor a numeric bound. The server never flags on such a rule, so
/// there is no expectation to show. Bounds count only as JSON numbers, the
/// same jsonb_typeof check answer_ok() makes: a quoted "3" is no bound there
/// either.
String? formatCorrect(BuildContext context, Map<String, dynamic>? correct) {
  if (correct == null) return null;
  final eq = correct['eq'];
  if (eq is String) return formatAnswer(context, eq);

  // 3, not 3.0 — a whole bound can come back from jsonb as a float.
  String? bound(Object? n) =>
      n is num ? n.toString().replaceFirst(RegExp(r'\.0$'), '') : null;
  final t = AppLocalizations.of(context)!;
  return switch ((bound(correct['min']), bound(correct['max']))) {
    (null, null) => null,
    (final min?, null) => t.answerAtLeast(min),
    (null, final max?) => t.answerAtMost(max),
    (final min?, final max?) when min == max => min,
    (final min?, final max?) => t.answerRange(min, max),
  };
}
