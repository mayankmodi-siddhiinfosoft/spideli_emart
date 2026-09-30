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
///   1. the highest wholesale tier whose minQty <= Q whose price is LOWER than
///      the retail price - tested per tier, so a discount that beats tier 1
///      never hides a deeper tier (a variant's own wholesale price SHIFTS that
///      ladder, it does not replace it - see [customerTiers]);
///   2. else disPrice when set and lower than price;
///   3. else price.
/// All figures are commission-inclusive (Constant.productCommissionPrice),
/// like the retail prices the app already shows.
///
/// **Wholesale is for approved business accounts only** (WEB spec §19): every
/// tier here comes from `ProductModel.activeWholesaleTiers`, which is empty
/// unless `WholesaleEntitlement.mayBuyWholesale`, so one switch withholds the
/// badge, the ladder, the minimum and the price at once.
class WholesalePricing {
  WholesalePricing._();

  static Variants? _variant(ProductModel product, String? variantId) {
    if (variantId == null || variantId.isEmpty) return null;
    return product.itemAttribute?.variants?.firstWhereOrNull((v) => v.variantId == variantId);
  }

  /// Wholesale tiers this customer can get on [product] (or one of its
  /// variants), commission-inclusive; empty when wholesale does not apply.
  ///
  /// **A variant SHIFTS the ladder, it does not replace it** - the 30 September
  /// rule of STORE spec §3 / WEB spec §10, which the store panel, both POS
  /// screens and the website all implement and which this must match to the
  /// last unit.
  ///
  /// `variant_wholesale_price` is that variant's **TIER-ONE** price. The
  /// product's tiers own the quantity breaks and the steps between them; the
  /// variant shifts the whole ladder to start at its own figure, and the steps
  /// are kept as **differences, not ratios**:
  ///
  /// ```
  /// product tiers      10 -> 949    50 -> 849    150 -> 749
  ///
  /// variant blank   =>  949   849   749     the product's ladder, unchanged
  /// variant 949     =>  949   849   749     identical - the commonest case
  /// variant 999     =>  999   899   799     fifty more, throughout
  /// variant 899     =>  899   799   699     fifty less, throughout
  /// ```
  ///
  /// A tier that would fall to **zero or below is dropped, not clamped**: a
  /// ladder that deep means the figures are wrong, and inventing a price would
  /// hide it.
  ///
  /// Read the old way - "this variant's only wholesale price" - it destroyed
  /// the ladder: a product with tiers at 10/50/150 charged the entry price at
  /// every quantity once sizes existed, and 50 of a tiered kurti charged 959
  /// instead of 859. That is the bug this replaces.
  ///
  /// The other variant-level fields (STORE spec §3, `item_attribute.variants[]`)
  /// are unchanged and all optional - **absent is the normal case** and means
  /// the rule above:
  /// * `wholesaleEnabled: false` (explicit) - this variant is RETAIL-ONLY;
  /// * `wholesaleMinQty` - the quantity tier one is reached at for this
  ///   variant, replacing the product's entry threshold. It moves tier one's
  ///   threshold only; the rest of the ladder is the product's.
  static List<WholesaleTier> customerTiers(ProductModel product, VendorModel vendor, {String? variantId}) {
    final Variants? variant = _variant(product, variantId);
    // Only an EXPLICIT false makes one variant retail-only. Absent / blank /
    // non-boolean reads as null and changes nothing (parseWholesaleBoolOrNull),
    // so a default-written field can never silently switch wholesale off.
    if (variant?.wholesaleEnabled == false) return <WholesaleTier>[];
    // Empty for a customer without an approved business account (WEB §19), so
    // the one switch upstream withholds every tier below.
    final List<WholesaleTier> tiers = product.activeWholesaleTiers;
    if (tiers.isEmpty) return tiers;
    final double variantEntry = double.tryParse((variant?.variantWholesalePrice ?? '').trim()) ?? 0;
    final int? variantMinQty = variant?.wholesaleMinQtyValue;
    // Blank / zero = no opinion: the product's ladder applies unchanged.
    final double shift = variantEntry > 0 ? variantEntry - tiers.first.priceValue : 0;
    final List<WholesaleTier> out = [];
    for (int i = 0; i < tiers.length; i++) {
      // Differences, not ratios: "a hundred rupees a step" stays true when a
      // size costs fifty more.
      final double shifted = tiers[i].priceValue + shift;
      if (shifted <= 0) continue; // dropped, never clamped
      // Untouched when nothing shifts, so a blank variant is byte-identical to
      // the product's own ladder.
      final String price = shift == 0 ? tiers[i].price : shifted.toStringAsFixed(2);
      String minQty = tiers[i].minQty;
      if (i == 0 && variantMinQty != null) minQty = variantMinQty.toString();
      out.add(WholesaleTier(minQty: minQty, price: Constant.productCommissionPrice(vendor, price)));
    }
    // The variant's own threshold can push tier 1 past a later tier; keep the
    // list ordered so the bands render and the tiers read in order (the price
    // itself is picked by highest reached minQty, which is order-independent).
    out.sort((a, b) => a.minQtyValue.compareTo(b.minQtyValue));
    return out;
  }

