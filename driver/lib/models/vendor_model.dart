import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/models/admin_commission.dart';
import 'package:driver/models/subscription_plan_model.dart';

class VendorModel {
  String? author;
  bool? dineInActive;
  String? openDineTime;
  List<dynamic>? categoryID;
  String? id;
  String? categoryPhoto;
  List<dynamic>? restaurantMenuPhotos;
  List<WorkingHours>? workingHours;
  String? location;
  String? fcmToken;
  G? g;
  bool? hidephotos;
  bool? reststatus;
  Filters? filters;
  AdminCommission? adminCommission;
  String? photo;
  String? description;
  num? walletAmount;
  String? closeDineTime;
  String? zoneId;
  Timestamp? createdAt;
  double? longitude;
  bool? enabledDiveInFuture;
  String? restaurantCost;
  DeliveryCharge? deliveryCharge;
  String? authorProfilePic;
  String? authorName;
  String? phonenumber;
  List<SpecialDiscount>? specialDiscount;
  bool? specialDiscountEnable;
  GeoPoint? coordinates;
  num? reviewsSum;
  num? reviewsCount;
  List<dynamic>? photos;
  String? title;
  List<dynamic>? categoryTitle;
  double? latitude;
  String? subscriptionPlanId;
  Timestamp? subscriptionExpiryDate;
  SubscriptionPlanModel? subscriptionPlan;
  String? subscriptionTotalOrders;
  bool? isSelfDelivery;
  String? packagingCharge;

  VendorModel(
      {this.author,
      this.dineInActive,
      this.openDineTime,
      this.categoryID,
      this.id,
      this.categoryPhoto,
      this.restaurantMenuPhotos,
      this.workingHours,
      this.location,
      this.fcmToken,
      this.g,
      this.hidephotos,
      this.reststatus,
      this.filters,
      this.reviewsCount,
      this.photo,
      this.description,
      this.walletAmount,
      this.closeDineTime,
      this.zoneId,
      this.createdAt,
      this.longitude,
      this.enabledDiveInFuture,
      this.restaurantCost,
      this.deliveryCharge,
      this.adminCommission,
      this.authorProfilePic,
      this.authorName,
      this.phonenumber,
      this.specialDiscount,
      this.specialDiscountEnable,
      this.coordinates,
      this.reviewsSum,
      this.photos,
      this.title,
      this.categoryTitle,
      this.latitude,
      this.subscriptionPlanId,
      this.subscriptionExpiryDate,
      this.subscriptionPlan,
      this.subscriptionTotalOrders,
      this.isSelfDelivery,
      this.packagingCharge})
      : _positionFromLatLngFields = latitude != null && longitude != null;

  VendorModel.fromJson(Map<String, dynamic> json) {
    author = json['author'];
    dineInActive = json['dine_in_active'];
    openDineTime = json['openDineTime'];
    if (json['categoryID'].runtimeType != String) {
      categoryID = json['categoryID'] ?? [];
    }
    id = json['id'];
    categoryPhoto = json['categoryPhoto'];
    restaurantMenuPhotos = json['restaurantMenuPhotos'] ?? [];
    if (json['workingHours'] != null) {
      workingHours = <WorkingHours>[];
      json['workingHours'].forEach((v) {
        workingHours!.add(WorkingHours.fromJson(v));
      });
    }
    location = json['location'];
    fcmToken = json['fcmToken'];
    g = json['g'] != null ? G.fromJson(json['g']) : null;
    hidephotos = json['hidephotos'];
    reststatus = json['reststatus'];
    filters = json['filters'] != null ? Filters.fromJson(json['filters']) : null;
    reviewsCount = json['reviewsCount'] ?? 0.0;
    photo = json['photo'];
    description = json['description'];
    walletAmount = json['walletAmount'];
    closeDineTime = json['closeDineTime'];
    zoneId = json['zoneId'];
    createdAt = json['createdAt'];
    enabledDiveInFuture = json['enabledDiveInFuture'];
    restaurantCost = json['restaurantCost']?.toString();
    deliveryCharge = json['DeliveryCharge'] != null ? DeliveryCharge.fromJson(json['DeliveryCharge']) : null;
    adminCommission = json['adminCommission'] != null ? AdminCommission.fromJson(json['adminCommission']) : null;
    authorProfilePic = json['authorProfilePic'];
    authorName = json['authorName'];
    phonenumber = json['phonenumber'];
    if (json['specialDiscount'] != null) {
      specialDiscount = <SpecialDiscount>[];
      json['specialDiscount'].forEach((v) {
        specialDiscount!.add(SpecialDiscount.fromJson(v));
      });
    }
    specialDiscountEnable = json['specialDiscountEnable'];
    coordinates = json['coordinates'] is GeoPoint ? json['coordinates'] : null;
    reviewsSum = json['reviewsSum'] ?? 0.0;
    photos = json['photos'] ?? [];
    title = json['title'];
    if (json['categoryTitle'].runtimeType != String) {
      categoryTitle = json['categoryTitle'] ?? [];
    }
    // Report 02#2: `latitude` / `longitude` are strings, and three live
    // stores hold "" for both. `double.parse("")` threw here, which took the
    // order holding the store (and the listener reading it) down with it.
    // Such a store now simply has no position: no pin, no route, no distance.
    _positionFromLatLngFields = _point(json['latitude'], json['longitude']) != null;
    final position = parsePosition(json);
    latitude = position?.lat;
    longitude = position?.lng;
    subscriptionPlanId = json['subscriptionPlanId'];
    subscriptionExpiryDate = json['subscriptionExpiryDate'];
    subscriptionPlan = json['subscription_plan'] != null ? SubscriptionPlanModel.fromJson(json['subscription_plan']) : null;
    subscriptionTotalOrders = json['subscriptionTotalOrders'];
    isSelfDelivery = json['isSelfDelivery'];
    packagingCharge = json['packagingCharge'] ?? "0";
  }

