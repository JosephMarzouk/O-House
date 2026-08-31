import 'package:flutter/material.dart';

/// The Broadsheet palette from the design handoff
/// (.design-preview-tmp/_ds/broadsheet-*/styles.css). Named for the role each
/// colour plays, not its hue — `magenta` is only ever rejected/overdue, and
/// nothing else in the app may reach for it.
abstract final class AppColors {
  /// accent-900 — the splash ground and every screen's header block.
  static const ink = Color(0xFF0E213F);

  /// accent — every primary action.
  static const cyan = Color(0xFF0088B0);

  /// accent-700 — link text and pressed primaries.
  static const cyanDark = Color(0xFF006786);

  /// accent-100 — the offline banner's ground.
  static const cyanTint = Color(0xFFE9F8FF);

  /// accent-2-700 — rejected and overdue only.
  static const magenta = Color(0xFFAA0B56);

  /// bg — every screen ground.
  static const paper = Color(0xFFF3F2F2);

  /// surface — input fill, cards.
  static const surface = Color(0xFFEAE9E9);

  /// text — body ink.
  static const text = Color(0xFF201E1D);

  static const divider = Color(0x29201E1D); // text @ 16%
}

/// Radius is 2px everywhere in Broadsheet — there are no rounded cards.
const kRadius = BorderRadius.all(Radius.circular(2));

/// Sized for gloves: nothing tappable falls below 44, primaries sit at 56.
const kControlHeight = 56.0;

/// The 11px uppercase tracked label that heads every field and section.
const kSectionLabel = TextStyle(
  fontSize: 11,
  height: 1,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.99, // .09em
  color: Color(0x80201E1D), // text @ 50%
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.cyan,
    primary: AppColors.cyan,
    onPrimary: AppColors.paper,
    secondary: AppColors.magenta,
    error: AppColors.magenta,
    surface: AppColors.paper,
    onSurface: AppColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    // Source Serif 4 covers Latin; Arabic falls through to Noto Naskh, so one
    // TextTheme serves both locales without a per-locale branch.
    fontFamily: 'Source Serif 4',
    fontFamilyFallback: const ['Noto Naskh Arabic'],
    dividerColor: AppColors.divider,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.68,
      ),
      headlineSmall: TextStyle(
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.52,
      ),
      titleMedium: TextStyle(
        fontSize: 19,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.3),
      bodyMedium: TextStyle(fontSize: 15, height: 1.4),
      bodySmall: TextStyle(fontSize: 13, height: 1.4),
      // Button text. It lives here rather than in filledButtonTheme's
      // `textStyle` because ButtonStyle *replaces* the text style instead of
      // merging it — a TextStyle passed to styleFrom carries no font family,
      // so the label falls back to the platform default and Arabic renders as
      // tofu. Set on the TextTheme, ThemeData applies the family and the
      // Arabic fallback for us.
      labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      labelSmall: kSectionLabel,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.paper,
      elevation: 0,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      constraints: BoxConstraints(minHeight: kControlHeight),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: kRadius,
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: kRadius,
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: kRadius,
        borderSide: BorderSide(color: AppColors.cyan),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.paper,
        minimumSize: const Size.fromHeight(kControlHeight),
        shape: const RoundedRectangleBorder(borderRadius: kRadius),
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: kRadius),
    ),
  );
}