  /// The products a listing may draw (WEB spec §19): a **wholesale-only**
  /// product is hidden outright from a customer without an approved business
  /// account - product lists, new arrivals, search, the store page, both home
  /// screens and favourites. A mixed product stays, at retail.
  ///
  /// Filter the list BEFORE the card loop rather than returning nothing inside
  /// it, so an all-hidden result falls through to each screen's own empty
  /// message instead of drawing a blank row.
  ///
  /// `ProductModel.hiddenForCustomer` reads the raw product document, never the
  /// computed price: a customer who may not buy wholesale has no computed
  /// tiers, so keying this on them would leak every wholesale-only product to
  /// exactly the customers it hides them from.
  static List<ProductModel> visibleProducts(Iterable<ProductModel> products) => products.where((p) => !p.hiddenForCustomer).toList();

  /// True when this line's variant EXPLICITLY carries `wholesaleEnabled: false`
  /// (STORE spec §3): that one variant is retail-only, whatever the product's
  /// switch says. A product-level line, or a variant without the field, is
  /// never retail-only by this rule - so this is false and nothing changes.
  static bool isRetailOnlyVariant(ProductModel product, String? variantId) => _variant(product, variantId)?.wholesaleEnabled == false;

  /// [ProductModel.isWholesaleOnly] for ONE line: a retail-only variant of a
  /// wholesale-only product is still bought at retail, so its retail price
  /// stays visible and no wholesale minimum is imposed on it.
  static bool isWholesaleOnlyFor(ProductModel product, {String? variantId}) => product.isWholesaleOnly && !isRetailOnlyVariant(product, variantId);

  /// Minimum order quantity of ONE line: on a wholesale-only line the first
  /// tier that line can reach - so a variant with its own `wholesaleMinQty`
  /// asks for its own minimum - and 1 otherwise, as before.
  static int minOrderQuantityFor(ProductModel product, VendorModel vendor, {String? variantId}) {
    if (!isWholesaleOnlyFor(product, variantId: variantId)) return 1;
    final List<WholesaleTier> tiers = customerTiers(product, vendor, variantId: variantId);
    return tiers.isEmpty ? product.minOrderQuantity : tiers.first.minQtyValue;
  }

