import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/product_model.dart';

/// Compact wholesale tiers text for the product list, e.g.
/// "700 from 10 · 650 from 50", or "700 from 10 · +2 more tiers" when there
/// are more than two tiers. [variantWholesalePrice] (the displayed variant's
/// own wholesale price) replaces the first tier's price. Null when the product
/// has no usable wholesale tier.
String? wholesaleTiersBadge(ProductModel product, {String? variantWholesalePrice}) {
  final List<WholesaleTier> tiers = product.activeWholesaleTiers;
  if (tiers.isEmpty) return null;
  String priceOf(int i) {
    final String variantPrice = (variantWholesalePrice ?? '').trim();
    if (i == 0 && (double.tryParse(variantPrice) ?? 0) > 0) return variantPrice;
    return tiers[i].price;
  }

  String tierText(int i) => "${Constant.amountShow(amount: priceOf(i))} ${"from".tr} ${tiers[i].minQtyValue}";
  if (tiers.length <= 2) {
    final String text = List.generate(tiers.length, tierText).join(' · ');
    return tiers.length == 1 ? "$text ${"units".tr}" : text;
  }
  return "${tierText(0)} · +${tiers.length - 1} ${"more tiers".tr}";
}

/// "Delivery only" / "Takeaway only" when the product is restricted to one
/// fulfilment mode, else null.
String? fulfilmentRestrictionLabel(ProductModel product) {
  final List<String> modes = product.effectiveFulfilment;
  if (modes.length != 1) return null;
  return modes.first == ProductModel.fulfilmentDelivery ? "Delivery only".tr : "Takeaway only".tr;
}
