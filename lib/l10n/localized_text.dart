import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';

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

/// 'Swimming pool · Wed 26 Aug · 07:00 – 11:00' — the line under the title on
/// both the task detail and the submission review headers. Parts that are
/// missing drop out rather than leaving a dangling separator.
String assignmentSubtitle(BuildContext context, Assignment a) {
  final locale = Localizations.localeOf(context).toString();
  return <String>[
    pickLocalized(context, a.siteNameAr, a.siteNameEn),
    if (a.scheduledDate != null)
      DateFormat('EEE d MMM', locale).format(a.scheduledDate!),
    ?formatWindow(a.windowStart, a.windowEnd),
  ].where((s) => s.isNotEmpty).join(' · ');
}
