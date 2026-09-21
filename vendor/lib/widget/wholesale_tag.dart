import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/models/cart_product_model.dart';
import 'package:vendor/themes/app_them_data.dart';

/// Text for the wholesale tag of an order line, e.g. "Wholesale · from 10 units".
String wholesaleTagText(CartProductModel product) {
  final String minQty = (product.wholesaleMinQty ?? '').trim();
  if (minQty.isEmpty) return "Wholesale".tr;
  return "${"Wholesale".tr} · ${"from".tr} $minQty ${"units".tr}";
}

/// Small tag shown on order lines charged at the wholesale price
/// (`isWholesale == true`). Renders nothing for regular lines.
class WholesaleTag extends StatelessWidget {
  final CartProductModel product;
  final bool isDark;

  const WholesaleTag({super.key, required this.product, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (product.isWholesale != true) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: isDark ? AppThemeData.primary50 : AppThemeData.primary600, borderRadius: BorderRadius.circular(6)),
      child: Text(
        wholesaleTagText(product),
        style: TextStyle(fontSize: 12, color: AppThemeData.primary300, fontFamily: AppThemeData.medium),
      ),
    );
  }
}
