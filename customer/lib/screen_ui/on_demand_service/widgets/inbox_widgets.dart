import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';

/// Chat-inbox row shared by the provider and worker inboxes (archetype J).
class InboxRow extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String time;
  final String orderLabel;
  final VoidCallback onTap;

  const InboxRow({super.key, required this.name, required this.imageUrl, required this.time, required this.orderLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs),
      child: DsCard.outlined(
        onTap: onTap,
        padding: const EdgeInsets.all(DsSpace.md),
        semanticLabel: name,
        child: Row(
          children: [
            DsAvatar(imageUrl: imageUrl, name: name, size: 52, ring: true),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm)),
                      const DsGap(DsSpace.sm),
                      Text(time, style: t.caption.tabular),
                    ],
                  ),
                  const DsGap(DsSpace.xs),
                  Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 14, color: c.textMuted),
                      const DsGap(DsSpace.xs),
                      Expanded(child: Text(orderLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm)),
                    ],
                  ),
                ],
              ),
            ),
            const DsGap(DsSpace.sm),
            Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Single shimmer placeholder used while a conversation's profile loads.
class InboxRowSkeleton extends StatelessWidget {
  const InboxRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
      child: DsShimmer(
        child: Row(
          children: [
            DsSkeleton.circle(size: 52),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [DsSkeleton.line(width: 140), const DsGap(DsSpace.sm), DsSkeleton.line(width: 200, height: 10)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Initial loading state for the inbox lists.
class InboxListSkeleton extends StatelessWidget {
  const InboxListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: DsSpace.md),
      child: DsSkeletonList(itemCount: 7, trailing: false),
    );
  }
}
