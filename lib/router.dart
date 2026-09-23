import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/assignments/detail_screen.dart';
import 'features/assignments/history_detail_screen.dart';
import 'features/assignments/list_screen.dart';
import 'features/assignments/signature_screen.dart';
import 'features/assignments/success_screen.dart';
import 'club.dart';
import 'features/auth/club_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/set_password_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'supabase.dart';
import 'theme.dart';
import 'widgets/app_nav_bar.dart';

final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: AuthRefresh(),
  redirect: (context, state) {
    final loc = state.matchedLocation;
    // Splash owns the cold-boot routing decision, and login now owns the
    // post-sign-in one — must_change_password included — itself (see
    // login_screen.dart's _submit), so a redirect here would only ever be
    // racing it. Neither gets bounced by this rule.
    if (loc == '/splash' || loc == '/club') return null;
    // No club, no Supabase: nothing else can even ask who is signed in.
    if (currentClub == null) return '/club';
    if (loc == '/login') return null;

    final loggedIn = supabase.auth.currentSession != null;
    return loggedIn ? null : '/login';
  },
  routes: [
    GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
    GoRoute(path: '/club', builder: (c, s) => const ClubScreen()),
    // No transition: /login opens with its ink panel at full height, exactly
    // the pixels the splash ends on, and drags it up itself. Any route
    // animation here would show as a seam mid-drag.
    GoRoute(
      path: '/login',
      pageBuilder: (c, s) => const NoTransitionPage(child: LoginScreen()),
    ),
    GoRoute(
      path: '/set-password',
      builder: (c, s) => const SetPasswordScreen(),
    ),

    // The three peer destinations. indexedStack keeps every branch alive, so
    // switching tabs preserves each one's scroll offset and the tasks search
    // field, and none of them shows a back arrow — at a branch root there is
    // nothing to pop, so AppBar.automaticallyImplyLeading finds nothing.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        backgroundColor: AppColors.paper,
        // The branches paint *under* the floating bar, so Home's ink panel
        // can still reach the bottom of the screen during the splash
        // hand-off. Scrollables owe their last row navBarExtent() of padding.
        extendBody: true,
        body: shell,
        bottomNavigationBar: AppNavBar(shell: shell),
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            // No transition, for the same reason /login has none: Home opens
            // with its ink panel already at Login's header height and drags
            // it down itself. A route animation would slide the whole screen
            // across that motion and show as a seam.
            GoRoute(
              path: '/home',
              pageBuilder: (c, s) =>
                  const NoTransitionPage(child: HomeScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/tasks', builder: (c, s) => const TasksListScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          ],
        ),
      ],
    ),

    // Full-screen work, deliberately outside the shell: declared top-level
    // rather than nested under the branch's /tasks precisely so they do not
    // inherit the nav bar. These are pushed, and keep their back arrow.
    GoRoute(
      path: '/tasks/:id',
      builder: (c, s) =>
          TaskDetailScreen(assignmentId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/tasks/:id/signature',
      builder: (c, s) => SignatureScreen(assignmentId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/tasks/:id/success',
      builder: (c, s) => SuccessScreen(assignmentId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/history/:id',
      builder: (c, s) =>
          HistoryDetailScreen(assignmentId: s.pathParameters['id']!),
    ),
  ],
);

/// Re-runs the redirect on every sign-in/sign-out and every club change.
/// Supabase is re-initialized per club (club.dart), so the auth stream is
/// re-subscribed each time the club changes rather than taken once.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh() {
    clubChanges.addListener(_resubscribe);
    _resubscribe();
  }
  StreamSubscription<AuthState>? _sub;

  void _resubscribe() {
    _sub?.cancel();
    _sub = currentClub == null
        ? null
        : supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
    notifyListeners();
  }

  @override
  void dispose() {
    clubChanges.removeListener(_resubscribe);
    _sub?.cancel();
    super.dispose();
  }
}
