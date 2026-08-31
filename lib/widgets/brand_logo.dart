import 'package:flutter/material.dart';

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
      child: Image.asset('assets/owest.png', fit: BoxFit.cover),
    );
  }
}
