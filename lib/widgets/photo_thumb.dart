import 'dart:io';

import 'package:flutter/material.dart';

/// Renders a local file path or a remote URL the same way — the outbox
/// stores local paths until sync.dart uploads them (§7C), so a thumbnail
/// may be either at any given moment.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.path, this.size = 56});
  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isRemote = path.startsWith('http');
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: isRemote
            ? Image.network(path, fit: BoxFit.cover)
            : Image.file(File(path), fit: BoxFit.cover),
      ),
    );
  }
}
