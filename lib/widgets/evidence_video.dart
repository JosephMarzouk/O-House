import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../data/providers.dart';
import '../theme.dart';

/// A clip is marked by its extension alone: `{id}.mp4` on the phone, and the
/// API stores it as `…-{id}.mp4`. A signed link keeps the path, then a query.
bool isVideoPath(String path) => RegExp(r'\.mp4($|\?)', caseSensitive: false).hasMatch(path);

/// The tile a clip shows where a photo would show its picture. No frame is
/// extracted: that would need another native plugin for a 48 px thumbnail.
class VideoTile extends StatelessWidget {
  const VideoTile({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: size,
      height: size,
      // Not const: ink is the tenant's brand colour, read at runtime.
      child: ColoredBox(
        color: AppColors.ink,
        child: const Center(
          child: Icon(Icons.play_circle_outline, size: 24, color: AppColors.paper),
        ),
      ),
    ),
  );
}

/// Plays a clip full screen: the file while it is still on this phone, else
/// the round's signed link (online only).
Future<void> openEvidenceVideo(
  BuildContext context,
  WidgetRef ref, {
  required String assignmentId,
  required String path,
}) async {
  final VideoPlayerController controller;
  if (p.isAbsolute(path) && File(path).existsSync()) {
    controller = VideoPlayerController.file(File(path));
  } else {
    final url = ref.read(roundMediaProvider(assignmentId)).valueOrNull?[path];
    if (url == null) return; // offline, or the link has not arrived yet
    controller = VideoPlayerController.networkUrl(Uri.parse(url));
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _VideoScreen(controller: controller),
    ),
  );
}

class _VideoScreen extends StatefulWidget {
  const _VideoScreen({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<_VideoScreen> {
  late final Future<void> _ready = widget.controller.initialize().then((_) {
    widget.controller.play();
  });

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: FutureBuilder<void>(
          future: _ready,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48);
            }
            if (snap.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator(color: Colors.white);
            }
            return GestureDetector(
              onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(c),
                    VideoProgressIndicator(c, allowScrubbing: true),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