  /// What a cart line of [product] needs to reprice itself.
  static CartLineMeta metaFor(ProductModel product, VendorModel vendor, {String? variantId}) {
    return CartLineMeta(
      tiers: customerTiers(product, vendor, variantId: variantId),
      saleType: isRetailOnlyVariant(product, variantId) ? ProductModel.saleTypeRetail : product.effectiveSaleType,
      minOrderQty: minOrderQuantityFor(product, vendor, variantId: variantId),
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
  ///
  /// [stock] is the units the line actually has (-1 = unlimited): a tier the
  /// chosen size cannot physically reach is not advertised at all (WEB spec
  /// §10, "A size that cannot make up a pack says so" - 60 left in a size and
  /// "749 from 150 units" was an invitation into a stock error).
  static List<PriceBand> bands({required double retail, required List<WholesaleTier> tiers, required bool wholesaleOnly, int stock = -1}) {
    final List<WholesaleTier> useful =
        tiers.where((t) => t.isUsable && (wholesaleOnly || retail <= 0 || t.priceValue < retail) && (stock < 0 || t.minQtyValue <= stock)).toList()
          ..sort((a, b) => a.minQtyValue.compareTo(b.minQtyValue));
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

  /// "Sold in a minimum of 15 units" - the wholesale-only floor, worded the
  /// same on the product page, the cart line and the listing badge.
  static String minimumLabel(int minQty) => "${'Sold in a minimum of'.tr} $minQty ${'units'.tr}";

  /// What a LISTING card advertises: the ENTRY tier, the offer the legacy
  /// `wholesalePrice` / `wholesaleMinQty` pair carries and the panels keep
  /// aligned with tier 1 (WEB spec §10, "the listing badges"). '' when this
  /// customer has no wholesale tier on this product.
  static String listingBadgeLabel(ProductModel product, VendorModel vendor, {String? variantId, CurrencyModel? currency}) {
    final List<WholesaleTier> tiers = customerTiers(product, vendor, variantId: variantId);
    if (tiers.isEmpty) return '';
    final WholesaleTier entry = tiers.first;
    if (isWholesaleOnlyFor(product, variantId: variantId)) return minimumLabel(entry.minQtyValue);
    final double retail = retailPrice(product, vendor, variantId: variantId);
    // Never advertise a price the customer would not actually get.
    if (retail > 0 && entry.priceValue >= retail) return '';
    return entryLabel(entry, currency);
  }

  /// "Wholesale 3,500 from 15 units".
  static String entryLabel(WholesaleTier tier, CurrencyModel? currency) =>
      "${'Wholesale'.tr} ${Constant.amountShow(amount: tier.price, currency: currency)} ${'from'.tr} ${tier.minQtyValue} ${'units'.tr}";

  /// The note under the product page's quantity box (WEB spec §10,
  /// `updateWholesaleNote()`), for [quantity] of this product / variant.
  ///
  /// [stock] is the units the line actually has (-1 = unlimited). A step up the
  /// chosen size cannot reach is **not offered**: the box will not go there and
  /// the stock will not grow, so "add 90 more" would be a dead end.
  static WholesaleNote noteFor({required double retail, required List<WholesaleTier> tiers, required int quantity, int stock = -1}) {
    final List<WholesaleTier> reachable = stock < 0 ? tiers : tiers.where((t) => t.minQtyValue <= stock).toList();
    final LinePrice current = LinePrice.resolve(retail: retail, tiers: reachable, quantity: quantity);
    final WholesaleTier? next = LinePrice.nextTier(tiers: reachable, quantity: quantity, currentUnit: current.unit);
    return WholesaleNote(applied: current.isWholesale ? current : null, next: next, unitsToNext: next == null ? 0 : next.minQtyValue - quantity);
  }

  // ------------- WEB spec §10, the two 30 September product-page rules -------------

  /// Units this line actually has: the selected variant's stock, else the
  /// product's. **-1 means unlimited**, the value both panels use.
  static int stockFor(ProductModel product, {String? variantId}) {
    final Variants? variant = _variant(product, variantId);
    if (variant != null) return int.tryParse((variant.variantQuantity ?? '').trim()) ?? 0;
    return product.quantity ?? 0;
  }

  /// The ENTRY tier of this line - the cheapest quantity that unlocks a
  /// wholesale price, and on a wholesale-only product the only price the
  /// customer can actually pay. null when this line has no wholesale tier.
  static WholesaleTier? entryTierFor(ProductModel product, VendorModel vendor, {String? variantId}) {
    final List<WholesaleTier> tiers = customerTiers(product, vendor, variantId: variantId);
    return tiers.isEmpty ? null : tiers.first;
  }

  /// **A wholesale-only product shows a price a customer can pay** (WEB spec
  /// §10, 30 September): the headline is the ENTRY tier for the selected
  /// variant, not the retail price - a single piece is not for sale at any
  /// price, so showing the retail figure was showing a price nobody could pay.
  ///
  /// null for retail and mixed products: there the retail headline is honest,
  /// so the check is on the sale type alone.
  static WholesaleTier? headlineTierFor(ProductModel product, VendorModel vendor, {String? variantId}) {
    if (!isWholesaleOnlyFor(product, variantId: variantId)) return null;
    return entryTierFor(product, vendor, variantId: variantId);
  }

  /// "per piece, from 10 units" - under the wholesale-only headline price.
  static String headlineMinimumLabel(int minQty) => "${'per piece, from'.tr} $minQty ${'units'.tr}";

  /// **A size that cannot make up a pack says so** (WEB spec §10, 30
  /// September): the units still missing before this line could reach its
  /// entry tier, or 0 when it is workable.
  ///
  /// A wholesale-only line opens its quantity box at the entry tier; if the
  /// chosen size holds less than that, every route out is a dead end - the box
  /// will not go lower and the stock will not go higher - and add-to-cart used
  /// to fail with a stock error that named neither the size nor a way out.
  static int packShortfall(ProductModel product, VendorModel vendor, {String? variantId}) {
    if (!isWholesaleOnlyFor(product, variantId: variantId)) return 0;
    final int stock = stockFor(product, variantId: variantId);
    if (stock < 0) return 0; // unlimited
    final int minQty = minOrderQuantityFor(product, vendor, variantId: variantId);
    return stock < minQty ? minQty - stock : 0;
  }

  /// "Only 60 left in this option - 150 needed for the smallest pack".
  static String shortfallLabel(int stock, int minQty) =>
      "${'Only'.tr} $stock ${'left in this option'.tr} — $minQty ${'needed for the smallest pack'.tr}";

  /// [wholesaleDetails] with everything that could run or fetch code removed
  /// (WEB spec §10, `safeWholesaleDetails()`): a price table is the point of
  /// the field, so it is rendered as HTML - but it is typed in the store
  /// panel, and a store account must not be able to run code in a customer's
  /// browser. `script`, `iframe`, `object`, `embed`, `link`, `style` and
  /// `form` tags go with their contents, then every `on*` handler and every
  /// `javascript:` URL.
  static String safeDetailsHtml(String? raw) {
    String html = raw ?? '';
    if (html.trim().isEmpty) return '';
    const List<String> banned = ['script', 'iframe', 'object', 'embed', 'link', 'style', 'form'];
    for (final String tag in banned) {
      // <tag ...> ... </tag>, and any stray opening / closing / self-closing tag.
      html = html.replaceAll(RegExp('<\\s*$tag\\b[^>]*>[\\s\\S]*?<\\s*/\\s*$tag\\s*>', caseSensitive: false), '');
      html = html.replaceAll(RegExp('<\\s*/?\\s*$tag\\b[^>]*>', caseSensitive: false), '');
    }
    // on*="..." / on*='...' / on*=unquoted
    html = html.replaceAll(RegExp('\\son[a-z0-9_\\-]+\\s*=\\s*"[^"]*"', caseSensitive: false), '');
    html = html.replaceAll(RegExp("\\son[a-z0-9_\\-]+\\s*=\\s*'[^']*'", caseSensitive: false), '');
    html = html.replaceAll(RegExp('\\son[a-z0-9_\\-]+\\s*=\\s*[^\\s>]+', caseSensitive: false), '');
    // javascript: / vbscript: URLs, however they are spelled - and data: URLs
    // that are not an inline image (a price table's own image is the one use
    // of data: worth keeping).
    for (final String scheme in ['javascript', 'vbscript', 'data:(?!image/)']) {
      final String head = scheme.contains(':') ? scheme : '$scheme\\s*:';
      html = html.replaceAll(RegExp('(href|src|xlink:href)\\s*=\\s*"\\s*$head[^"]*"', caseSensitive: false), '');
      html = html.replaceAll(RegExp("(href|src|xlink:href)\\s*=\\s*'\\s*$head[^']*'", caseSensitive: false), '');
      html = html.replaceAll(RegExp('(href|src|xlink:href)\\s*=\\s*$head[^\\s>]*', caseSensitive: false), '');
    }
    return html.trim();
  }

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

/// Where the customer stands on the wholesale ladder at a given quantity:
/// the tier in force (null below the first one) and the next, cheaper tier.
class WholesaleNote {
  /// The tier the line is priced at right now, or null at retail.
  final LinePrice? applied;

  /// The next tier up, only when it costs less than what is paid now.
  final WholesaleTier? next;

  /// Units still to add to reach [next].
  final int unitsToNext;

  const WholesaleNote({required this.applied, required this.next, required this.unitsToNext});

  bool get isEmpty => applied == null && next == null;
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
