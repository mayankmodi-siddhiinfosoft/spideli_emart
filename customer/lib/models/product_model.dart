import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/tax_model.dart';
import 'package:get/get.dart';
import 'package:customer/utils/business_account.dart';
import 'package:customer/utils/wholesale_entitlement.dart';

class ProductModel {
  int? fats;
  String? vendorID;
  bool? veg;
  bool? publish;
  List<dynamic>? addOnsTitle;
  int? calories;
  int? proteins;
  List<dynamic>? addOnsPrice;
  num? reviewsSum;
  bool? takeawayOption;
  String? name;
  Map<String, dynamic>? reviewAttributes;
  Map<String, dynamic>? productSpecification;
  ItemAttribute? itemAttribute;
  String? id;
  int? quantity;
  int? grams;
  num? reviewsCount;
  String? disPrice;
  List<dynamic>? photos;
  bool? nonveg;
  String? photo;
  String? price;
  String? categoryID;
  String? description;
  Timestamp? createdAt;
  String? sectionId;
  String? brandId;
  bool? isDigitalProduct;
  String? digitalProduct;
  List<TaxModel>? taxSetting;

  /// Wholesale / retail fields written by the Store app (read-only here).
  /// See vendor/lib/models/product_model.dart for the reference.
  /// `wholesaleTiers: [{minQty, price}]` sorted, legacy `wholesalePrice` /
  /// `wholesaleMinQty` = the first tier (products may carry only those).
  bool? wholesaleEnabled;
  String? wholesalePrice;
  String? wholesaleMinQty;
  List<WholesaleTier>? wholesaleTiers;

  /// "retail" | "wholesale" | "both"; absent = "retail" when wholesale is off, else "both".
  String? saleType;

  /// Wholesale terms written with the store panel's HTML editor (price table,
  /// minimum order terms, packaging notes). Rendered under the description
  /// when the product has a wholesale tier - **sanitised first**, see
  /// `WholesalePricing.safeDetailsHtml`.
  String? wholesaleDetails;

  /// Wholesale prices only for verified Business customers.
  bool? wholesaleBusinessOnly;

  /// Subset of ["delivery", "takeaway"]; absent = derived from [takeawayOption].
  List<String>? fulfilment;

  static const String saleTypeRetail = 'retail';
  static const String saleTypeWholesale = 'wholesale';
  static const String saleTypeBoth = 'both';
  static const String fulfilmentDelivery = 'delivery';
  static const String fulfilmentTakeaway = 'takeaway';
  static const List<String> allFulfilmentModes = [fulfilmentDelivery, fulfilmentTakeaway];

  ProductModel({
    this.fats,
    this.vendorID,
    this.veg,
    this.publish,
    this.addOnsTitle,
    this.calories,
    this.proteins,
    this.addOnsPrice,
    this.reviewsSum,
    this.takeawayOption,
    this.name,
    this.reviewAttributes,
    this.productSpecification,
    this.itemAttribute,
    this.id,
    this.quantity,
    this.grams,
    this.reviewsCount,
    this.disPrice,
    this.photos,
    this.nonveg,
    this.photo,
    this.price,
    this.categoryID,
    this.description,
    this.createdAt,
    this.sectionId,
    this.brandId,
    this.isDigitalProduct,
    this.digitalProduct,
    this.taxSetting,
    this.wholesaleEnabled,
    this.wholesalePrice,
    this.wholesaleMinQty,
    this.wholesaleTiers,
    this.saleType,
    this.wholesaleDetails,
    this.wholesaleBusinessOnly,
    this.fulfilment,
  });

