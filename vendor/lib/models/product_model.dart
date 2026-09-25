import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor/models/tax_model.dart';

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

  /// Wholesale pricing (set by the store): once a cart line reaches
  /// [wholesaleMinQty] units, every unit on that line is charged
  /// [wholesalePrice]. Both values are strings (like price/disPrice) and are
  /// written back as "" whenever [wholesaleEnabled] is false.
  bool? wholesaleEnabled;
  String? wholesalePrice;
  String? wholesaleMinQty;

  /// Wholesale price tiers, sorted by minQty ascending (max [maxWholesaleTiers]).
  /// Stored as `wholesaleTiers: [{minQty: "5", price: "6557127"}, ...]`.
  /// For compatibility, [wholesalePrice]/[wholesaleMinQty] always mirror the
  /// FIRST (lowest-quantity) tier. Products that only have the legacy fields
  /// load as a single tier.
  List<WholesaleTier>? wholesaleTiers;

  /// "retail" | "wholesale" | "both". Absent: "retail" when wholesale is off,
  /// "both" when it is on. For "wholesale" the minimum order quantity is the
  /// first tier's minQty.
  String? saleType;

  /// When true, only verified Business customers get wholesale prices
  /// (enforced by the customer app).
  bool? wholesaleBusinessOnly;

  /// Subset of ["delivery", "takeaway"]; absent/empty = both.
  List<String>? fulfilment;

  static const int maxWholesaleTiers = 5;
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
        // The web panels and POS edit only the single-tier fields. If they were
        // changed there, they win for tier 1 - otherwise the next save here
        // would write the old tier 1 back over the panel's edit.
        final tiers = [...wholesaleTiers!]..sort((a, b) => a.minQtyValue.compareTo(b.minQtyValue));
        if (tiers.first.minQty != legacy.minQty || tiers.first.price != legacy.price) {
          tiers[0] = legacy;
          wholesaleTiers = tiers;
        }
      }
    }
    final String rawSaleType = parseWholesaleString(json['saleType']).toLowerCase();
    saleType = rawSaleType.isEmpty ? null : rawSaleType;
    wholesaleBusinessOnly = parseWholesaleBool(json['wholesaleBusinessOnly']);
    fulfilment = parseFulfilment(json['fulfilment']);
  }

  /// Tiers to use/write: [wholesaleTiers] sorted, or the legacy single tier.
  List<WholesaleTier> get sortedWholesaleTiers {
    final List<WholesaleTier> tiers = [...?wholesaleTiers];
    if (tiers.isEmpty && (wholesalePrice ?? '').isNotEmpty && (wholesaleMinQty ?? '').isNotEmpty) {
      tiers.add(WholesaleTier(minQty: wholesaleMinQty!, price: wholesalePrice!));
    }
    tiers.sort((a, b) => a.minQtyValue.compareTo(b.minQtyValue));
    return tiers;
  }

  /// Usable tiers (price > 0, minQty >= 2) when wholesale is on, else empty.
  List<WholesaleTier> get activeWholesaleTiers => wholesaleEnabled == true ? sortedWholesaleTiers.where((t) => t.isUsable).toList() : <WholesaleTier>[];

  /// True when the product has a usable wholesale tier configured.
  bool get hasWholesaleTier => activeWholesaleTiers.isNotEmpty;

  /// Normalised sale type, see [saleType].
  String get effectiveSaleType {
    if (wholesaleEnabled != true) return saleTypeRetail;
    return saleType == saleTypeWholesale ? saleTypeWholesale : saleTypeBoth;
  }

  /// Normalised fulfilment modes, see [fulfilment].
  ///
  /// A product saved before `fulfilment` existed keeps the meaning the apps
  /// have always given `takeawayOption`: true = TAKEAWAY ONLY (the customer
  /// app hid it in Delivery mode and showed every product in TakeAway mode);
  /// false/absent = both Delivery and TakeAway.
  List<String> get effectiveFulfilment {
    final List<String> modes = allFulfilmentModes.where((m) => fulfilment?.contains(m) == true).toList();
    if (modes.isNotEmpty) return modes;
    return takeawayOption == true ? [fulfilmentTakeaway] : [fulfilmentDelivery, fulfilmentTakeaway];
  }

  /// Whether the owner explicitly chose the modes (the list only flags those).
  bool get hasExplicitFulfilment => allFulfilmentModes.any((m) => fulfilment?.contains(m) == true);

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
    } else {
      // Explicit null so removing every attribute actually clears the variants.
      data['item_attribute'] = null;
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
    final bool enabled = wholesaleEnabled ?? false;
    final List<WholesaleTier> tiers = enabled ? sortedWholesaleTiers : <WholesaleTier>[];
    data['wholesaleEnabled'] = enabled;
    data['wholesaleTiers'] = tiers.map((t) => t.toJson()).toList();
    // Legacy single-tier mirror of the first tier (web panels, POS, customer app).
    data['wholesalePrice'] = tiers.isNotEmpty ? tiers.first.price : '';
    data['wholesaleMinQty'] = tiers.isNotEmpty ? tiers.first.minQty : '';
    data['saleType'] = effectiveSaleType;
    data['wholesaleBusinessOnly'] = enabled && wholesaleBusinessOnly == true;
    // Only when the owner chose the modes: writing the default would mark every
    // older product as explicitly restricted the first time it is saved.
    if (hasExplicitFulfilment) {
      data['fulfilment'] = allFulfilmentModes.where((m) => fulfilment!.contains(m)).toList();
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

  /// Variant-level wholesale unit price; "" means "use the product's wholesalePrice".
  /// This app edits it; the Store panel may write it as `wholesalePrice`
  /// instead (STORE spec §3), which is accepted on read.
  String? variantWholesalePrice;

  /// Store-panel variant fields (`item_attribute.variants[].wholesaleEnabled` /
  /// `wholesaleMinQty`, STORE spec §3). This app has no editor for them: they
  /// are parsed and written straight back so saving a product here can never
  /// drop what the Store panel set. Null = the variant does not carry the
  /// field, and nothing is invented on write.
  bool? wholesaleEnabled;
  String? wholesaleMinQty;

  Variants({this.variantId, this.variantImage, this.variantPrice, this.variantQuantity, this.variantSku, this.variantWholesalePrice, this.wholesaleEnabled, this.wholesaleMinQty});

  Variants.fromJson(Map<String, dynamic> json) {
    variantId = json['variant_id'];
    variantImage = json['variant_image'];
    variantPrice = json['variant_price'] ?? '0';
    variantQuantity = json['variant_quantity'] ?? '0';
    variantSku = json['variant_sku'];
    variantWholesalePrice = parseWholesaleString(json.containsKey('variant_wholesale_price') ? json['variant_wholesale_price'] : json['wholesalePrice']);
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
    data['variant_wholesale_price'] = variantWholesalePrice ?? '';
    if (wholesaleEnabled != null) data['wholesaleEnabled'] = wholesaleEnabled;
    if (wholesaleMinQty != null) data['wholesaleMinQty'] = wholesaleMinQty;
    return data;
  }
}

/// Tolerant parsing for wholesale fields: bools may arrive as strings,
/// numbers as num or string.
bool parseWholesaleBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.trim().toLowerCase() == 'true' || value.trim() == '1';
  return false;
}