  /// True when [latitude] / [longitude] were read from the stored
  /// `latitude` / `longitude` themselves. Only then does [toJson] write them,
  /// so an order's store snapshot holding "" is never rewritten with null or
  /// with a position derived from `coordinates`.
  bool _positionFromLatLngFields = false;

  /// False for a store saved without a usable position (report 02#2). Such a
  /// store gets no map pin, no route, no distance and no directions to 0,0.
  bool get hasPosition => latitude != null && longitude != null;

  /// The store's position from `latitude` / `longitude` (strings or numbers),
  /// else `coordinates`, else `g.geopoint`; null when none of them is a real
  /// point. Never throws. Same rule as the customer app's
  /// `VendorModel.parsePosition` and the Store app's `parseCoordinate`.
  static ({double lat, double lng})? parsePosition(Map<String, dynamic> json) {
    final Object? coordinates = json['coordinates'];
    final Object? g = json['g'];
    final Object? geopoint = g is Map ? g['geopoint'] : null;
    return _point(json['latitude'], json['longitude']) ??
        (coordinates is GeoPoint ? _point(coordinates.latitude, coordinates.longitude) : null) ??
        (geopoint is GeoPoint ? _point(geopoint.latitude, geopoint.longitude) : null);
  }

  static ({double lat, double lng})? _point(Object? lat, Object? lng) {
    final double? a = parseCoordinate(lat);
    final double? b = parseCoordinate(lng);
    if (a == null || b == null) return null;
    if (a.abs() > 90 || b.abs() > 180) return null;
    // 0,0 is this data model's "not set": no store is in the Gulf of Guinea.
    if (a == 0 && b == 0) return null;
    return (lat: a, lng: b);
  }

  /// A latitude / longitude as stored by the apps (numbers) or the panels
  /// (strings). Blank, "null", non-numeric, NaN or infinite values are null.
  static double? parseCoordinate(Object? value) {
    if (value == null) return null;
    final double? parsed = value is num ? value.toDouble() : double.tryParse(value.toString().trim());
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['author'] = author;
    data['dine_in_active'] = dineInActive;
    data['openDineTime'] = openDineTime;
    data['categoryID'] = categoryID;
    data['id'] = id;
    data['categoryPhoto'] = categoryPhoto;
    data['restaurantMenuPhotos'] = restaurantMenuPhotos;
    data['subscriptionPlanId'] = subscriptionPlanId;
    data['subscriptionExpiryDate'] = subscriptionExpiryDate;
    data['subscription_plan'] = subscriptionPlan?.toJson();
    if (workingHours != null) {
      data['workingHours'] = workingHours!.map((v) => v.toJson()).toList();
    }
    data['location'] = location;
    data['fcmToken'] = fcmToken;
    if (g != null) {
      data['g'] = g!.toJson();
    }
    data['hidephotos'] = hidephotos;
    data['reststatus'] = reststatus;
    if (filters != null) {
      data['filters'] = filters!.toJson();
    }
    data['reviewsCount'] = reviewsCount;
    data['photo'] = photo;
    data['description'] = description;
    data['walletAmount'] = walletAmount;
    data['closeDineTime'] = closeDineTime;
    data['zoneId'] = zoneId;
    data['createdAt'] = createdAt;
    if (_positionFromLatLngFields) data['longitude'] = longitude;
    data['enabledDiveInFuture'] = enabledDiveInFuture;
    data['restaurantCost'] = restaurantCost;
    if (deliveryCharge != null) {
      data['DeliveryCharge'] = deliveryCharge!.toJson();
    }
    if (adminCommission != null) {
      data['adminCommission'] = adminCommission!.toJson();
    }
    data['authorProfilePic'] = authorProfilePic;
    data['authorName'] = authorName;
    data['phonenumber'] = phonenumber;
    if (specialDiscount != null) {
      data['specialDiscount'] = specialDiscount!.map((v) => v.toJson()).toList();
    }
    data['specialDiscountEnable'] = specialDiscountEnable;
    if (coordinates != null) data['coordinates'] = coordinates;
    data['reviewsSum'] = reviewsSum;
    data['photos'] = photos;
    data['title'] = title;
    data['categoryTitle'] = categoryTitle;
    if (_positionFromLatLngFields) data['latitude'] = latitude;
    data['subscriptionTotalOrders'] = subscriptionTotalOrders;
    data['isSelfDelivery'] = isSelfDelivery;
    data['packagingCharge'] = packagingCharge;
    return data;
  }
}

