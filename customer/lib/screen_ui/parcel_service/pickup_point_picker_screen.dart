import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/screen_ui/parcel_service/parcel_shipping_widgets.dart';
import 'package:customer/service/parcel_shipping_service.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// List + map of the pickup points of a region (spec 4.2 steps 3-4). Pops
/// with the chosen [PickupPointModel].
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
    final bool isDark = Get.find<ThemeController>().isDark.value;
    final Color text = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final Color muted = isDark ? AppThemeData.greyDark500 : AppThemeData.grey500;
    final String q = query.trim().toLowerCase();
    final List<PickupPointModel> shown = q.isEmpty ? points : points.where((p) => '${p.name} ${p.quarter} ${p.town}'.toLowerCase().contains(q)).toList();
    final List<PickupPointModel> located = shown.where((p) => p.hasLocation).toList();
    return Scaffold(
      appBar: AppBar(backgroundColor: AppThemeData.primary300, title: Text(widget.title, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900))),
      body:
          loading
              ? Constant.loader()
              : points.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text("No pickup point is available here yet.".tr, textAlign: TextAlign.center, style: AppThemeData.mediumTextStyle(fontSize: 16, color: muted))))
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (located.isNotEmpty) ...[
                    ParcelPointsMap(
                      points: located.map((p) => ParcelMapPoint(p.latitude!, p.longitude!, p.name, highlight: p.id == widget.selectedId)).toList(),
                      onTap: (i) => Get.back(result: located[i]),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: "Search pickup points".tr, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 12),
                  for (final p in shown) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => Get.back(result: p),
                      child: ParcelCard(
                        isDark: isDark,
                        child: Row(
                          children: [
                            Icon(Icons.storefront_outlined, color: p.id == widget.selectedId ? AppThemeData.primary300 : muted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: text)),
                                  if (p.subtitle.isNotEmpty) Text(p.subtitle, style: AppThemeData.mediumTextStyle(fontSize: 13, color: muted)),
                                  if (p.openingHours.isNotEmpty) Text("${'Opening hours'.tr}: ${p.openingHours}", style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted)),
                                  if (p.phone.isNotEmpty) Text(p.phone, style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted)),
                                ],
                              ),
                            ),
                            if (p.id == widget.selectedId) Icon(Icons.check_circle, color: AppThemeData.primary300),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
    );
  }
}