/// Tri-state read of a wholesale bool: `true` / `false` only when the document
/// says so EXPLICITLY, null when the field is absent, null or blank - so an
/// absent or blank field is never mistaken for a decision to switch off.
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

/// Parses `fulfilment`: a list (or comma-separated string) of modes; keeps
/// only known modes. Returns null when absent/empty (= both modes).
List<String>? parseFulfilment(dynamic value) {
  Iterable<dynamic> raw;
  if (value is List) {
    raw = value;
  } else if (value is String) {
    raw = value.split(',');
  } else {
    return null;
  }
  final List<String> modes = raw.map((e) => e.toString().trim().toLowerCase()).map((e) => e == 'take_away' || e == 'take-away' ? ProductModel.fulfilmentTakeaway : e).toSet().where(ProductModel.allFulfilmentModes.contains).toList();
  return modes.isEmpty ? null : modes;
}

/// One wholesale price tier: from [minQty] units the unit price is [price].
class WholesaleTier {
  String minQty;
  String price;

  WholesaleTier({required this.minQty, required this.price});

  factory WholesaleTier.fromJson(Map<String, dynamic> json) =>
      WholesaleTier(minQty: parseWholesaleString(json['minQty'] ?? json['min_qty']), price: parseWholesaleString(json['price']));

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

String parseWholesaleString(dynamic value) {
  if (value == null) return '';
  if (value is num) {
    if (value is int) return value.toString();
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }
  return value.toString().trim();
}

class ProductSpecificationModel {
  String? lable;
  String? value;

  ProductSpecificationModel({this.lable, this.value});

  ProductSpecificationModel.fromJson(Map<String, dynamic> json) {
    lable = json['lable'];
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['lable'] = lable;
    data['value'] = value;
    return data;
  }
}
