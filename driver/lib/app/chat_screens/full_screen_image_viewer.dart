import 'dart:io';

import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

/// Full-screen media viewer: edge-to-edge image on black, with a transparent
/// DS app bar over it.
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final File? imageFile;

  const FullScreenImageViewer({super.key, required this.imageUrl, this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: const DsAppBar(transparent: true),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            color: Colors.black,
            child: Hero(
              tag: imageUrl,
              child: PhotoView(
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                imageProvider: imageFile == null ? NetworkImage(imageUrl) : Image.file(imageFile!).image,
              ),
            ),
          ),
        ));
  }
}