  ProductModel.fromJson(Map<String, dynamic> json) {
    fats = json['fats'];
    vendorID = json['vendorID'];
    veg = json['veg'];
    publish = json['publish'];
    addOnsTitle = json['addOnsTitle'];
    calories = json['calories'];
    proteins = json['proteins'];
    addOnsPrice = json['addOnsPrice'];
    reviewsSum = json['reviewsSum'] ?? 0.0;
    takeawayOption = json['takeawayOption'];
    name = json['name'];
    reviewAttributes = json['reviewAttributes'];
    productSpecification = json['product_specification'];
    itemAttribute = json['item_attribute'] != null ? ItemAttribute.fromJson(json['item_attribute']) : null;
    id = json['id'];
    quantity = json['quantity'];
    grams = json['grams'];
    reviewsCount = json['reviewsCount'] ?? 0.0;
    disPrice = json['disPrice'] ?? "0";
    photos = json['photos'] ?? [];
    nonveg = json['nonveg'];
    photo = json['photo'];
    price = json['price'];
    categoryID = json['categoryID'];
    description = json['description'];
    createdAt = json['createdAt'];
    sectionId = json['section_id'];
    brandId = json['brandID'];
    isDigitalProduct = json['isDigitalProduct'];
    digitalProduct = json['digitalProduct'];
    if (json['taxSetting'] != null) {
      taxSetting = <TaxModel>[];
      json['taxSetting'].forEach((v) {
        taxSetting!.add(TaxModel.fromJson(v));
      });
    }
    wholesaleEnabled = parseWholesaleBool(json['wholesaleEnabled']);
    wholesalePrice = parseWholesaleString(json['wholesalePrice']);
    wholesaleMinQty = parseWholesaleString(json['wholesaleMinQty']);
    wholesaleTiers = WholesaleTier.parseList(json['wholesaleTiers']);
    if ((wholesalePrice ?? '').isNotEmpty && (wholesaleMinQty ?? '').isNotEmpty) {
      final legacy = WholesaleTier(minQty: wholesaleMinQty!, price: wholesalePrice!);
      if (wholesaleTiers!.isEmpty) {
        wholesaleTiers = [legacy];
      } else {
        // Same rule as the Store app: the web panels / POS edit only the
        // single-tier fields, so when they differ they win for tier 1.
        final tiers = [...wholesaleTiers!]..sort((a, b) => a.minQtyValue.compareTo(b.minQtyValue));
        if (tiers.first.minQty != legacy.minQty || tiers.first.price != legacy.price) {
          tiers[0] = legacy;
          wholesaleTiers = tiers;
        }
      }
    }
    wholesaleDetails = parseWholesaleString(json['wholesaleDetails']);
    final String rawSaleType = parseWholesaleString(json['saleType']).toLowerCase();
    saleType = rawSaleType.isEmpty ? null : rawSaleType;
    wholesaleBusinessOnly = parseWholesaleBool(json['wholesaleBusinessOnly']);
    fulfilment = parseFulfilment(json['fulfilment']);
  }

  /// Tiers sorted by minQty (or the legacy single tier).
  List<WholesaleTier> get sortedWholesaleTiers {
    final List<WholesaleTier> tiers = [...?wholesaleTiers];
    if (tiers.isEmpty && (wholesalePrice ?? '').isNotEmpty && (wholesaleMinQty ?? '').isNotEmpty) {
      tiers.add(WholesaleTier(minQty: wholesaleMinQty!, price: wholesalePrice!));
    }
    tiers.sort((a, b) => a.minQtyValue.compareTo(b.minQtyValue));
    return tiers;
  }

  /// Usable tiers (price > 0, minQty >= 2) **as the store set them**, whoever
  /// is looking. This is the raw document, so it answers "is this a wholesale
  /// product" even for a customer who may not buy wholesale - which is what
  /// [isWholesaleOnlyProduct] and therefore [hiddenForCustomer] need.
  List<WholesaleTier> get rawWholesaleTiers => wholesaleEnabled == true ? sortedWholesaleTiers.where((t) => t.isUsable).toList() : <WholesaleTier>[];

  /// The ONE switch of WEB spec §19, the app's equivalent of the website's
  /// `wholesaleEnabled = productData.wholesaleEnabled && customerMayBuyWholesale`
  /// in `processVendorData`: wholesale applies to this product **for this
  /// customer**. Everything wholesale hangs off it - the tiers, the badge, the
  /// ladder, the minimum quantity and the price charged - so withholding it
  /// here withholds wholesale on every screen at once.
  bool get wholesaleAvailableToCustomer => wholesaleEnabled == true && !wholesaleBlockedForCustomer;

  /// The tiers THIS customer may be given: empty for a customer without an
  /// approved business account, which is how a mixed product falls back to
  /// retail with no badge, no ladder and no pack minimum.
  List<WholesaleTier> get activeWholesaleTiers => wholesaleAvailableToCustomer ? rawWholesaleTiers : <WholesaleTier>[];

  bool get hasWholesaleTier => activeWholesaleTiers.isNotEmpty;

