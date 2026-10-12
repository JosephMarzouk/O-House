import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/providers.dart';
import '../l10n/app_localizations.dart';
import '../router.dart';

/// Push notifications (plan Step 5, PRD §12).
///
/// The server decides who hears what and renders the text in the person's
/// language (`o-house-api/src/notifications`). The phone only:
///   * hands its FCM token to `PUT /me/devices` while someone is signed in,
///     and takes it back at sign-out (PN-1);
///   * asks for permission once Home is up, with a one-line reason (PN-2);
///   * in the foreground, shows a banner and refreshes the rounds (PN-7);
///   * on a tap, opens what `data.open` names: the round, Tasks, or Home.
///
/// Each club is its own Firebase project, read from its flavor's
/// `android/app/src/<flavor>/google-services.json`. A club without one (no
/// project yet) starts with push off and everything else unchanged.

/// Whether Firebase started. False in tests, on web, and for a club whose
/// flavor has no google-services.json.
bool pushAvailable = false;

/// The route a tap asked for while the app was not running. Splash and Login
/// open it after their own checks (signed in, profile, locale), never before.
String? pendingPushRoute;

/// The ScaffoldMessenger the foreground banner goes to (set on MaterialApp).
final pushMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> initPush() async {
  try {
    await Firebase.initializeApp();
    pushAvailable = true;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) pendingPushRoute = routeFor(initial.data);
  } catch (e) {
    debugPrint('[push] off: $e');
  }
}

/// Where a push's `data` sends a tap. Null: stay where the app opens.
String? routeFor(Map<String, dynamic> data) {
  final id = data['assignmentId'];
  return switch (data['open']) {
    'task' when id is String && id.isNotEmpty => '/tasks/$id',
    'tasks' => '/tasks',
    'home' => '/home',
    _ => null,
  };
}

/// Opens [route] over Home: a round is pushed (back returns to Home), a tab
/// is gone to. Home is where Splash and Login just went, so its hand-off
/// animation still plays first.
void openPushRoute(String? route) {
  if (route == null || route == '/home') return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    route.startsWith('/tasks/') ? router.push(route) : router.go(route);
  });
}

/// Splash and Login call this right after `go('/home')`.
void openPendingPushRoute() {
  final route = pendingPushRoute;
  pendingPushRoute = null;
  openPushRoute(route);
}

String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

/// Alive while someone is signed in (app.dart listens to it): registers the
/// token, follows Firebase's token rotation, and handles pushes that arrive
/// in the foreground or are tapped from the background.
final pushServiceProvider = Provider<void>((ref) {
  if (!pushAvailable) return;
  if (ref.watch(userIdProvider) == null) return;
  final api = ref.read(apiClientProvider);
  final messaging = FirebaseMessaging.instance;

  // Best effort: offline now, sent again at the next start or sign-in.
  Future<void> register(String token) async {
    try {
      await api.put('/me/devices', json: {'token': token, 'platform': _platform});
    } catch (e) {
      debugPrint('[push] register failed: $e');
    }
  }

  final subs = [
    messaging.onTokenRefresh.listen(register),
    FirebaseMessaging.onMessage.listen((m) {
      ref.invalidate(roundsRefreshProvider);
      _showBanner(m);
    }),
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      ref.invalidate(roundsRefreshProvider);
      openPushRoute(routeFor(m.data));
    }),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });

  unawaited(() async {
    try {
      final token = await messaging.getToken();
      if (token != null) await register(token);
    } catch (e) {
      debugPrint('[push] no token: $e');
    }
  }());
});

/// At sign-out, before the session goes (the DELETE needs it). Bounded: an
/// offline sign-out must not hang. If it fails, the next person to sign in on
/// this phone takes the token over, and FCM retires a deleted one.
Future<void> unregisterPush(ApiClient api) async {
  if (!pushAvailable) return;
  try {
    await () async {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await api.delete('/me/devices/${Uri.encodeComponent(token)}');
      await FirebaseMessaging.instance.deleteToken();
    }().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('[push] unregister failed: $e');
  }
}

bool _askedThisRun = false;

/// PN-2: once Home is up, a one-line reason, then the system's own prompt.
/// Asked only while undecided: after a yes or a no, Android doesn't ask
/// again, and neither do we. The app works the same without it.
Future<void> askPushPermission(BuildContext context) async {
  if (!pushAvailable || _askedThisRun) return;
  _askedThisRun = true;
  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.getNotificationSettings();
  if (settings.authorizationStatus != AuthorizationStatus.notDetermined) return;
  if (!context.mounted) return;
  final t = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(t.pushPermissionTitle),
      content: Text(t.pushPermissionReason),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t.pushPermissionContinue))],
    ),
  );
  await messaging.requestPermission();
}

/// A push while the app is open: Android shows nothing by itself, so a
/// banner says it, with Open when it points somewhere.
void _showBanner(RemoteMessage m) {
  final messenger = pushMessengerKey.currentState;
  final context = pushMessengerKey.currentContext;
  final n = m.notification;
  if (messenger == null || context == null || n == null) return;
  final route = routeFor(m.data);
  final t = AppLocalizations.of(context);
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.title != null)
            Text(n.title!, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (n.body != null) Text(n.body!),
        ],
      ),
      action: route == null || t == null
          ? null
          : SnackBarAction(label: t.pushOpen, onPressed: () => openPushRoute(route)),
    ),
  );
}
