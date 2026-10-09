import 'package:customer/models/admin_commission_model.dart';
import 'package:customer/models/platform_fee_model.dart';
import 'package:customer/utils/product_delivery_charge.dart';

class SectionModel {
  String? referralAmount;
  String? serviceType;
  String? color;
  String? name;
  String? sectionImage;
  String? markerIcon;
  String? id;
  bool? isActive;
  bool? dineInActive;
  bool? isProductDetails;
  String? serviceTypeFlag;
  String? deliveryCharge;
  String? rideType;
  String? theme;
  int? nearByRadius;
  AdminCommission? adminCommision;
  PlatformFeeModel? platformFee;
  bool? packagingChargeEnable;

  /// `is_delivery_charge_customization` (Doc 60): delivery is charged from the
  /// products' own `delivery_charges` tiers. Set by the admin for the
  /// e-commerce / multivendor-delivery services only. The cart reads it fresh
  /// (FireStoreUtils.getSectionDeliveryChargeCustomization); this copy is
  /// only the starting value.
  bool isDeliveryChargeCustomization = false;

  /// Regions the service is offered in (spec 18.8). Empty/absent = every region.
  List<String>? regionIds;

  /// `service_groups` id this service belongs to (spec 18.11). "" / absent =
  /// ungrouped. Read only.
  String? serviceGroup;

  /// Position of the service (lower first); decides order within a group.
  /// Read only.
  num? order;

  /// Lower [order] first; a section without one goes last; ties by name.
  static int compareByOrder(SectionModel a, SectionModel b) {
    final num ao = a.order ?? double.infinity;
    final num bo = b.order ?? double.infinity;
    final int byOrder = ao.compareTo(bo);
    return byOrder != 0 ? byOrder : (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
  }

  SectionModel({
    this.referralAmount,
    this.serviceType,
    this.color,
    this.name,
    this.sectionImage,
    this.markerIcon,
    this.id,
    this.isActive,
    this.theme,
    this.adminCommision,
    this.dineInActive,
    this.deliveryCharge,
    this.nearByRadius,
    this.isProductDetails,
    this.serviceTypeFlag,
    this.rideType,
    this.platformFee,
    this.packagingChargeEnable,
    this.regionIds,
    this.serviceGroup,
    this.order,
  });

  SectionModel.fromJson(Map<String, dynamic> json) {
    // Read tolerantly: a value of an unexpected type (a number where text is
    // expected, a missing platformFee) used to throw, and getSections then
    // dropped that section, so an active service silently disappeared.
    referralAmount = _text(json['referralAmount']) ?? '';
    serviceType = _text(json['serviceType']) ?? '';
    color = _text(json['color']);
    name = _text(json['name']);
    sectionImage = _text(json['sectionImage']);
    markerIcon = _text(json['markerIcon']);
    id = _text(json['id']);
    adminCommision = json['adminCommision'] is Map ? _tryParse(() => AdminCommission.fromJson(Map<String, dynamic>.from(json['adminCommision']))) : null;
    isActive = json['isActive'] is bool ? json['isActive'] as bool : json['isActive']?.toString() == 'true';
    theme = _text(json['theme']) ?? "theme_2";
    dineInActive = json['dine_in_active'] == true;
    isProductDetails = json['is_product_details'] == true;
    serviceTypeFlag = _text(json['serviceTypeFlag']) ?? '';
    deliveryCharge = _text(json['delivery_charge']) ?? '';
    rideType = _text(json['rideType']) ?? 'ride';

    // 👇 Safe parsing for number (handles NaN, double, int)
    final rawRadius = json['nearByRadius'];
    if (rawRadius == null || rawRadius is! num || rawRadius.isNaN) {
      nearByRadius = 5000;
    } else {
      nearByRadius = rawRadius.toInt();
    }
    platformFee = json['platformFee'] is Map ? _tryParse(() => PlatformFeeModel.fromJson(Map<String, dynamic>.from(json['platformFee']))) : null;
    packagingChargeEnable = json['packagingChargeEnable'] == true;
    isDeliveryChargeCustomization = ProductDeliveryCharge.isEnabled(json['is_delivery_charge_customization']);
    regionIds = json['regionIds'] is List ? (json['regionIds'] as List).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() : null;
    serviceGroup = json['serviceGroup']?.toString();
    order = json['order'] is num ? json['order'] as num : num.tryParse(json['order']?.toString() ?? '');
  }

  static String? _text(dynamic value) => value == null ? null : (value is String ? value : (value is Map || value is List ? null : value.toString()));

  static T? _tryParse<T>(T Function() parse) {
    try {
      return parse();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['referralAmount'] = referralAmount;
    data['serviceType'] = serviceType;
    data['color'] = color;
    data['name'] = name;
    data['sectionImage'] = sectionImage;
    data['markerIcon'] = markerIcon;
    data['rideType'] = rideType;
    data['theme'] = theme;
    if (adminCommision != null) {
      data['adminCommision'] = adminCommision!.toJson();
    }
    data['id'] = id;
    data['isActive'] = isActive;
    data['dine_in_active'] = dineInActive;
    data['is_product_details'] = isProductDetails;
    data['serviceTypeFlag'] = serviceTypeFlag;
    data['delivery_charge'] = deliveryCharge;
    data['nearByRadius'] = nearByRadius;

    if (platformFee?.enable == true) {
      data['platformFee'] = platformFee?.toJson();
    }
    data['packagingChargeEnable'] = packagingChargeEnable;
    if (isDeliveryChargeCustomization) data['is_delivery_charge_customization'] = true;
    if (regionIds != null) data['regionIds'] = regionIds;
    if (serviceGroup != null) data['serviceGroup'] = serviceGroup;
    if (order != null) data['order'] = order;

    return data;
  }
}
