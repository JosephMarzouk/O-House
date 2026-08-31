import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// "O House" + the subtitle, no logo — split out from [BrandPanel] so Home's
/// header can crossfade just the text while the logo glides independently
/// (see home_header.dart).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t.appName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: AppColors.paper),
        ),
        const SizedBox(height: 7),
        Text(
          t.loginSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: Color(0xA6F3F2F2),
          ),
        ),
      ],
    );
  }
}
