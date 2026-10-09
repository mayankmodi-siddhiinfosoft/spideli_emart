import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/product_delivery_charges.dart';

/// "Delivery Charges" section of the Add / Edit Product screen (bug point 60,
/// APP-SPEC-PRODUCT-DELIVERY-CHARGES §3B). The screen shows it only while the
/// store's section has `is_delivery_charge_customization == true`.
///
/// One delivery charge per product (client rule, 9 Oct 2026): the three
/// fields of a single [row], all required on save. There is no add or remove.
class ProductDeliveryChargesSection extends StatelessWidget {
  final DeliveryChargeTierInput row;

  /// The store's currency symbol (or code), shown in the minimum charge label.
  final String? currencySymbol;
  final String? currencyCode;

  const ProductDeliveryChargesSection({super.key, required this.row, this.currencySymbol, this.currencyCode});

  @override
  Widget build(BuildContext context) {
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
        DsAdaptiveGrid(
          minItemWidth: 200,
          maxColumns: 3,
          equalHeight: false,
          spacing: DsSpace.sm,
          runSpacing: 0,
          children: [
            _field(ProductDeliveryCharges.perKmLabel.tr, row.perKmController),
            _field(minimumChargeLabel, row.minimumChargeController),
            _field(ProductDeliveryCharges.withinKmLabel.tr, row.withinKmController),
          ],
        ),
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
