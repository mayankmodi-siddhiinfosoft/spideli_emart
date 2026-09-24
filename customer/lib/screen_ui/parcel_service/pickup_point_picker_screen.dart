import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/screen_ui/parcel_service/parcel_shipping_widgets.dart';
import 'package:customer/service/parcel_shipping_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// List + map of the pickup points of a region (spec 4.2 steps 3-4). Pops
/// with the chosen [PickupPointModel].
///
/// Archetype B (catalogue): the located points sit on a map header, a sticky
/// search bar filters the list and every point is a selectable outlined card.
class PickupPointPickerScreen extends StatefulWidget {
  final String title;
  final String? regionId;
  final String? city;
  final String? selectedId;

  const PickupPointPickerScreen({super.key, required this.title, this.regionId, this.city, this.selectedId});

  @override
  State<PickupPointPickerScreen> createState() => _PickupPointPickerScreenState();
}

class _PickupPointPickerScreenState extends State<PickupPointPickerScreen> {
  List<PickupPointModel> points = [];
  bool loading = true;
  String query = '';

  @override
  void initState() {
    super.initState();
    ParcelShippingService.pickupPointsFor(regionId: widget.regionId, city: widget.city).then((value) {
      if (!mounted) return;
      setState(() {
        points = value;
        loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.dsLayout;
    final String q = query.trim().toLowerCase();
    final List<PickupPointModel> shown = q.isEmpty ? points : points.where((p) => '${p.name} ${p.quarter} ${p.town}'.toLowerCase().contains(q)).toList();
    final List<PickupPointModel> located = shown.where((p) => p.hasLocation).toList();
    return DsScaffold(
      title: widget.title,
      subtitle: loading ? null : "${points.length} ${'Pickup points'.tr}",
      maxContentWidth: DsLayout.contentMax,
      body: DsAsync(
        isLoading: loading,
        skeleton: const DsSkeletonList(itemCount: 5),
        isEmpty: points.isEmpty,
        empty: DsEmptyState(icon: Icons.storefront_outlined, title: "No pickup point is available here yet.".tr),
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
          children: [
            if (located.isNotEmpty) ...[
              ParcelPointsMap(
                points: located.map((p) => ParcelMapPoint(p.latitude!, p.longitude!, p.name, highlight: p.id == widget.selectedId)).toList(),
                onTap: (i) => Get.back(result: located[i]),
              ),
              const DsGap(DsSpace.lg),
            ],
            DsSearchBar(hint: "Search pickup points".tr, onChanged: (v) => setState(() => query = v)),
            const DsGap(DsSpace.lg),
            if (shown.isEmpty)
              DsEmptyState(compact: true, icon: Icons.search_off_rounded, title: "No pickup point is available here yet.".tr)
            else
              for (int i = 0; i < shown.length; i++)
                DsFadeSlideIn(
                  index: i,
                  child: _PointTile(point: shown[i], selected: shown[i].id == widget.selectedId),
                ),
          ],
        ),
      ),
    );
  }
}

/// One pickup point: icon well, name, address, opening hours and phone.
class _PointTile extends StatelessWidget {
  final PickupPointModel point;
  final bool selected;

  const _PointTile({required this.point, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.lg),
      borderColor: selected ? c.brand : null,
      semanticLabel: point.name,
      onTap: () => Get.back(result: point),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsIconWell(icon: Icons.storefront_outlined, size: 40, tone: selected ? DsTone.brand : DsTone.neutral),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(point.name, style: t.titleSm),
                if (point.subtitle.isNotEmpty) Text(point.subtitle, style: t.bodySm),
                if (point.openingHours.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpace.xs),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: c.textMuted),
                        const DsGap(DsSpace.xs),
                        Expanded(child: Text("${'Opening hours'.tr}: ${point.openingHours}", style: t.caption)),
                      ],
                    ),
                  ),
                if (point.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpace.xxs),
                    child: Row(
                      children: [
                        Icon(Icons.call_outlined, size: 13, color: c.textMuted),
                        const DsGap(DsSpace.xs),
                        Text(point.phone, style: t.caption.tabular),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (selected) ...[const DsGap(DsSpace.sm), Icon(Icons.check_circle_rounded, color: c.brandStrong)],
        ],
      ),
    );
  }
}
