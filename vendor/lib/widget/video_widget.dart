import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:video_player/video_player.dart';

/// True when [url] is something [VideoWidget] / [VideoAdvWidget] can open: a
/// [File], or an address that is not empty. A missing video used to throw
/// while the widget was built (`null` is not a `String`).
bool hasPlayableVideoSource(dynamic url) => url is File || (url is String && url.trim().isNotEmpty);

/// Neutral stand-in for a video that is missing or cannot be opened.
class VideoUnavailableBox extends StatelessWidget {
  const VideoUnavailableBox({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(child: Icon(Icons.videocam_off_outlined, size: 36, color: Colors.white.withValues(alpha: 0.7))),
    );
  }
}

class VideoWidget extends StatefulWidget {
  final dynamic url;
  final double width;

  const VideoWidget({super.key, this.width = 140, required this.url});

  @override
  VideoWidgetState createState() => VideoWidgetState();
}

class VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  /// False when [url] is neither a file nor a non-empty address; the widget
  /// then shows [VideoUnavailableBox] instead of throwing while it is built.
  late final bool _hasSource = hasPlayableVideoSource(widget.url);

  @override
  void initState() {
    super.initState();
    if (!_hasSource) return;
    _controller = widget.url is File ? VideoPlayerController.file(widget.url) : VideoPlayerController.network(widget.url as String);

    _initializeVideoPlayerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    if (_hasSource) _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: MediaQuery.of(context).size.height,
      child: !_hasSource
          ? const VideoUnavailableBox()
          : FutureBuilder(
              future: _initializeVideoPlayerFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const VideoUnavailableBox();
                if (snapshot.connectionState == ConnectionState.done) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        VideoPlayer(_controller),
                        Center(
                          child: InkWell(
                            onTap: () {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                              setState(() {});
                            },
                            child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
    );
  }
}

class VideoAdvWidget extends StatefulWidget {
  final dynamic url;
  final double width;
  final double? height;

  const VideoAdvWidget({super.key, this.height, this.width = 140, required this.url});

  @override
  VideoAdvWidgetState createState() => VideoAdvWidgetState();
}

class VideoAdvWidgetState extends State<VideoAdvWidget> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  /// False when [url] is neither a file nor a non-empty address; the widget
  /// then shows [VideoUnavailableBox] instead of throwing while it is built.
  late final bool _hasSource = hasPlayableVideoSource(widget.url);

  @override
  void initState() {
    super.initState();
    if (!_hasSource) return;
    _controller = widget.url is File ? VideoPlayerController.file(widget.url) : VideoPlayerController.network(widget.url as String);

    _initializeVideoPlayerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    if (_hasSource) _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height ?? MediaQuery.of(context).size.height,
      child: !_hasSource
          ? const VideoUnavailableBox()
          : FutureBuilder(
              future: _initializeVideoPlayerFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const VideoUnavailableBox();
                if (snapshot.connectionState == ConnectionState.done) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        VideoPlayer(_controller),
                        Center(
                          child: InkWell(
                            onTap: () {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                              setState(() {});
                            },
                            child: _controller.value.isPlaying == false ? SvgPicture.asset('assets/icons/ic_pause.svg') : Icon(Icons.pause, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
    );
  }
}
