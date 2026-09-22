import 'package:customer/constant/constant.dart';
import 'package:customer/models/cart_product_model.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/preferences.dart';
import 'package:get/get.dart';

/// Wholesale / retail pricing on the shopping side (spec 8.2) and the
/// Delivery / TakeAway order type (spec 7.3).
///
/// Pricing rule (per cart line of quantity Q - a product, or one variant of a
/// product; variants never aggregate):
///   1. the highest wholesale tier whose minQty <= Q (tier 1's price is the
///      variant's wholesale price when set), but only if that price is LOWER
///      than the retail price - the customer always pays the lower price;
///   2. else disPrice when set and lower than price;
///   3. else price.
/// All figures are commission-inclusive (Constant.productCommissionPrice),
/// like the retail prices the app already shows. `wholesaleBusinessOnly`
/// products get no wholesale price here (no verified Business accounts yet).
class WholesalePricing {
  WholesalePricing._();

  static Variants? _variant(ProductModel product, String? variantId) {
    if (variantId == null || variantId.isEmpty) return null;
    return product.itemAttribute?.variants?.firstWhereOrNull((v) => v.variantId == variantId);
  }

  /// Wholesale tiers this customer can get on [product] (or one of its
  /// variants), commission-inclusive; empty when wholesale does not apply.
  static List<WholesaleTier> customerTiers(ProductModel product, VendorModel vendor, {String? variantId}) {
    if (product.wholesaleBlockedForCustomer) return <WholesaleTier>[];
    final List<WholesaleTier> tiers = product.activeWholesaleTiers;
    if (tiers.isEmpty) return tiers;
    final String variantWholesale = (_variant(product, variantId)?.variantWholesalePrice ?? '').trim();
    final List<WholesaleTier> out = [];
    for (int i = 0; i < tiers.length; i++) {
      String raw = tiers[i].price;
      if (i == 0 && (double.tryParse(variantWholesale) ?? 0) > 0) raw = variantWholesale;
      out.add(WholesaleTier(minQty: tiers[i].minQty, price: Constant.productCommissionPrice(vendor, raw)));
    }
    return out;
  }

  /// What a cart line of [product] needs to reprice itself.
  static CartLineMeta metaFor(ProductModel product, VendorModel vendor, {String? variantId}) {
    return CartLineMeta(
      tiers: customerTiers(product, vendor, variantId: variantId),
      saleType: product.effectiveSaleType,
      minOrderQty: product.minOrderQuantity,
      fulfilment: product.effectiveFulfilment,
    );
  }

  /// Retail unit price (commission-inclusive) of [product] / a variant:
  /// disPrice when set and lower than price, else price.
  static double retailPrice(ProductModel product, VendorModel vendor, {String? variantId}) {
    final Variants? variant = _variant(product, variantId);
    if (variant != null) return double.tryParse(Constant.productCommissionPrice(vendor, variant.variantPrice ?? '0')) ?? 0;
    final double price = double.tryParse(Constant.productCommissionPrice(vendor, product.price ?? '0')) ?? 0;
    final double dis = double.tryParse(product.disPrice ?? '0') ?? 0;
    if (dis <= 0) return price;
    final double disPrice = double.tryParse(Constant.productCommissionPrice(vendor, product.disPrice!)) ?? 0;
    return (price <= 0 || disPrice < price) ? disPrice : price;
  }

  /// Price bands shown side by side on the product: retail from 1 unit (not
  /// for wholesale-only products), then each tier that is cheaper than retail,
  /// with its quantity range.
  static List<PriceBand> bands({required double retail, required List<WholesaleTier> tiers, required bool wholesaleOnly}) {
    final List<WholesaleTier> useful = tiers.where((t) => t.isUsable && (wholesaleOnly || retail <= 0 || t.priceValue < retail)).toList()..sort((a, b) => a.minQtyValue.compareTo(b.minQtyValue));
    final List<PriceBand> out = [];
    if (!wholesaleOnly) {
      out.add(PriceBand(price: retail, from: 1, to: useful.isEmpty ? null : useful.first.minQtyValue - 1, isWholesale: false));
    }
    for (int i = 0; i < useful.length; i++) {
      // Wholesale-only: the customer still never pays more than the retail price.
      final double p = (retail > 0 && useful[i].priceValue > retail) ? retail : useful[i].priceValue;
      out.add(PriceBand(price: p, from: useful[i].minQtyValue, to: i + 1 < useful.length ? useful[i + 1].minQtyValue - 1 : null, isWholesale: true));
    }
    return out;
  }

