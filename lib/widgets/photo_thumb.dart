import 'dart:io';

import 'package:flutter/material.dart';

import '../data/sync.dart';
import '../theme.dart';

/// Renders whatever shape an evidence path happens to be in — see [mediaUrl],
/// which owns that decision. Three reach here: a device path still queued in
/// the outbox, a bucket-relative path once this app has uploaded it, and a
/// full URL when the admin dashboard wrote the row.
///
/// The middle case is the one that used to break: `submit_assignment` stores
/// `signature_url` as the bare bucket path, this widget assumed anything
/// without `http` was a local file, and a submitted signature therefore always
/// rendered as the grey placeholder.
///
/// A path that will not load is normal here, not exceptional: the file may
/// still be queued, may have been cleared from the cache directory, or may be
/// a demo placeholder. So it falls back to the design's grey tile rather than
/// letting Image throw a red box into the middle of a checklist.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.path,
    this.size = 56,
    this.fit = BoxFit.cover,
  });

  final String path;
  final double size;

  /// `contain` for a signature strip, where cropping the stroke would be a
  /// lie about what was signed.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // Never throws into the tree: an unresolvable path is normal here, so a
    // failure to build a URL falls back to the placeholder like any other
    // missing image rather than taking the screen down.
    String? url;
    try {
      url = mediaUrl(path);
    } catch (_) {
      url = null;
    }
    Widget placeholder(_, _, _) => const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 22,
          color: Color(0x66201E1D), // text @ 40%
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? Image.network(url, fit: fit, errorBuilder: placeholder)
            : Image.file(File(path), fit: fit, errorBuilder: placeholder),
      ),
    );
  }
}