  /// Normalised sale type **for this customer**, see [saleType]: a customer who
  /// may not buy wholesale buys at retail, so nothing imposes a pack minimum
  /// on them (WEB spec §19; the website's `enforceSaleTypeQuantity` likewise
  /// does not raise such a customer's quantity).
  String get effectiveSaleType {
    if (!wholesaleAvailableToCustomer) return saleTypeRetail;
    return saleType == saleTypeWholesale ? saleTypeWholesale : saleTypeBoth;
  }

  /// Sale type as the STORE set it, whoever is looking (the raw document).
  String get rawSaleType {
    if (wholesaleEnabled != true) return saleTypeRetail;
    return saleType == saleTypeWholesale ? saleTypeWholesale : saleTypeBoth;
  }

  /// Wholesale-only product: retail price hidden, minimum quantity = first tier.
  bool get isWholesaleOnly => effectiveSaleType == saleTypeWholesale && hasWholesaleTier;

  /// Wholesale-only **as the store set it**, whoever is looking.
  ///
  /// The hide filter of WEB spec §19 reads THIS, not the computed price: a
  /// customer who may not buy wholesale has no tiers, so [isWholesaleOnly] is
  /// false for them and keying the filter on it would leak every
  /// wholesale-only product to exactly the customers it hides them from.
  bool get isWholesaleOnlyProduct => rawSaleType == saleTypeWholesale && rawWholesaleTiers.isNotEmpty;

  /// Wholesale withheld from this customer (WEB spec §19): **blanket**, for
  /// anyone without an approved business account, plus the per-product
  /// `wholesaleBusinessOnly` flag the store panel and store app write (STORE
  /// spec §3), which can only ever restrict further - never grant.
  bool get wholesaleBlockedForCustomer => !WholesaleEntitlement.mayBuyWholesale || (wholesaleBusinessOnly == true && !BusinessAccount.isApproved);

  /// A wholesale-only product a customer without an approved business account
  /// must not see at all: **hidden** from every listing and refused on a
  /// direct link, with a pointer to the business-account application.
  bool get hiddenForCustomer => isWholesaleOnlyProduct && wholesaleBlockedForCustomer;

  /// Kept for the screens that word the refusal: the same verdict as
  /// [hiddenForCustomer].
  bool get isBusinessOnlyProduct => hiddenForCustomer;

  /// Mirrors the Store app's `effectiveFulfilment`: the explicit [fulfilment]
  /// when set, else the legacy meaning of [takeawayOption].
  /// A product saved before `fulfilment` existed keeps the meaning the apps
  /// have always given `takeawayOption`: true = TAKEAWAY ONLY (the customer
  /// app hid it in Delivery mode and showed every product in TakeAway mode);
  /// false/absent = both Delivery and TakeAway.
  List<String> get effectiveFulfilment {
    final List<String> modes = allFulfilmentModes.where((m) => fulfilment?.contains(m) == true).toList();
    if (modes.isNotEmpty) return modes;
    return takeawayOption == true ? [fulfilmentTakeaway] : [fulfilmentDelivery, fulfilmentTakeaway];
  }

  /// Whether the product can be ordered with the order type [foodType] ("Delivery" / "TakeAway").
  bool allowsFoodType(String foodType) => effectiveFulfilment.contains(foodTypeToFulfilment(foodType));

