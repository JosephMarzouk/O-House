import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/providers.dart';
import '../theme.dart';
import 'evidence_video.dart';

/// Renders one piece of evidence, whatever state it is in:
///
///  * a file on this phone: a photo or signature still in the outbox, or
///    staged on a round not yet submitted. Shown from disk, online or not.
///  * a stored path (or a legacy full URL): shown through the short-lived
///    signed link `GET /assignments/:id` returns for that round. The bucket
///    is private, so there is no public URL to build.
///
/// A path that will not load is normal here, not exceptional: offline, the
/// link has not arrived, or the object is missing. So it falls back to the
/// design's grey tile rather than letting Image throw a red box into the
/// middle of a checklist.
class PhotoThumb extends ConsumerWidget {
  const PhotoThumb({
    super.key,
    required this.assignmentId,
    required this.path,
    this.size = 56,
    this.fit = BoxFit.cover,
  });

  final String assignmentId;
  final String path;
  final double size;

  /// `contain` for a signature strip, where cropping the stroke would be a
  /// lie about what was signed.
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isVideoPath(path)) return VideoTile(size: size);

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

    final Widget image;
    // existsSync, not just isAbsolute: a stored path can carry a leading
    // slash ('/signatures/x.png'), and that one belongs to the server.
    if (p.isAbsolute(path) && File(path).existsSync()) {
      image = Image.file(File(path), fit: fit, errorBuilder: placeholder);
    } else {
      final url = ref.watch(roundMediaProvider(assignmentId)).valueOrNull?[path];
      image = url == null
          ? placeholder(null, null, null)
          : Image.network(url, fit: fit, errorBuilder: placeholder);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}
