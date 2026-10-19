import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Video evidence is at most 1 MB (business rule, 19 Oct 2026), shrunk here
/// on the phone before it is kept: the upload over mobile data stays small,
/// the outbox holds 1 MB rather than 50, and it works offline. The API
/// refuses anything bigger (MAX_VIDEO_BYTES in o-house-api's
/// assignments.module.ts), so the two must move together.
const maxVideoBytes = 1024 * 1024;

/// The camera's limit. image_picker asks the camera app for it; most obey.
/// A longer clip (a camera that doesn't) keeps only its first 20 s: cleaners
/// keep their evidence rather than being asked to record it again.
const maxVideoSeconds = 20;

/// Video bitrates to try, in order. 20 s × (330 kbps picture + 48 kbps
/// sound) ≈ 0.95 MB, under the cap with room for the container. The second,
/// 70% of the first, is for a phone whose encoder overshoots.
const videoBitrates = [330000, 230000];

/// Shrinks [input] into [output] at a video bitrate; answers the new size.
typedef Compress = Future<int> Function(String input, String output, int videoBitrate);

/// The shrunk clip's path, or null when no attempt fits in [maxVideoBytes]
/// (an encoder that overshoots even the lower bitrate). Attempts that didn't
/// fit are deleted; an error (no encoder, unreadable clip) is the caller's.
Future<String?> shrinkVideo(String input, String tempDir, {Compress compress = compressVideo}) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  for (final (i, rate) in videoBitrates.indexed) {
    final out = p.join(tempDir, 'shrink-$stamp-$i.mp4');
    if (await compress(input, out, rate) <= maxVideoBytes) return out;
    try {
      await File(out).delete();
    } on FileSystemException {
      // Already gone: nothing to tidy.
    }
  }
  return null;
}

/// MainActivity.kt's compressVideo: Media3 Transformer, 480 p, H.264 + AAC,
/// the first [maxVideoSeconds] only.
const _channel = MethodChannel('o_house/app');

Future<int> compressVideo(String input, String output, int videoBitrate) async {
  final size = await _channel.invokeMethod<int>('compressVideo', {
    'input': input,
    'output': output,
    'videoBitrate': videoBitrate,
    'maxMs': maxVideoSeconds * 1000,
  });
  return size!;
}