  /// Minimum order quantity: first tier's minQty for wholesale-only products, else 1.
  int get minOrderQuantity {
    if (effectiveSaleType != saleTypeWholesale) return 1;
    final tiers = activeWholesaleTiers;
    return tiers.isEmpty ? 1 : tiers.first.minQtyValue;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['fats'] = fats;
    data['vendorID'] = vendorID;
    data['veg'] = veg;
    data['publish'] = publish;
    data['addOnsTitle'] = addOnsTitle;
    data['addOnsPrice'] = addOnsPrice;
    data['calories'] = calories;
    data['proteins'] = proteins;
    data['reviewsSum'] = reviewsSum;
    data['takeawayOption'] = takeawayOption;
    data['name'] = name;
    data['reviewAttributes'] = reviewAttributes;
    data['product_specification'] = productSpecification;
    if (itemAttribute != null) {
      data['item_attribute'] = itemAttribute!.toJson();
    }
    data['id'] = id;
    data['quantity'] = quantity;
    data['grams'] = grams;
    data['reviewsCount'] = reviewsCount;
    data['disPrice'] = disPrice;
    data['photos'] = photos;
    data['nonveg'] = nonveg;
    data['photo'] = photo;
    data['price'] = price;
    data['categoryID'] = categoryID;
    data['description'] = description;
    data['createdAt'] = createdAt;
    data['section_id'] = sectionId;
    data['brandID'] = brandId;
    data['isDigitalProduct'] = isDigitalProduct;
    data['digitalProduct'] = digitalProduct;
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ItemAttribute {
  List<Attributes>? attributes;
  List<Variants>? variants;

  ItemAttribute({this.attributes, this.variants});

  ItemAttribute.fromJson(Map<String, dynamic> json) {
    if (json['attributes'] != null) {
      attributes = <Attributes>[];
      json['attributes'].forEach((v) {
        attributes!.add(Attributes.fromJson(v));
      });
    }
    if (json['variants'] != null) {
      variants = <Variants>[];
      json['variants'].forEach((v) {
        variants!.add(Variants.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (attributes != null) {
      data['attributes'] = attributes!.map((v) => v.toJson()).toList();
    }
    if (variants != null) {
      data['variants'] = variants!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Attributes {
  String? attributeId;
  List<String>? attributeOptions;

  Attributes({this.attributeId, this.attributeOptions});

  Attributes.fromJson(Map<String, dynamic> json) {
    attributeId = json['attribute_id'];
    attributeOptions = json['attribute_options'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['attribute_id'] = attributeId;
    data['attribute_options'] = attributeOptions;
    return data;
  }
}

class Variants {
  String? variantId;
  String? variantImage;
  String? variantPrice;
  String? variantQuantity;
  String? variantSku;

  /// This variant's **TIER-ONE** wholesale price - not its only price.
  ///
  /// The product's tiers own the quantity breaks and the steps between them;
  /// this figure shifts the whole ladder to start at it, by the same
  /// DIFFERENCE at every tier (STORE spec §3 / WEB spec §10, "A variant shifts
  /// the ladder, it does not replace it" - 30 September). **Blank is the
  /// normal case** and means the product's ladder applies unchanged.
  /// See `WholesalePricing.customerTiers`.
  ///
  /// Round-tripped so a write-back of item_attribute (stock update) never
  /// drops it.
  ///
  /// Read from the app's own `variant_wholesale_price` key, falling back to
  /// the Store spec's `wholesalePrice` on `item_attribute.variants[]`
  /// (STORE spec §3) when only that one is present.
  String? variantWholesalePrice;

  /// Variant-level wholesale switch, `item_attribute.variants[].wholesaleEnabled`
  /// (STORE spec §3). **Tri-state on purpose:**
  /// * `false` (explicitly written) - THIS variant is retail-only, whatever the
  ///   product-level switch says;
  /// * `true` - no change: the product's tiers still govern;
  /// * null (absent, blank, or not a boolean) - no opinion, today's behaviour:
  ///   the product-level switch and thresholds govern.
  ///
  /// An absent or default-written field therefore can never switch wholesale
  /// off - see [parseWholesaleBoolOrNull].
  bool? wholesaleEnabled;

  /// Variant-level `wholesaleMinQty` (STORE spec §3): the quantity at which
  /// THIS variant reaches its wholesale price, replacing the product's first
  /// threshold for this variant only. ""/absent = the product's threshold.
  String? wholesaleMinQty;

  Variants({this.variantId, this.variantImage, this.variantPrice, this.variantQuantity, this.variantSku, this.variantWholesalePrice, this.wholesaleEnabled, this.wholesaleMinQty});

  Variants.fromJson(Map<String, dynamic> json) {
    variantId = json['variant_id'];
    variantImage = json['variant_image'];
    variantPrice = json['variant_price'] ?? '0';
    variantQuantity = json['variant_quantity'] ?? '0';
    variantSku = json['variant_sku'];
    if (json.containsKey('variant_wholesale_price')) {
      variantWholesalePrice = parseWholesaleString(json['variant_wholesale_price']);
    } else if (json.containsKey('wholesalePrice')) {
      variantWholesalePrice = parseWholesaleString(json['wholesalePrice']);
    } else {
      variantWholesalePrice = null;
    }
    wholesaleEnabled = parseWholesaleBoolOrNull(json['wholesaleEnabled']);
    final String minQty = parseWholesaleString(json['wholesaleMinQty']);
    wholesaleMinQty = minQty.isEmpty ? null : minQty;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['variant_id'] = variantId;
    data['variant_image'] = variantImage;
    data['variant_price'] = variantPrice;
    data['variant_quantity'] = variantQuantity;
    data['variant_sku'] = variantSku;
    // Written back only when the document carried them, so a stock-update
    // round trip of item_attribute never drops - nor invents - these fields.
    if (variantWholesalePrice != null) data['variant_wholesale_price'] = variantWholesalePrice;
    if (wholesaleEnabled != null) data['wholesaleEnabled'] = wholesaleEnabled;
    if (wholesaleMinQty != null) data['wholesaleMinQty'] = wholesaleMinQty;
    return data;
  }

  /// The variant's own wholesale threshold when it carries a usable one
  /// (>= 2 units, the same floor [WholesaleTier.isUsable] applies), else null
  /// = use the product's.
  int? get wholesaleMinQtyValue {
    final String raw = (wholesaleMinQty ?? '').trim();
    if (raw.isEmpty) return null;
    final int qty = int.tryParse(raw) ?? (double.tryParse(raw)?.toInt() ?? 0);
    return qty >= 2 ? qty : null;
  }
}

class ReviewsAttribute {
  num? reviewsCount;
  num? reviewsSum;

  ReviewsAttribute({this.reviewsCount, this.reviewsSum});

  ReviewsAttribute.fromJson(Map<String, dynamic> json) {
    reviewsCount = json['reviewsCount'] ?? 0;
    reviewsSum = json['reviewsSum'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['reviewsCount'] = reviewsCount;
    data['reviewsSum'] = reviewsSum;
    return data;
  }
}

/// The app's order-type preference ("Delivery" / "TakeAway", possibly stored
/// translated by older builds) -> fulfilment mode.
String foodTypeToFulfilment(String foodType) {
  final String v = foodType.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  return v == 'takeaway' || foodType == 'TakeAway'.tr ? ProductModel.fulfilmentTakeaway : ProductModel.fulfilmentDelivery;
}

/// Tolerant parsing for wholesale fields: bools may arrive as strings.
bool parseWholesaleBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.trim().toLowerCase() == 'true' || value.trim() == '1';
  return false;
}

/// Tri-state read of a wholesale bool: `true` / `false` only when the document
/// says so EXPLICITLY, null when the field is absent, null or blank.
///
/// A missing or blank field must never read as `false`, because `false` is a
/// decision ("this one is retail-only") while absence means "no opinion, the
/// level above governs". Only a real boolean, a number, or the words
/// "true"/"false"/"1"/"0" count as a decision.
bool? parseWholesaleBoolOrNull(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final String v = value.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
  }
  return null;
}

/// Parses `fulfilment` (list or comma-separated string); null when absent/empty.
List<String>? parseFulfilment(dynamic value) {
  Iterable<dynamic> raw;
  if (value is List) {
    raw = value;
  } else if (value is String) {
    raw = value.split(',');
  } else {
    return null;
  }
  final List<String> modes =
      raw
          .map((e) => e.toString().trim().toLowerCase())
          .map((e) => e == 'take_away' || e == 'take-away' ? ProductModel.fulfilmentTakeaway : e)
          .toSet()
          .where(ProductModel.allFulfilmentModes.contains)
          .toList();
  return modes.isEmpty ? null : modes;
}

String parseWholesaleString(dynamic value) {
  if (value == null) return '';
  if (value is num) {
    if (value is int) return value.toString();
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
  return value.toString().trim();
}

/// One wholesale price tier: from [minQty] units the unit price is [price].
class WholesaleTier {
  String minQty;
  String price;

  WholesaleTier({required this.minQty, required this.price});

  factory WholesaleTier.fromJson(Map<String, dynamic> json) => WholesaleTier(minQty: parseWholesaleString(json['minQty'] ?? json['min_qty']), price: parseWholesaleString(json['price']));

  Map<String, dynamic> toJson() => {'minQty': minQty, 'price': price};

  int get minQtyValue => int.tryParse(minQty) ?? (double.tryParse(minQty)?.toInt() ?? 0);

  double get priceValue => double.tryParse(price) ?? 0;

  bool get isUsable => minQtyValue >= 2 && priceValue > 0;

  static List<WholesaleTier> parseList(dynamic value) {
    if (value is! List) return <WholesaleTier>[];
    final List<WholesaleTier> tiers = [];
    for (final item in value) {
      if (item is Map) {
        final tier = WholesaleTier.fromJson(Map<String, dynamic>.from(item));
        if (tier.minQty.isNotEmpty || tier.price.isNotEmpty) tiers.add(tier);
      }
    }
    tiers.sort((a, b) => a.minQtyValue.compareTo(b.minQtyValue));
    return tiers;
  }
}