  /// "1000 (1-9) · 700 (10-49) · 650 (50+)" in [currency].
  static String bandsText(List<PriceBand> bands, CurrencyModel? currency) => bands.map((b) => '${Constant.amountShow(amount: b.price.toString(), currency: currency)} (${b.rangeLabel})').join('  ·  ');

  /// Rebuilds a line of a past order for "reorder": the order line carries the
  /// price that was charged (possibly wholesale), so retail prices and the
  /// wholesale tiers are taken from the product as it is now.
  /// Returns null when a WHOLESALE line can't be re-priced (product or store
  /// unavailable, or an error): its stored price is the wholesale unit price,
  /// and adding it as a plain line would sell at that price at any quantity.
  static Future<CartProductModel?> reorderLine(CartProductModel line, {VendorModel? vendor}) async {
    final String productId = (line.id ?? '').split('~').first;
    final String? variantId = (line.id ?? '').contains('~') ? line.id!.split('~').last : null;
    final CartProductModel copy = CartProductModel.fromJson(line.toJson())
      ..isWholesale = false
      ..wholesaleMinQty = '';
    try {
      final ProductModel? product = await FireStoreUtils.getProductById(productId);
      final VendorModel? store = (vendor?.id != null) ? vendor : await FireStoreUtils.getVendorById(line.vendorID ?? '');
      if (product == null || store == null) return line.isWholesale == true ? null : copy;
      copy.lineMeta = metaFor(product, store, variantId: variantId);
      if (line.isWholesale == true) {
        final Variants? variant = _variant(product, variantId);
        if (variant != null) {
          copy.price = Constant.productCommissionPrice(store, variant.variantPrice ?? '0');
          copy.discountPrice = "0";
        } else {
          copy.price = Constant.productCommissionPrice(store, product.price ?? '0');
          copy.discountPrice = (double.tryParse(product.disPrice ?? '0') ?? 0) <= 0 ? "0" : Constant.productCommissionPrice(store, product.disPrice!);
        }
      }
      if ((copy.quantity ?? 0) < copy.minOrderQuantity) copy.quantity = copy.minOrderQuantity;
    } catch (_) {
      if (line.isWholesale == true) return null;
    }
    return copy;
  }
}

/// One price with its quantity range.
class PriceBand {
  final double price;
  final int from;
  final int? to;
  final bool isWholesale;

  const PriceBand({required this.price, required this.from, required this.to, required this.isWholesale});

  String get rangeLabel {
    if (to == null) return '$from+';
    if (to! <= from) return '$from';
    return '$from–$to';
  }
}

/// The Delivery / TakeAway order type, kept in Preferences.foodDeliveryType
/// (the app's existing takeaway mode). Stored untranslated.
class OrderTypeMode {
  OrderTypeMode._();

  static const String delivery = 'Delivery';
  static const String takeAway = 'TakeAway';

  static String get current => normalise(Preferences.getString(Preferences.foodDeliveryType, defaultValue: delivery));

  static bool get isTakeAway => current == takeAway;

  /// Older builds stored the translated label; map anything takeaway-like to [takeAway].
  static String normalise(String value) => foodTypeToFulfilment(value) == ProductModel.fulfilmentTakeaway ? takeAway : delivery;

  static Future<void> set(String value) => Preferences.setString(Preferences.foodDeliveryType, normalise(value));

  /// Human label of a fulfilment mode.
  static String labelOf(String fulfilmentMode) => fulfilmentMode == ProductModel.fulfilmentTakeaway ? 'TakeAway'.tr : 'Delivery'.tr;
}
