import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/book_parcel_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/screen_ui/parcel_service/parcel_shipping_widgets.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Spec 4.2 step 5-6 / 7.4: carriers for the shipment with price, estimated
/// time and rating; "Request a quote" when the route is not served.
class ParcelCarrierSelectionScreen extends StatefulWidget {
  const ParcelCarrierSelectionScreen({super.key});

  @override
  State<ParcelCarrierSelectionScreen> createState() => _ParcelCarrierSelectionScreenState();
}

class _ParcelCarrierSelectionScreenState extends State<ParcelCarrierSelectionScreen> {
  late final BookParcelController controller;
  late final List<ParcelCarrierOption> options;
  int selected = 0;

  @override
  void initState() {
    super.initState();
    controller = Get.arguments['controller'];
    options = List<ParcelCarrierOption>.from(Get.arguments['options'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Get.find<ThemeController>().isDark.value;
    final CurrencyModel? currency = RegionService.currencyForRecord(controller.originRegionId);
    final Color text = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final Color muted = isDark ? AppThemeData.greyDark500 : AppThemeData.grey500;
    return Scaffold(
      appBar: AppBar(backgroundColor: AppThemeData.primary300, title: Text("Choose a carrier".tr, style: AppThemeData.boldTextStyle(fontSize: 18, color: AppThemeData.grey900))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ParcelCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ParcelLabels.scope(controller.scope.value), style: AppThemeData.boldTextStyle(fontSize: 16, color: text)),
                const SizedBox(height: 4),
                Text("${controller.originPlace.label}  >  ${controller.destinationPlace.label}", style: AppThemeData.mediumTextStyle(fontSize: 14, color: text)),
                const SizedBox(height: 4),
                Text(
                  "${ParcelLabels.shipmentType(controller.shipmentType.value)} - ${controller.weightKg != null ? '${controller.weightKg} kg' : (controller.selectedWeight?.title ?? '')}",
                  style: AppThemeData.mediumTextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (options.isEmpty) ...[
            ParcelCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Route not served".tr, style: AppThemeData.boldTextStyle(fontSize: 16, color: text)),
                  const SizedBox(height: 6),
                  Text(
                    "No carrier has a price for this route and weight yet. Request a quote: the Spideli team will set a price and you can pay it from your parcel orders.".tr,
                    style: AppThemeData.mediumTextStyle(fontSize: 14, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            RoundedButtonFill(title: "Request a quote".tr, color: AppThemeData.primary300, textColor: AppThemeData.grey900, onPress: () => controller.goToCart(quoteRequest: true)),
          ] else ...[
            for (int i = 0; i < options.length; i++) ...[_optionTile(options[i], i, currency, isDark, text, muted), const SizedBox(height: 10)],
            const SizedBox(height: 6),
            ParcelBreakdownCard(isDark: isDark, currency: currency, breakdown: ParcelLabels.breakdownOf(options[selected].quote, currency?.code)),
            const SizedBox(height: 20),
            RoundedButtonFill(title: "Continue".tr, color: AppThemeData.primary300, textColor: AppThemeData.grey900, onPress: () => controller.goToCart(option: options[selected])),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _optionTile(ParcelCarrierOption option, int index, CurrencyModel? currency, bool isDark, Color text, Color muted) {
    final DeliveryCarrierModel? carrier = option.carrier;
    final bool isSelected = index == selected;
    final String eta = carrier?.estimatedTime ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => setState(() => selected = index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
          border: Border.all(color: isSelected ? AppThemeData.primary300 : (isDark ? AppThemeData.greyDark200 : AppThemeData.grey200), width: isSelected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  carrier != null && carrier.photo.isNotEmpty
                      ? NetworkImageWidget(imageUrl: carrier.photo, height: 46, width: 46, fit: BoxFit.cover)
                      : Container(height: 46, width: 46, color: AppThemeData.primary300.withValues(alpha: 0.2), child: Icon(Icons.local_shipping_outlined, color: text)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(carrier?.name ?? "Spideli drivers".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 16, color: text)),
                  if (carrier == null) Text("Standard same-city delivery".tr, style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted)),
                  if (eta.isNotEmpty) Text("${'Estimated time'.tr}: $eta", style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted)),
                  if (carrier?.rating != null)
                    Row(children: [const Icon(Icons.star, size: 14, color: Colors.amber), const SizedBox(width: 2), Text(carrier!.rating!.toStringAsFixed(1), style: AppThemeData.mediumTextStyle(fontSize: 12, color: muted))]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Constant.amountShow(amount: option.quote.total.toString(), currency: currency), style: AppThemeData.boldTextStyle(fontSize: 16, color: text)),
                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? AppThemeData.primary300 : muted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
