import 'package:flutter/widgets.dart';

/// True once the one-time "ink panel unfurls into this screen's header"
/// hand-off animation has played this app session — on whichever of
/// LoginScreen or HomeScreen is shown first right after SplashScreen (signed
/// out lands on Login; already signed in lands on Home). Both check and flip
/// this in initState so neither replays the animation on a later visit —
/// back navigation, signing out and back in, returning from Tasks/Profile.
bool splashHandoffPlayed = false;

/// Set by Login immediately before it navigates to Home, to the height
/// Login's ink header is currently sitting at. Home consumes and clears it
/// in initState so the ink keeps *moving* — collapsing from Login's header
/// down to its own, shorter one — instead of cutting between two different
/// header sizes on the single frame where the route swaps.
double? loginHandoffFromHeight;

/// The splash's full-screen ink collapsing into a header.
const kSplashHandoffDuration = Duration(milliseconds: 1300);

/// Login to Home covers a couple of hundred pixels, not a whole screen.
/// Reusing the splash's 1300ms over that distance reads as a stall.
const kLoginHandoffDuration = Duration(milliseconds: 620);

/// Owns the "where does this screen's ink panel start, and how long does it
/// take to get home" decision for whichever screen mixes it in. Three cases:
///
/// - First screen after the splash — start full-screen, matching the splash's
///   last frame exactly, over [kSplashHandoffDuration].
/// - Home arriving from Login — start at Login's header height, over the
///   shorter [kLoginHandoffDuration].
/// - Any later visit — start collapsed and stay there. No replay.
mixin SplashHandoffAnimation<T extends StatefulWidget> on State<T> {
  bool _expanded = false;
  double? _expandedHeight;
  Duration _duration = kSplashHandoffDuration;

  bool get expanded => _expanded;

  /// Height the ink panel starts at, or null for the full screen.
  double? get expandedHeight => _expandedHeight;

  Duration get handoffDuration => _duration;

  @override
  void initState() {
    super.initState();
    if (!splashHandoffPlayed) {
      splashHandoffPlayed = true;
      _expanded = true;
      _expandedHeight = null; // full screen — the splash's last frame
    } else if (loginHandoffFromHeight != null) {
      _expanded = true;
      _expandedHeight = loginHandoffFromHeight;
      _duration = kLoginHandoffDuration;
      loginHandoffFromHeight = null;
    }

    if (_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _expanded = false);
      });
    }
  }
}
