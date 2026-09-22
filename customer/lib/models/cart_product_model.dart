import 'dart:convert';

import 'package:customer/models/product_model.dart' show ProductModel, WholesaleTier, parseWholesaleBool, parseWholesaleString;
import 'package:customer/models/tax_model.dart';

class CartProductModel {
  String? id;
  String? categoryId;
  String? name;
  String? photo;
  String? price;
  String? discountPrice;
  String? vendorID;
  int? quantity;
  String? extrasPrice;
  List<dynamic>? extras;
  VariantInfo? variantInfo;
  List<TaxModel>? taxSetting;

  /// Order line only (vendor_orders.products[]): true when [price] is the
  /// wholesale unit price actually charged; [wholesaleMinQty] is that tier's
  /// minQty. Same fields the Store app reads (vendor CartProductModel).
  bool? isWholesale;
  String? wholesaleMinQty;

  /// Cart only (local sqflite column `line_meta`, never written to Firestore):
  /// the product's wholesale tiers / sale type / fulfilment captured when the
  /// line was added, so the cart can reprice when the quantity changes.
  CartLineMeta? lineMeta;

  CartProductModel({
    this.id,
    this.categoryId,
    this.name,
    this.photo,
    this.price,
    this.discountPrice,
    this.vendorID,
    this.quantity,
    this.extrasPrice,
    this.variantInfo,
    this.extras,
    this.taxSetting,
    this.isWholesale,
    this.wholesaleMinQty,
    this.lineMeta,
  });

  CartProductModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    categoryId = json['category_id'];
    name = json['name'];
    photo = json['photo'];
    price = json['price'] ?? "0.0";
    discountPrice = json['discountPrice'] ?? "0.0";
    vendorID = json['vendorID'];
    quantity = json['quantity'];
    extrasPrice = json['extras_price'];

    extras =
        json['extras'] == "null" || json['extras'] == null
            ? null
            : "String" == json['extras'].runtimeType.toString()
            ? List<dynamic>.from(jsonDecode(json['extras']))
            : List<dynamic>.from(json['extras']);

    variantInfo =
        json['variant_info'] == "null" || json['variant_info'] == null
            ? null
            : "String" == json['variant_info'].runtimeType.toString()
            ? VariantInfo.fromJson(jsonDecode(json['variant_info']))
            : VariantInfo.fromJson(json['variant_info']);

    taxSetting =
        json['taxSetting'] == null
            ? []
            : json['taxSetting'] is String
            ? (jsonDecode(json['taxSetting']) as List).map((e) => TaxModel.fromJson(e)).toList()
            : json['taxSetting'] is List
            ? (json['taxSetting'] as List).map((e) => TaxModel.fromJson(e)).toList()
            : [];

