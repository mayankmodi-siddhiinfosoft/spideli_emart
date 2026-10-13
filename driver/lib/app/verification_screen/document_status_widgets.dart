import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/services/driver_document_status.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared pieces of the documents screens (the driver's own, the owner's
/// list and review): the same status labels and colours everywhere.

DsTone overallStatusTone(DocumentOverallStatus status) => switch (status) {
      DocumentOverallStatus.verified => DsTone.success,
      DocumentOverallStatus.actionRequired => DsTone.danger,
      DocumentOverallStatus.pending => DsTone.warning,
      DocumentOverallStatus.notSubmitted => DsTone.neutral,
    };

IconData overallStatusIcon(DocumentOverallStatus status) => switch (status) {
      DocumentOverallStatus.verified => Icons.verified_rounded,
      DocumentOverallStatus.actionRequired => Icons.error_outline_rounded,
      DocumentOverallStatus.pending => Icons.hourglass_top_rounded,
      DocumentOverallStatus.notSubmitted => Icons.upload_file_outlined,
    };

DsTone entryStatusTone(String status) => switch (status) {
      DocumentEntryStatus.approved => DsTone.success,
      DocumentEntryStatus.rejected || DocumentEntryStatus.expired => DsTone.danger,
      DocumentEntryStatus.pending => DsTone.warning,
      _ => DsTone.neutral,
    };

/// The overall status of a driver's documents (translated).
class DocumentOverallStatusChip extends StatelessWidget {
  final DocumentOverallStatus status;
  final bool small;

  const DocumentOverallStatusChip({super.key, required this.status, this.small = true});

  @override
  Widget build(BuildContext context) {
    return DsBadge(
      key: ValueKey('document-overall-${status.key}'),
      label: status.label.tr,
      tone: overallStatusTone(status),
      icon: overallStatusIcon(status),
      small: small,
    );
  }
}

/// The status of one document (translated).
class DocumentEntryStatusChip extends StatelessWidget {
  final String status;

  const DocumentEntryStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return DsStatusChip(key: ValueKey('document-entry-$status'), label: DocumentEntryStatus.label(status).tr, tone: entryStatusTone(status));
  }
}

/// The document type (`driver` / `vehicle`) of a required document.
class DocumentTypeBadge extends StatelessWidget {
  final String? type;

  const DocumentTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return DsBadge(
      label: DocumentTypeLabel.of(type).tr,
      tone: DsTone.brand,
      style: DsBadgeStyle.outline,
      icon: (type ?? '').trim() == 'vehicle' ? Icons.directions_car_outlined : Icons.badge_outlined,
      small: true,
    );
  }
}

/// The uploaded file(s) of a document as thumbnails; a tap opens the file
/// full screen (the Storage URL exactly as stored).
class DocumentFilesRow extends StatelessWidget {
  final String? frontImage;
  final String? backImage;
  final bool frontSide;
  final bool backSide;
  final String title;

  const DocumentFilesRow({super.key, required this.frontImage, required this.backImage, required this.frontSide, required this.backSide, required this.title});

  @override
  Widget build(BuildContext context) {
    final bool hasFront = (frontImage ?? '').trim().isNotEmpty;
    final bool hasBack = (backImage ?? '').trim().isNotEmpty;
    final bool showFront = frontSide || hasFront;
    final bool showBack = backSide || hasBack;
    if (!showFront && !showBack) return const SizedBox.shrink();
    return Row(
      children: [
        if (showFront) Expanded(child: _Thumb(url: frontImage, label: 'Front Side'.tr, title: title)),
        if (showFront && showBack) const DsGap(DsSpace.md),
        if (showBack) Expanded(child: _Thumb(url: backImage, label: 'Back Side'.tr, title: title)),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final String label;
  final String title;

  const _Thumb({required this.url, required this.label, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final String image = (url ?? '').trim();
    final bool has = image.isNotEmpty;
    return Semantics(
      button: has,
      label: '$title — $label',
      child: InkWell(
        onTap: has ? () => DocumentImageViewer.open(image, '$title — $label') : null,
        borderRadius: DsRadius.brMd,
        child: Container(
          height: 96,
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
          child: has
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: DsRadius.brMd,
                      child: CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (_, _, _) => const Icon(Icons.broken_image, size: 30),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                        child: Text(label, style: t.caption.copyWith(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                    const Center(child: Icon(Icons.zoom_in, color: Colors.white70, size: 28)),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file_outlined, color: c.textMuted, size: 22),
                      const DsGap(DsSpace.xxs),
                      Text(label, style: t.caption),
                      Text('No image'.tr, style: t.caption.withColor(c.textMuted)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// A document file full screen (pinch to zoom).
class DocumentImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const DocumentImageViewer({super.key, required this.url, required this.title});

  static void open(String url, String title) {
    if (url.trim().isEmpty) return;
    Get.to(() => DocumentImageViewer(url: url, title: title), fullscreenDialog: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close'.tr, onPressed: () => Get.back()),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
            errorWidget: (_, _, _) => const Icon(Icons.broken_image, size: 48, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
