import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:vendor/themes/ds/ds.dart';

class FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;
  final String heroTag;
  final File? videoFile;

  /// Shared-element tag of the video itself; defaults to [videoUrl] (the
  /// previous behaviour). Pass the thumbnail's tag when it is not the URL.
  final Object? mediaHeroTag;

  const FullScreenVideoViewer({super.key, required this.videoUrl, required this.heroTag, this.videoFile, this.mediaHeroTag});

  /// True when [url] is an `http(s)` address this viewer can stream.
  static bool canPlay(String? url) {
    final String value = (url ?? '').trim();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  @override
  _FullScreenVideoViewerState createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  VideoPlayerController? _controller;

  /// Set when there is nothing to play or the video could not be opened, so
  /// the page says so instead of spinning on a black screen forever.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoFile == null && !FullScreenVideoViewer.canPlay(widget.videoUrl)) {
      _failed = true;
      return;
    }
    final VideoPlayerController controller = widget.videoFile == null
        ? VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl.trim()))
        : VideoPlayerController.file(widget.videoFile!);
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
          if (mounted) setState(() {});
        })
        .catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        });
    controller.setLooping(true);
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: const DsBackButton(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        color: Colors.black,
        child: _failed || controller == null
            ? const _VideoUnavailable()
            : Hero(
                tag: widget.mediaHeroTag ?? widget.videoUrl,
                child: Center(
                  child: controller.value.isInitialized
                      ? AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller))
                      : const DsSpinner(size: 32, color: Colors.white),
                ),
              ),
      ),
      floatingActionButton: _failed || controller == null
          ? null
          : FloatingActionButton(
              heroTag: widget.heroTag,
              tooltip: controller.value.isPlaying ? 'Pause'.tr : 'Play'.tr,
              onPressed: () {
                setState(() {
                  controller.value.isPlaying ? controller.pause() : controller.play();
                });
              },
              child: Icon(controller.value.isPlaying ? CupertinoIcons.pause : CupertinoIcons.play_arrow_solid),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller?.dispose();
  }
}

/// Shown on the black viewer background when there is no video to play.
class _VideoUnavailable extends StatelessWidget {
  const _VideoUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, size: 56, color: Colors.white.withValues(alpha: 0.7)),
            const DsGap(DsSpace.md),
            Text(
              "Video not available".tr,
              textAlign: TextAlign.center,
              style: context.dsText.bodyStrong.withColor(Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }
}
