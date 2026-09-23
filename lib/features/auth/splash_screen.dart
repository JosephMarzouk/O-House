import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../models/profile.dart';
import '../../club.dart';
import '../../supabase.dart';
import '../../theme.dart';
import '../../widgets/brand_panel.dart';
import '../locale_provider.dart';

/// Restores the session (supabase_flutter does this from local storage during
/// initialize), loads the profile, applies the saved locale, then routes by
/// must_change_password (§6, screen 1).
///
/// Signed out, this hands off to `/login`, which opens with its ink panel at
/// full height — the same pixels this screen ends on — and drags it up into
/// its header. The seam is invisible, so the animation belongs entirely to
/// LoginScreen and nothing has to be coordinated across the route boundary.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    // This screen is only ever reached once per app process — cold boot,
    // GoRouter's fixed initialLocation — nothing routes back to it, so the
    // hold is unconditional.
    final hold = Future<void>.delayed(const Duration(seconds: 2));

    // No club yet (first launch, or after Switch club): its code comes first,
    // because sign-in happens against that club's own Supabase project.
    if (currentClub == null) {
      await hold;
      if (mounted) context.go('/club');
      return;
    }

    if (supabase.auth.currentSession == null) {
      await hold;
      if (mounted) context.go('/login');
      return;
    }

    // Fetch and hold run together, so a slow profile call eats into the 2s
    // rather than being added to it — and the splash never cuts to Home
    // before the must_change_password answer is in.
    final pending = ref.read(currentProfileProvider.future);
    await hold;

    Profile? profile;
    try {
      profile = await pending.timeout(const Duration(seconds: 3));
    } catch (_) {
      // Swallowed on purpose — see below.
    }
    if (!mounted) return;

    if (profile == null) {
      context.go('/home');
      return;
    }

    ref.read(localeProvider.notifier).set(profile.locale);
    context.go(profile.mustChangePassword ? '/set-password' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(bottom: false, child: Center(child: BrandPanel())),
      ),
    );
  }
}
