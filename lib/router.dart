import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/assignments/detail_screen.dart';
import 'features/assignments/history_detail_screen.dart';
import 'features/assignments/list_screen.dart';
import 'features/assignments/signature_screen.dart';
import 'features/assignments/success_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/set_password_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'supabase.dart';

final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
  redirect: (context, state) {
    final loc = state.matchedLocation;
    // Splash owns the cold-boot routing decision, and login now owns the
    // post-sign-in one — must_change_password included — itself (see
    // login_screen.dart's _submit), so a redirect here would only ever be
    // racing it. Neither gets bounced by this rule.
    if (loc == '/splash' || loc == '/login') return null;

    final loggedIn = supabase.auth.currentSession != null;
    return loggedIn ? null : '/login';
  },
  routes: [
    GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
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
    GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
    GoRoute(path: '/tasks', builder: (c, s) => const TasksListScreen()),
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
      builder: (c, s) => const SuccessScreen(),
    ),
    GoRoute(
      path: '/history/:id',
      builder: (c, s) =>
          HistoryDetailScreen(assignmentId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
  ],
);

/// Bridges Supabase's auth stream to go_router's Listenable-based refresh —
/// the standard small adapter, not worth a package for ~10 lines.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
