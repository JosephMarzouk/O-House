import 'package:flutter/material.dart';

import '../tenant.dart';

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
      // This build's club (tenant.dart).
      child: Image.asset(tenant.logo, fit: BoxFit.cover),
    );
  }
}
