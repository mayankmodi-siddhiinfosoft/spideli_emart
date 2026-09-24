import 'dart:io';

import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

/// Archetype **K — full-bleed media**: black canvas, floating chrome.
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final File? imageFile;

  const FullScreenImageViewer({super.key, required this.imageUrl, this.imageFile});

  @override
  Widget build(BuildContext context) {
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
          tag: imageUrl,
          child: PhotoView(
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            imageProvider: imageFile == null ? NetworkImage(imageUrl) : Image.file(imageFile!).image,
          ),
        ),
      ),
    );
  }
}
