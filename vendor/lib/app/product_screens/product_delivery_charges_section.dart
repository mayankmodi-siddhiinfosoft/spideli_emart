import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/product_delivery_charges.dart';

/// "Delivery Charges" section of the Add / Edit Product screen (bug point 60,
/// APP-SPEC-PRODUCT-DELIVERY-CHARGES §3B). The screen shows it only while the
/// store's section has `is_delivery_charge_customization == true`.
///
/// Up to [ProductDeliveryCharges.maxTiers] rows of three fields. At the limit
/// the add button is disabled and the limit warning shows above it; removing
/// a row re-enables the button and hides the warning.
class ProductDeliveryChargesSection extends StatelessWidget {
  final List<DeliveryChargeTierInput> rows;

  /// The store's currency symbol (or code), shown in the minimum charge label.
  final String? currencySymbol;
  final String? currencyCode;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const ProductDeliveryChargesSection({super.key, required this.rows, required this.onAdd, required this.onRemove, this.currencySymbol, this.currencyCode});

  static const Key addButtonKey = ValueKey('delivery-charge-add');
  static const Key limitWarningKey = ValueKey('delivery-charge-limit');

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final bool limitReached = ProductDeliveryCharges.isLimitReached(rows.length);
    final String minimumChargeLabel = ProductDeliveryCharges.minimumChargeLabelWithCurrency(
      ProductDeliveryCharges.minimumChargeLabel.tr,
      symbol: currencySymbol,
      code: currencyCode,
    );
    return DsFormSection(
      title: ProductDeliveryCharges.title.tr,
      subtitle: ProductDeliveryCharges.note.tr,
      icon: Icons.local_shipping_outlined,
      children: [
        for (int i = 0; i < rows.length; i++)
          Container(
            key: ObjectKey(rows[i]),
            margin: const EdgeInsets.only(bottom: DsSpace.sm),
            padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.sm, DsSpace.xs, 0),
            decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: DsTypography.labelSm.copyWith(color: c.brandStrong)),
                    ),
                    const Spacer(),
                    DsIconButton(
                      icon: Icons.delete_outline_rounded,
                      semanticLabel: ProductDeliveryCharges.removeLabel.tr,
                      color: c.danger,
                      onPressed: () => onRemove(i),
                    ),
                  ],
                ),
                const DsGap(DsSpace.xs),
                Padding(
                  padding: const EdgeInsets.only(right: DsSpace.sm),
                  child: DsAdaptiveGrid(
                    minItemWidth: 200,
                    maxColumns: 3,
                    equalHeight: false,
                    spacing: DsSpace.sm,
                    runSpacing: 0,
                    children: [
                      _field(ProductDeliveryCharges.perKmLabel.tr, rows[i].perKmController),
                      _field(minimumChargeLabel, rows[i].minimumChargeController),
                      _field(ProductDeliveryCharges.withinKmLabel.tr, rows[i].withinKmController),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (limitReached) ...[
          DsInlineAlert(key: limitWarningKey, tone: DsTone.warning, message: ProductDeliveryCharges.limitReached.tr),
          const DsGap(DsSpace.sm),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsButton.tonal(
            key: addButtonKey,
            label: ProductDeliveryCharges.addLabel.tr,
            icon: Icons.add_rounded,
            size: DsButtonSize.sm,
            // Disabled (greyed out) at the limit.
            onPressed: limitReached ? null : onAdd,
          ),
        ),
        const DsGap(DsSpace.md),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return DsTextField(
      label: label,
      hint: '0',
      controller: controller,
      keyboardType: ProductDeliveryCharges.keyboardType,
      textInputAction: TextInputAction.next,
      inputFormatters: [ProductDeliveryCharges.inputFormatter],
      bottomSpacing: DsSpace.md,
    );
  }
}
