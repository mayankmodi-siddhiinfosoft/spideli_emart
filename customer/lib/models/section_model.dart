import 'package:customer/models/admin_commission_model.dart';
import 'package:customer/models/platform_fee_model.dart';

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

  /// Regions the service is offered in (spec 18.8). Empty/absent = every region.
  List<String>? regionIds;

  /// `service_groups` id this service belongs to (spec 18.11). "" / absent =
  /// ungrouped. Read only.
  String? serviceGroup;

  /// Position of the service (lower first); decides order within a group.
  /// Read only.
  num? order;

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
    referralAmount = json['referralAmount'] ?? '';
    serviceType = json['serviceType'] ?? '';
    color = json['color'];
    name = json['name'];
    sectionImage = json['sectionImage'];
    markerIcon = json['markerIcon'];
    id = json['id'];
    adminCommision = json.containsKey('adminCommision') ? AdminCommission.fromJson(json['adminCommision']) : null;
    isActive = json['isActive'];
    theme = json['theme'] ?? "theme_2";
    dineInActive = json['dine_in_active'] ?? false;
    isProductDetails = json['is_product_details'] ?? false;
    serviceTypeFlag = json['serviceTypeFlag'] ?? '';
    deliveryCharge = json['delivery_charge'] ?? '';
    rideType = json['rideType'] ?? 'ride';

    // 👇 Safe parsing for number (handles NaN, double, int)
    final rawRadius = json['nearByRadius'];
    if (rawRadius == null || rawRadius is! num || rawRadius.isNaN) {
      nearByRadius = 5000;
    } else {
      nearByRadius = rawRadius.toInt();
    }
    platformFee = PlatformFeeModel.fromJson(json['platformFee']);
    packagingChargeEnable = json['packagingChargeEnable'] ?? false;
    regionIds = json['regionIds'] is List ? (json['regionIds'] as List).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() : null;
    serviceGroup = json['serviceGroup']?.toString();
    order = json['order'] is num ? json['order'] as num : num.tryParse(json['order']?.toString() ?? '');
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
    if (regionIds != null) data['regionIds'] = regionIds;
    if (serviceGroup != null) data['serviceGroup'] = serviceGroup;
    if (order != null) data['order'] = order;

    return data;
  }
}
