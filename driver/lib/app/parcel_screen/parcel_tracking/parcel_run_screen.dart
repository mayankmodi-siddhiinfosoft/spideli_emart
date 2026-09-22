import 'package:driver/app/parcel_screen/parcel_order_details.dart';
import 'package:driver/app/parcel_screen/parcel_tracking/parcel_scan_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/parcel_home_controller.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/services/parcel_tracking_service.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Parcel run" manifest (spec 9: Manifest ▸ Scan each parcel at hand-over ▸ Update status).
/// Lists the in-progress parcels of this driver and, for a company, of its fleet — sorted by next action.
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
    final isDark = Get.find<ThemeController>().isDark.value;
    final textColor = isDark ? AppThemeData.grey50 : AppThemeData.grey900;
    final subColor = isDark ? AppThemeData.grey300 : AppThemeData.grey600;
    final me = FireStoreUtils.getCurrentUid();
    return Scaffold(
      appBar: AppBar(
        title: Text("Parcel run".tr),
        actions: [IconButton(onPressed: () => Get.to(() => const ParcelScanScreen())!.then((_) => _load()), icon: const Icon(Icons.qr_code_scanner))],
      ),
      backgroundColor: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
      body: _loading
          ? Constant.loader()
          : RefreshIndicator(
              onRefresh: _load,
              child: _parcels.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text("No parcels in progress.".tr, textAlign: TextAlign.center, style: TextStyle(color: subColor)),
                      )
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _parcels.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final o = _parcels[i];
                        final next = ParcelTrackingService.nextActions(o);
                        final status = ParcelTrackingService.currentStatus(o) ?? o.status ?? '';
                        final driverName = o.driverId != me ? _drivers[o.driverId] : null;
                        return InkWell(
                          onTap: () => Get.to(() => const ParcelOrderDetails(), arguments: o),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(o.trackingNumber ?? Constant.orderId(orderId: o.id ?? ''), style: TextStyle(color: textColor, fontFamily: AppThemeData.semiBold)),
                                      const SizedBox(height: 2),
                                      Text(_route(o), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text("${'Status'.tr}: ${status.tr}", style: TextStyle(color: subColor, fontSize: 12)),
                                      Text(
                                        next.statuses.isEmpty ? (next.reason ?? '').tr : "${'Next'.tr}: ${next.statuses.map((e) => e.tr).join(' / ')}",
                                        style: TextStyle(color: AppThemeData.primary300, fontSize: 12),
                                      ),
                                      if (driverName != null && driverName.isNotEmpty) Text("${'Driver'.tr}: $driverName", style: TextStyle(color: subColor, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: () => Get.to(() => ParcelScanScreen(expectedOrderId: o.id))!.then((_) => _load()),
                                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                                  label: Text("Scan".tr),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