    isWholesale = parseWholesaleBool(json['isWholesale']);
    wholesaleMinQty = parseWholesaleString(json['wholesaleMinQty']);
    lineMeta = CartLineMeta.tryParse(json['line_meta']);
  }

  /// Firestore order line.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['category_id'] = categoryId;
    data['name'] = name;
    data['photo'] = photo;
    data['price'] = price;
    data['discountPrice'] = discountPrice;
    data['vendorID'] = vendorID;
    data['quantity'] = quantity;
    data['extras_price'] = extrasPrice;
    data['extras'] = extras;
    if (variantInfo != null) {
      data['variant_info'] = variantInfo?.toJson(); // Handle null value
    }
    // ✅ Convert List<Map> to String
    data['taxSetting'] = taxSetting == null ? [] : taxSetting!.map((e) => e.toJson()).toList();
    data['isWholesale'] = isWholesale ?? false;
    data['wholesaleMinQty'] = wholesaleMinQty ?? '';
    return data;
  }

  /// Local cart row (sqflite `cart_products` columns only).
  Map<String, dynamic> toDbJson() {
    final Map<String, dynamic> data = toJson()
      ..remove('isWholesale')
      ..remove('wholesaleMinQty');
    data['variant_info'] = jsonEncode(variantInfo);
    data['extras'] = jsonEncode(extras);
    data['taxSetting'] = jsonEncode(taxSetting);
    data['line_meta'] = lineMeta == null ? null : jsonEncode(lineMeta!.toJson());
    return data;
  }

  static double _num(String? value) => double.tryParse(value ?? '') ?? 0;

  /// Unit price actually charged on a stored ORDER line: the wholesale price
  /// when [isWholesale] (never re-derived), else discountPrice when set, else
  /// price - the Store app's `unitPrice`.
  double get unitPrice {
    final double linePrice = _num(price);
    if (isWholesale == true) return linePrice;
    final double lineDiscount = _num(discountPrice);
    return lineDiscount > 0 ? lineDiscount : linePrice;
  }

  /// Retail unit price of a CART line: discountPrice when set and lower than
  /// price, else price.
  double get retailUnitPrice {
    final double linePrice = _num(price);
    final double lineDiscount = _num(discountPrice);
    if (lineDiscount > 0 && (linePrice <= 0 || lineDiscount < linePrice)) return lineDiscount;
    return linePrice;
  }

  /// Wholesale pricing of a CART line for its current [quantity] (spec 8.2):
  /// the highest tier whose minQty <= quantity, only when its price is lower
  /// than [retailUnitPrice] - the customer always pays the lower price.
  /// Each cart line (product or product variant) is priced on its own.
  LinePrice get linePrice => LinePrice.resolve(retail: retailUnitPrice, tiers: lineMeta?.tiers ?? const <WholesaleTier>[], quantity: quantity ?? 0);

  /// Unit price charged for this cart line right now.
  double get chargedUnitPrice => linePrice.unit;

  /// Minimum quantity for this line (wholesale-only products), else 1.
  int get minOrderQuantity {
    final int min = lineMeta?.minOrderQty ?? 1;
    return min < 1 ? 1 : min;
  }

  /// The order line to write: the charged unit price in [price] (and
  /// discountPrice "0" so any reader using "discountPrice when > 0, else
  /// price" gets the same figure), plus isWholesale / wholesaleMinQty.
  CartProductModel toOrderLine() {
    final LinePrice p = linePrice;
    final bool discountApplies = !p.isWholesale && _num(discountPrice) > 0 && _num(discountPrice) == p.unit;
    return CartProductModel(
      id: id,
      categoryId: categoryId,
      name: name,
      photo: photo,
      price: p.isWholesale ? _plain(p.unit) : price,
      discountPrice: p.isWholesale ? "0" : (discountApplies ? discountPrice : "0"),
      vendorID: vendorID,
      quantity: quantity,
      extrasPrice: extrasPrice,
      variantInfo: variantInfo,
      extras: extras,
      taxSetting: taxSetting,
      isWholesale: p.isWholesale,
      wholesaleMinQty: p.isWholesale ? p.minQty : '',
    );
  }

  static String _plain(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Price of one cart line at its quantity.
class LinePrice {
  final double unit;
  final bool isWholesale;
  final String minQty;

  const LinePrice({required this.unit, required this.isWholesale, required this.minQty});

  /// The highest tier whose minQty <= [quantity], only when cheaper than
  /// [retail]; otherwise [retail].
  static LinePrice resolve({required double retail, required List<WholesaleTier> tiers, required int quantity}) {
    WholesaleTier? reached;
    for (final WholesaleTier tier in tiers) {
      if (tier.isUsable && tier.minQtyValue <= quantity && (reached == null || tier.minQtyValue >= reached.minQtyValue)) reached = tier;
    }
    if (reached != null && (retail <= 0 || reached.priceValue < retail)) {
      return LinePrice(unit: reached.priceValue, isWholesale: true, minQty: reached.minQty);
    }
    return LinePrice(unit: retail, isWholesale: false, minQty: '');
  }
}

/// Product data a cart line needs to reprice itself (local cart only).
class CartLineMeta {
  /// Usable wholesale tiers for this line, commission-inclusive (the same
  /// basis as the line's price), tier 1 replaced by the variant's wholesale
  /// price when set. Empty when wholesale does not apply to this customer.
  List<WholesaleTier> tiers;

  /// Effective sale type of the product ("retail" | "wholesale" | "both").
  String saleType;

  /// Minimum order quantity (first tier's minQty for wholesale-only products).
  int minOrderQty;

  /// Effective fulfilment modes of the product (["delivery", "takeaway"]).
  List<String> fulfilment;

  CartLineMeta({required this.tiers, required this.saleType, required this.minOrderQty, required this.fulfilment});

  bool get isWholesaleOnly => saleType == ProductModel.saleTypeWholesale;

  Map<String, dynamic> toJson() => {'tiers': tiers.map((e) => e.toJson()).toList(), 'saleType': saleType, 'minOrderQty': minOrderQty, 'fulfilment': fulfilment};

  static CartLineMeta? tryParse(dynamic raw) {
    try {
      dynamic value = raw;
      if (value is String) {
        if (value.isEmpty || value == 'null') return null;
        value = jsonDecode(value);
      }
      if (value is! Map) return null;
      final Map<String, dynamic> json = Map<String, dynamic>.from(value);
      return CartLineMeta(
        tiers: WholesaleTier.parseList(json['tiers']),
        saleType: parseWholesaleString(json['saleType']).isEmpty ? ProductModel.saleTypeRetail : parseWholesaleString(json['saleType']),
        minOrderQty: int.tryParse(parseWholesaleString(json['minOrderQty'])) ?? 1,
        fulfilment: json['fulfilment'] is List ? List<String>.from((json['fulfilment'] as List).map((e) => e.toString())) : <String>[],
      );
    } catch (_) {
      return null;
    }
  }
}

class VariantInfo {
  String? variantId;
  String? variantPrice;
  String? variantSku;
  String? variantImage;
  Map<String, dynamic>? variantOptions;

  VariantInfo({this.variantId, this.variantPrice, this.variantSku, this.variantImage, this.variantOptions});

  VariantInfo.fromJson(Map<String, dynamic> json) {
    variantId = json['variant_id'] ?? '';
    variantPrice = json['variant_price'].toString();
    variantSku = json['variant_sku'] ?? '';
    variantImage = json['variant_image'] ?? '';
    variantOptions = json['variant_options'] ?? {};
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['variant_id'] = variantId;
    data['variant_price'] = variantPrice;
    data['variant_sku'] = variantSku;
    data['variant_image'] = variantImage;
    data['variant_options'] = variantOptions;
    return data;
  }
}
