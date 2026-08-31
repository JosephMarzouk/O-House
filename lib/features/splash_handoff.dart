import 'package:flutter/widgets.dart';

/// True once the one-time "ink panel unfurls into this screen's header"
/// hand-off animation has played this app session — on whichever of
/// LoginScreen or HomeScreen is shown first right after SplashScreen (signed
/// out lands on Login; already signed in lands on Home). Both check and flip
/// this in initState so neither replays the animation on a later visit —
/// back navigation, signing out and back in, returning from Tasks/Profile.
bool splashHandoffPlayed = false;

/// Owns that one-shot decision for whichever screen mixes it in: `expanded`
/// starts true only if this screen is the first to claim the hand-off, then
/// flips false on the next frame so [InkHandoffPanel] can animate the
/// collapse. A later visit sees the flag already claimed and starts (and
/// stays) collapsed — no replay.
mixin SplashHandoffAnimation<T extends StatefulWidget> on State<T> {
  bool _expanded = true;
  bool get expanded => _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !splashHandoffPlayed;
    splashHandoffPlayed = true;
    if (_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _expanded = false);
      });
    }
  }
}
