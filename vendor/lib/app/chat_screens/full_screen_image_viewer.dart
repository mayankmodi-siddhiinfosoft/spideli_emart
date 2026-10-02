import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:vendor/themes/ds/ds.dart';

/// Full-screen, zoomable photo.
///
/// Never opens blank (report 02#7 family): with no file and no usable
/// `http(s)` URL it says the photo is unavailable, and a photo that fails to
/// load says so too instead of leaving a black page.
class FullScreenImageViewer extends StatelessWidget {
  /// Network address of the photo. Null, empty or not `http(s)` is treated as
  /// "no photo".
  final String? imageUrl;
  final File? imageFile;

  /// Shared-element tag. Must match the tag on the thumbnail that opened the
  /// viewer and be unique on that screen; when null the viewer falls back to
  /// [imageUrl] (the previous behaviour) and to no hero at all without one.
  final Object? heroTag;

  const FullScreenImageViewer({super.key, required this.imageUrl, this.imageFile, this.heroTag});

  /// True when [url] can be shown by this viewer.
  static bool canShow(String? url) {
    final String value = (url ?? '').trim();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// Opens the viewer for [url] when there is a photo to show; does nothing
  /// otherwise. Returns whether it opened.
  static bool open(String? url, {Object? heroTag}) {
    if (!canShow(url)) return false;
    Get.to(FullScreenImageViewer(imageUrl: url!.trim(), heroTag: heroTag));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasFile = imageFile != null;
    final bool hasUrl = canShow(imageUrl);
    final Object? tag = heroTag ?? (hasUrl ? imageUrl!.trim() : null);

    Widget content;
    if (!hasFile && !hasUrl) {
      content = const _ImageUnavailable();
    } else {
      content = PhotoView(
        imageProvider: hasFile ? FileImage(imageFile!) : NetworkImage(imageUrl!.trim()) as ImageProvider,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => const Center(child: DsSpinner(size: 32, color: Colors.white)),
        errorBuilder: (context, error, stackTrace) => const _ImageUnavailable(),
      );
      if (tag != null) content = Hero(tag: tag, child: content);
    }

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
      body: Container(color: Colors.black, child: content),
    );
  }
}

/// Shown on the black viewer background when there is no photo to display.
class _ImageUnavailable extends StatelessWidget {
  const _ImageUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hide_image_outlined, size: 56, color: Colors.white.withValues(alpha: 0.7)),
            const DsGap(DsSpace.md),
            Text(
              "Photo not available".tr,
              textAlign: TextAlign.center,
              style: context.dsText.bodyStrong.withColor(Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }
}
