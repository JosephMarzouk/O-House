import 'package:flutter/material.dart';

import '../club.dart';

/// The club mark on its own — no fixed size, so it can sit inside a plain
/// [SizedBox] (as part of [BrandPanel]) or inside an [AnimatedPositioned]
/// that tweens its box between two very different sizes (see home_header.dart)
/// without the image itself fighting the animation.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      // The signed-in club's own logo from the registry; the bundled mark
      // before a club is chosen, offline on a cold start, or if it fails.
      child: currentClub?.logoUrl == null
          ? Image.asset('assets/owest.png', fit: BoxFit.cover)
          : Image.network(
              currentClub!.logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Image.asset('assets/owest.png', fit: BoxFit.cover),
            ),
    );
  }
}
