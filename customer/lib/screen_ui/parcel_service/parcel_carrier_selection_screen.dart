import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/book_parcel_controller.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/parcel_shipping_models.dart';
import 'package:customer/screen_ui/parcel_service/parcel_shipping_widgets.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Spec 4.2 step 5-6 / 7.4: carriers for the shipment with price, estimated
/// time and rating; "Request a quote" when the route is not served.
///
/// Archetype E (booking wizard, step 5): a tinted route recap on top, the
/// carriers as selectable option cards, the live breakdown under them and a
/// sticky Continue bar.
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
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
    final CurrencyModel? currency = RegionService.currencyForRecord(controller.originRegionId);
    return DsScaffold(
      title: "Choose a carrier".tr,
      maxContentWidth: DsLayout.contentMax,
      body: ListView(
        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
        children: DsFadeSlideIn.stagger([
          DsCard.tinted(
            padding: const EdgeInsets.all(DsSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DsBadge(label: ParcelLabels.scope(controller.scope.value), tone: DsTone.brand, style: DsBadgeStyle.solid, icon: Icons.public_rounded),
                    const DsGap(DsSpace.sm),
                    Flexible(
                      child: Text(
                        "${ParcelLabels.shipmentType(controller.shipmentType.value)} - ${controller.weightKg != null ? '${controller.weightKg} kg' : (controller.selectedWeight?.title ?? '')}",
                        style: t.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.alt_route_rounded, size: 18, color: c.brandStrong),
                    const DsGap(DsSpace.sm),
                    Expanded(child: Text("${controller.originPlace.label}  >  ${controller.destinationPlace.label}", style: t.titleSm)),
                  ],
                ),
              ],
            ),
          ),
          if (options.isEmpty)
            DsInlineAlert(
              tone: DsTone.warning,
              title: "Route not served".tr,
              message: "No carrier has a price for this route and weight yet. Request a quote: the Spideli team will set a price and you can pay it from your parcel orders.".tr,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DsSectionHeader(title: "Choose a carrier".tr, subtitle: "${options.length} ${'available'.tr}"),
                for (int i = 0; i < options.length; i++) _optionTile(options[i], i, currency),
                const DsGap(DsSpace.sm),
                ParcelBreakdownCard(currency: currency, breakdown: ParcelLabels.breakdownOf(options[selected].quote, currency?.code)),
              ],
            ),
        ]),
      ),
      bottomBar: DsStickyBar(
        child: options.isEmpty
            ? DsButton.primary(
                label: "Request a quote".tr,
                icon: Icons.request_quote_outlined,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () => controller.goToCart(quoteRequest: true),
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Shipping total".tr, style: t.caption),
                        Text(Constant.amountShow(amount: options[selected].quote.total.toString(), currency: currency), style: t.title.tabular),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.lg),
                  DsButton.primary(
                    label: "Continue".tr,
                    trailingIcon: Icons.arrow_forward_rounded,
                    size: DsButtonSize.lg,
                    onPressed: () => controller.goToCart(option: options[selected]),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _optionTile(ParcelCarrierOption option, int index, CurrencyModel? currency) {
    final c = context.dsColors;
    final t = context.dsText;
    final DeliveryCarrierModel? carrier = option.carrier;
    final bool isSelected = index == selected;
    final String eta = carrier?.estimatedTime ?? '';
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      borderColor: isSelected ? c.brand : null,
      semanticLabel: carrier?.name ?? "Spideli drivers".tr,
      onTap: () => setState(() => selected = index),
      child: Row(
        children: [
          carrier != null && carrier.photo.isNotEmpty
              ? DsImage(url: carrier.photo, height: 48, width: 48, radius: DsRadius.sm)
              : const DsIconWell(icon: Icons.local_shipping_outlined, size: 48),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(carrier?.name ?? "Spideli drivers".tr, style: t.titleSm),
                if (carrier == null) Text("Standard same-city delivery".tr, style: t.bodySm),
                if (eta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpace.xxs),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: c.textMuted),
                        const DsGap(DsSpace.xs),
                        Expanded(child: Text("${'Estimated time'.tr}: $eta", style: t.caption)),
                      ],
                    ),
                  ),
                if (carrier?.rating != null)
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpace.xs),
                    child: DsBadge(label: carrier!.rating!.toStringAsFixed(1), tone: DsTone.warning, icon: Icons.star_rounded, small: true),
                  ),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(Constant.amountShow(amount: option.quote.total.toString(), currency: currency), style: t.titleSm.tabular),
              const DsGap(DsSpace.xs),
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? c.brand : c.textMuted,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
