import 'dart:io';

import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// Archetype **K — full-bleed media**: black canvas, floating play control.
class FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;
  final String heroTag;
  final File? videoFile;

  const FullScreenVideoViewer({super.key, required this.videoUrl, required this.heroTag, this.videoFile});

  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.videoFile == null ? VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl)) : VideoPlayerController.file(widget.videoFile!)
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
    _controller.setLooping(true);
  }

  @override
  Widget build(BuildContext context) {
    final playing = _controller.value.isPlaying;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        automaticallyImplyLeading: false,
        leading: const Padding(
          padding: EdgeInsets.only(left: DsSpace.sm),
          child: DsBackButton(color: Colors.white),
        ),
      ),
      body: Container(
        color: Colors.black,
        child: Hero(
          tag: widget.videoUrl,
          child: Center(
            child: _controller.value.isInitialized
                ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
                : const DsBrandLoader(color: Colors.white),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: widget.heroTag,
        tooltip: playing ? 'Pause'.tr : 'Play'.tr,
        onPressed: () {
          setState(() {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          });
        },
        child: Icon(playing ? CupertinoIcons.pause : CupertinoIcons.play_arrow_solid, semanticLabel: playing ? 'Pause'.tr : 'Play'.tr),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
