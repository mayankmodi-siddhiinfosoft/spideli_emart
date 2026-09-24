import 'package:driver/app/parcel_screen/parcel_order_details.dart';
import 'package:driver/app/parcel_screen/parcel_tracking/parcel_scan_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/parcel_home_controller.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Parcel run" manifest (spec 9: Manifest ▸ Scan each parcel at hand-over ▸ Update status).
/// Lists the in-progress parcels of this driver and, for a company, of its fleet — sorted by next action.
///
/// Archetype J/D: a collapsing manifest where every row carries its tracking
/// number, route, current status, the next step and a scan shortcut.
class ParcelRunScreen extends StatefulWidget {
  const ParcelRunScreen({super.key});

  @override
  State<ParcelRunScreen> createState() => _ParcelRunScreenState();
}

class _ParcelRunScreenState extends State<ParcelRunScreen> {
  bool _loading = true;
  List<ParcelOrderModel> _parcels = [];
  Map<String, String> _drivers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Parcels completed here must not stay actionable on the (stale) home list.
    if (Get.isRegistered<ParcelHomeController>()) Get.find<ParcelHomeController>().getParcelList();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _drivers = await ParcelTrackingService.manifestDrivers();
      _parcels = await ParcelTrackingService.manifest(_drivers.keys);
    } catch (e) {
      _parcels = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _route(ParcelOrderModel o) {
    final from = o.origin?['city']?.toString();
    final to = o.destination?['city']?.toString();
    if ((from ?? '').isNotEmpty || (to ?? '').isNotEmpty) return '${from ?? ''} → ${to ?? ''}';
    return '${o.sender?.address ?? ''} → ${o.receiver?.address ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final me = FireStoreUtils.getCurrentUid();
    return DsScaffold.collapsing(
      title: "Parcel run".tr,
      subtitle: _loading ? null : "${_parcels.length} ${'Parcels'.tr}",
      onRefresh: _load,
      actions: [
        DsIconButton(
          icon: Icons.qr_code_scanner,
          semanticLabel: "Scan parcel".tr,
          variant: DsIconButtonVariant.tonal,
          onPressed: () => Get.to(() => const ParcelScanScreen())!.then((_) => _load()),
        ),
      ],
      slivers: [
        if (_loading)
          const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 5))
        else if (_parcels.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState(
              icon: Icons.inventory_2_outlined,
              title: "No parcels in progress.".tr,
              actionLabel: "Scan parcel".tr,
              actionIcon: Icons.qr_code_scanner,
              onAction: () => Get.to(() => const ParcelScanScreen())!.then((_) => _load()),
            ),
          )
        else
          DsSliverResponsive(
            top: DsSpace.sm,
            bottom: DsSpace.xxl,
            sliver: SliverList.separated(
              itemCount: _parcels.length,
              separatorBuilder: (_, _) => const DsGap(DsSpace.md),
              itemBuilder: (context, i) {
                final o = _parcels[i];
                final next = ParcelTrackingService.nextActions(o);
                final status = ParcelTrackingService.currentStatus(o) ?? o.status ?? '';
                final driverName = o.driverId != me ? _drivers[o.driverId] : null;
                return DsFadeSlideIn(
                  index: i,
                  child: _ManifestCard(
                    title: o.trackingNumber ?? Constant.orderId(orderId: o.id ?? ''),
                    route: _route(o),
                    status: status,
                    nextLabel: next.statuses.isEmpty ? (next.reason ?? '').tr : "${'Next'.tr}: ${next.statuses.map((e) => e.tr).join(' / ')}",
                    driverName: driverName,
                    onTap: () => Get.to(() => const ParcelOrderDetails(), arguments: o),
                    onScan: () => Get.to(() => ParcelScanScreen(expectedOrderId: o.id))!.then((_) => _load()),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// One line of the manifest.
class _ManifestCard extends StatelessWidget {
  final String title;
  final String route;
  final String status;
  final String nextLabel;
  final String? driverName;
  final VoidCallback onTap;
  final VoidCallback onScan;

  const _ManifestCard({
    required this.title,
    required this.route,
    required this.status,
    required this.nextLabel,
    required this.driverName,
    required this.onTap,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: t.titleSm.w700.tabular)),
              const DsGap(DsSpace.sm),
              DsIconWell(icon: Icons.local_shipping_outlined, tone: DsTone.brand, size: 32),
            ],
          ),
          if (status.isNotEmpty) ...[
            const DsGap(DsSpace.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DsStatusChip(label: "${'Status'.tr}: ${status.tr}", status: status),
            ),
          ],
          const DsGap(DsSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.alt_route_rounded, size: 16, color: c.iconDefault),
              const DsGap(DsSpace.sm),
              Expanded(
                child: Text(route, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm.withColor(c.textPrimary)),
              ),
            ],
          ),
          if (nextLabel.isNotEmpty) ...[
            const DsGap(DsSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.east_rounded, size: 16, color: c.brandStrong),
                const DsGap(DsSpace.sm),
                Expanded(child: Text(nextLabel, style: t.labelSm.withColor(c.brandStrong))),
              ],
            ),
          ],
          if (driverName != null && driverName!.isNotEmpty) ...[
            const DsGap(DsSpace.sm),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 16, color: c.iconDefault),
                const DsGap(DsSpace.sm),
                Expanded(child: Text("${'Driver'.tr}: $driverName", style: t.caption)),
              ],
            ),
          ],
          const DsGap(DsSpace.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DsButton.tonal(
              label: "Scan".tr,
              icon: Icons.qr_code_scanner,
              size: DsButtonSize.sm,
              onPressed: onScan,
            ),
          ),
        ],
      ),
    );
  }
}
