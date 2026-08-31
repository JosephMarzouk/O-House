import 'package:flutter/material.dart';

import 'brand_logo.dart';
import 'brand_wordmark.dart';

/// The full ink block: logo, wordmark, subtitle. Splash shows it centred on
/// a full screen; Login shows the exact same block in a collapsed header, so
/// the drag-up transition has nothing to cross-fade between (see
/// login_screen.dart). Home's header is different enough — logo moves to a
/// corner, the text is replaced entirely — that it animates the two pieces
/// separately instead of reusing this composite; see home_header.dart.
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 96, height: 96, child: BrandLogo()),
        SizedBox(height: 22),
        BrandWordmark(),
      ],
    );
  }
}
