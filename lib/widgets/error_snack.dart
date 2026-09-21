import 'package:flutter/material.dart';

import '../theme.dart';

/// The one place a failure the user is waiting on becomes visible.
///
/// The submit path used to swallow everything: sqflite throws were unguarded
/// and SyncService.drain() catches its own errors by design, so a round that
/// could not be saved and a round that could not be sent looked identical to a
/// round that worked — the screen just sat there. That is what made "submit
/// does nothing, forever" impossible to diagnose from the device.
///
/// Deliberately not localized. These strings carry a raw exception for
/// diagnosis; they are not part of the EN/AR product copy, and inventing
/// translated wording for `PostgrestException(...)` would be pretending they
/// are. Replace with real per-signal copy when phase 4 surfaces sync failures
/// properly (see the TODO in sync.dart).
void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        backgroundColor: AppColors.magenta,
        // Long, because the useful part of a Postgrest message is at the end.
        duration: const Duration(seconds: 10),
        content: Text(message, style: const TextStyle(color: AppColors.paper)),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: AppColors.paper,
          onPressed: () => ScaffoldMessenger.of(context).clearSnackBars(),
        ),
      ),
    );
}