class WorkingHours {
  String? day;
  List<Timeslot>? timeslot;

  WorkingHours({this.day, this.timeslot});

  WorkingHours.fromJson(Map<String, dynamic> json) {
    day = json['day'];
    if (json['timeslot'] != null) {
      timeslot = <Timeslot>[];
      json['timeslot'].forEach((v) {
        timeslot!.add(Timeslot.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['day'] = day;
    if (timeslot != null) {
      data['timeslot'] = timeslot!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Timeslot {
  String? to;
  String? from;

  Timeslot({this.to, this.from});

  Timeslot.fromJson(Map<String, dynamic> json) {
    to = json['to'];
    from = json['from'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['to'] = to;
    data['from'] = from;
    return data;
  }
}

class G {
  String? geohash;
  GeoPoint? geopoint;

  G({this.geohash, this.geopoint});

  G.fromJson(Map<String, dynamic> json) {
    geohash = json['geohash'];
    geopoint = json['geopoint'] is GeoPoint ? json['geopoint'] : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['geohash'] = geohash;
    if (geopoint != null) data['geopoint'] = geopoint;
    return data;
  }
}

class Filters {
  String? goodForLunch;
  String? outdoorSeating;
  String? liveMusic;
  String? vegetarianFriendly;
  String? goodForDinner;
  String? goodForBreakfast;
  String? freeWiFi;
  String? takesReservations;

  Filters({this.goodForLunch, this.outdoorSeating, this.liveMusic, this.vegetarianFriendly, this.goodForDinner, this.goodForBreakfast, this.freeWiFi, this.takesReservations});

  Filters.fromJson(Map<String, dynamic> json) {
    goodForLunch = json['Good for Lunch'];
    outdoorSeating = json['Outdoor Seating'];
    liveMusic = json['Live Music'];
    vegetarianFriendly = json['Vegetarian Friendly'];
    goodForDinner = json['Good for Dinner'];
    goodForBreakfast = json['Good for Breakfast'];
    freeWiFi = json['Free Wi-Fi'];
    takesReservations = json['Takes Reservations'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['Good for Lunch'] = goodForLunch;
    data['Outdoor Seating'] = outdoorSeating;
    data['Live Music'] = liveMusic;
    data['Vegetarian Friendly'] = vegetarianFriendly;
    data['Good for Dinner'] = goodForDinner;
    data['Good for Breakfast'] = goodForBreakfast;
    data['Free Wi-Fi'] = freeWiFi;
    data['Takes Reservations'] = takesReservations;
    return data;
  }
}

class DeliveryCharge {
  num? minimumDeliveryChargesWithinKm;
  num? minimumDeliveryCharges;
  num? deliveryChargesPerKm;
  bool? vendorCanModify;

  DeliveryCharge({this.minimumDeliveryChargesWithinKm, this.minimumDeliveryCharges, this.deliveryChargesPerKm, this.vendorCanModify});

  DeliveryCharge.fromJson(Map<String, dynamic> json) {
    minimumDeliveryChargesWithinKm = json['minimum_delivery_charges_within_km'];
    minimumDeliveryCharges = json['minimum_delivery_charges'];
    deliveryChargesPerKm = json['delivery_charges_per_km'];
    vendorCanModify = json['vendor_can_modify'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['minimum_delivery_charges_within_km'] = minimumDeliveryChargesWithinKm;
    data['minimum_delivery_charges'] = minimumDeliveryCharges;
    data['delivery_charges_per_km'] = deliveryChargesPerKm;
    data['vendor_can_modify'] = vendorCanModify;
    return data;
  }
}

class SpecialDiscount {
  String? day;
  List<SpecialDiscountTimeslot>? timeslot;

  SpecialDiscount({this.day, this.timeslot});

  SpecialDiscount.fromJson(Map<String, dynamic> json) {
    day = json['day'];
    if (json['timeslot'] != null) {
      timeslot = <SpecialDiscountTimeslot>[];
      json['timeslot'].forEach((v) {
        timeslot!.add(SpecialDiscountTimeslot.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['day'] = day;
    if (timeslot != null) {
      data['timeslot'] = timeslot!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class SpecialDiscountTimeslot {
  String? discount;
  String? discountType;
  String? to;
  String? type;
  String? from;

  SpecialDiscountTimeslot({this.discount, this.discountType, this.to, this.type, this.from});

  SpecialDiscountTimeslot.fromJson(Map<String, dynamic> json) {
    discount = json['discount'];
    discountType = json['discount_type'];
    to = json['to'];
    type = json['type'];
    from = json['from'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['discount'] = discount;
    data['discount_type'] = discountType;
    data['to'] = to;
    data['type'] = type;
    data['from'] = from;
    return data;
  }
}
