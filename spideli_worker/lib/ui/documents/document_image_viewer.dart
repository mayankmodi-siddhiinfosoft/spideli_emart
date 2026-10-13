import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:spideliworker/themes/ds/ds.dart';

/// A document image full screen, zoomable. The Storage URL is used exactly as
/// stored (already percent-encoded; never re-encoded).
class DocumentImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const DocumentImageViewer({super.key, required this.url, required this.title});

  static void open(String url, String title) => Get.to(() => DocumentImageViewer(url: url, title: title));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title)),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(child: DsImage(url: url, fit: BoxFit.contain, radius: 0)),
        ),
      ),
    );
  }
}

/// A tappable thumbnail of an uploaded document side; opens
/// [DocumentImageViewer].
class DocumentThumb extends StatelessWidget {
  final String url;
  final String label;

  const DocumentThumb({super.key, required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: label,
          child: InkWell(
            borderRadius: DsRadius.brMd,
            onTap: () => DocumentImageViewer.open(url, label),
            child: DsImage(url: url, height: 96, width: double.infinity, radius: DsRadius.md),
          ),
        ),
        const DsGap(DsSpace.xs),
        Text(label, style: t.caption),
      ],
    );
  }
}
