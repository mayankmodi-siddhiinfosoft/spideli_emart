import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:vendor/themes/ds/ds.dart';

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
        automaticallyImplyLeading: false,
        leading: const DsBackButton(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        color: Colors.black,
        child: Hero(
          tag: imageUrl,
          child: PhotoView(
            imageProvider: imageFile == null ? NetworkImage(imageUrl) : Image.file(imageFile!).image,
            loadingBuilder: (context, event) => const Center(child: DsSpinner(size: 32, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
