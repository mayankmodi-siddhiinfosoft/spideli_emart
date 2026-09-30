import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/product_model.dart';

/// How this product is sold: "Retail", "Wholesale only" or "Retail & wholesale"
/// - the panel's sale type column (STORE spec 3, 30 September). Never null, so
/// the list says which of the three states a product is in, including legacy
/// products that carry no `saleType`: those read from `wholesaleEnabled` alone
/// (off = retail, on = both), exactly like [ProductModel.effectiveSaleType].
String saleTypeLabel(ProductModel product) {
  switch (product.effectiveSaleType) {
    case ProductModel.saleTypeWholesale:
      return "Wholesale only".tr;
    case ProductModel.saleTypeBoth:
      return "Retail & wholesale".tr;
    default:
      return "Retail".tr;
  }
}

/// Compact wholesale tiers text for the product list, e.g.
/// "700 from 10 · 650 from 50", or "700 from 10 · +2 more tiers" when there
/// are more than two tiers. Null when the product has no usable wholesale tier.
///
/// [variantWholesalePrice] (the displayed variant's own wholesale price) is that
/// variant's TIER-ONE price and SHIFTS the whole ladder by the difference, it
/// does not replace it (STORE spec 3, "A variant shifts the ladder, it does not
/// replace it"). Blank leaves the product's own tiers as they are, and a tier
/// the shift would take to zero or below is dropped rather than clamped.
String? wholesaleTiersBadge(ProductModel product, {String? variantWholesalePrice}) {
  final List<WholesaleTier> tiers = product.activeWholesaleTiers;
  if (tiers.isEmpty) return null;
  final double variantTierOne = double.tryParse((variantWholesalePrice ?? '').trim()) ?? 0;
  final double baseTierOne = double.tryParse(tiers.first.price) ?? 0;
  final double shift = variantTierOne > 0 && baseTierOne > 0 ? variantTierOne - baseTierOne : 0;
  final List<(String, int)> steps = [];
  for (final tier in tiers) {
    final double base = double.tryParse(tier.price) ?? 0;
    final double shifted = base + shift;
    // Dropped, not clamped: a ladder that deep means the figures are wrong.
    if (shift != 0 && shifted <= 0) continue;
    steps.add((shift == 0 ? tier.price : shifted.toString(), tier.minQtyValue));
  }
  if (steps.isEmpty) return null;
  String tierText(int i) => "${Constant.amountShow(amount: steps[i].$1)} ${"from".tr} ${steps[i].$2}";
  if (steps.length <= 2) {
    final String text = List.generate(steps.length, tierText).join(' · ');
    return steps.length == 1 ? "$text ${"units".tr}" : text;
  }
  return "${tierText(0)} · +${steps.length - 1} ${"more tiers".tr}";
}

/// "Delivery only" / "Takeaway only" when the product is restricted to one
/// fulfilment mode, else null.
String? fulfilmentRestrictionLabel(ProductModel product) {
  // Only flag restrictions the owner chose, not the default of older products.
  // `takeawayOption: true` is such a choice even without a `fulfilment` list:
  // it has always meant takeaway ONLY (STORE spec §3a), so the product really
  // is hidden from every delivery customer and the list has to say so.
  if (!product.hasExplicitFulfilment && product.takeawayOption != true) return null;
  final List<String> modes = product.effectiveFulfilment;
  if (modes.length != 1) return null;
  return modes.first == ProductModel.fulfilmentDelivery ? "Delivery only".tr : "Takeaway only".tr;
}
