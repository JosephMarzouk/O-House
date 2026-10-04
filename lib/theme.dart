import 'package:flutter/material.dart';

import 'tenant.dart';

/// The Broadsheet palette from the design handoff
/// (.design-preview-tmp/_ds/broadsheet-*/styles.css). Named for the role each
/// colour plays, not its hue — `magenta` is only ever an alarm state
/// (rejected, overdue, follow-up), and nothing else in the app may reach for
/// it.
///
/// The four brand colours come from this build's club (tenant.dart), so they
/// are `final`, not `const`. Everything else is shared by every club.
abstract final class AppColors {
  /// accent-900 — the splash ground and every screen's header block.
  static final ink = tenant.ink;

  /// accent — every primary action.
  static final cyan = tenant.accent;

  /// accent-700 — link text and pressed primaries.
  static final cyanDark = tenant.accentDark;

  /// accent-100 — the offline banner's ground.
  static final cyanTint = tenant.accentTint;

  /// Text and icons on a [cyan] fill. White for most clubs; a club whose
  /// accent is too light for white (RYZE's orange) gets its ink instead.
  static final onCyan = tenant.onAccent;

  /// accent-2-700 — rejected, overdue and follow-up only.
  static const magenta = Color(0xFFAA0B56);

  /// accent-2-100 — ground for the expired/rejected stat tile, and for
  /// everything follow-up: the chip, a flagged item's note, the success hero.
  static const magentaTint = Color(0xFFFFF1F4);

  /// accent-2-900 — label text on [magentaTint]; needs the extra depth
  /// [magenta] doesn't have to stay legible at small sizes.
  static const magentaDeep = Color(0xFF4B1528);

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

// ponytail: not in the design tokens — the floating nav bar and stat tiles
// are the only elements that lift off the paper, and nothing in the source
// export specifies their radius. 20px is a placeholder; eyeball-tune against
// the real nav bar before shipping.
const kRadiusFloating = BorderRadius.all(Radius.circular(20));

// ponytail: Broadsheet's own spec is flat (kRadius, 2px, "no rounded
// cards") — these two break from it on request. kRadiusControl covers every
// interactive control at kControlHeight (buttons, text fields, the language
// toggle); cards stay flat, as the handoff defines them.
const kRadiusControl = BorderRadius.all(Radius.circular(16));

/// Bottom corners only — a header sits flush against the top of the screen,
/// so only the edge that meets the paper body reads as rounded.
const kRadiusHeader = BorderRadius.vertical(bottom: Radius.circular(28));

/// `--shadow-md` — the floating nav bar and stat tiles.
const kShadowMd = BoxShadow(
  color: Color(0x292D2B2B),
  offset: Offset(0, 3),
  blurRadius: 10,
);

/// Sized for gloves: nothing tappable falls below 44, primaries sit at 56.
const kControlHeight = 56.0;

/// The minimum every screen's ink header stands below the status bar.
/// AppHeader treats it as a floor, not a fixed size — a header whose content
/// genuinely needs more room (Tasks' tab row, a task's progress bar) still
/// grows past it.
const kHeaderContentHeight = 140.0;

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
    onPrimary: AppColors.onCyan,
    secondary: AppColors.magenta,
    error: AppColors.magenta,
    surface: AppColors.paper,
    onSurface: AppColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    // Montserrat (the clubs' brand face) covers Latin; Arabic falls through to
    // Noto Naskh, so one TextTheme serves both locales without a per-locale
    // branch.
    fontFamily: 'Montserrat',
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
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.paper,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusHeader),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      constraints: const BoxConstraints(minHeight: kControlHeight),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: const OutlineInputBorder(
        borderRadius: kRadiusControl,
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: kRadiusControl,
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: kRadiusControl,
        borderSide: BorderSide(color: AppColors.cyan),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.onCyan,
        minimumSize: const Size.fromHeight(kControlHeight),
        shape: const RoundedRectangleBorder(borderRadius: kRadiusControl),
      ),
    ),
    // Text-only buttons are link text on paper, so they take cyanDark: base
    // cyan is too light to read there for some clubs (RYZE's orange, 1.9:1).
    // Without this they fall back to colorScheme.primary, which is cyan.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.cyanDark),
    ),
    // Without this an OutlinedButton falls back to Material's ~40px stadium,
    // so any pair of one filled and one outlined button — Clear and Submit on
    // the signature screen — comes out visibly mismatched in both height and
    // corner. Matching filledButtonTheme here fixes every such pair at once.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.cyanDark,
        minimumSize: const Size.fromHeight(kControlHeight),
        side: const BorderSide(color: AppColors.divider),
        shape: const RoundedRectangleBorder(borderRadius: kRadiusControl),
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: kRadius),
    ),
  );
}
