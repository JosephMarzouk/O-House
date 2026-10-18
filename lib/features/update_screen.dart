import 'package:flutter/material.dart';

import '../app_release.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

/// F-11 / MOB-01: this build is too old for the API. Shown over everything
/// (router.dart) until the app is replaced; there is no way past it, on
/// purpose. Unsent work stays on the phone and goes out after the update.
class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final url = upgradeRequired.value ?? '';
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.system_update, size: 56, color: AppColors.ink),
              const SizedBox(height: 20),
              Text(
                t.updateTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(t.updateBody, textAlign: TextAlign.center),
              const SizedBox(height: 28),
              if (url.isNotEmpty)
                FilledButton(onPressed: () => openUpdateLink(url), child: Text(t.updateDownload))
              else
                Text(t.updateAskSupervisor, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
