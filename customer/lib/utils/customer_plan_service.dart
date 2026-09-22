import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/order_history_limit.dart';
import 'package:customer/utils/region_service.dart';
import 'package:get/get.dart';

/// One platform plan sold to customers (`subscription_plans` with
/// `planFor == "customer"`, spec 18.10). Kept close to the raw document so the
/// snapshot written on purchase carries every field (planFor, features, ...).
class CustomerPlan {
  final Map<String, dynamic> raw;

  CustomerPlan(this.raw);

  String get id => raw['id']?.toString() ?? '';
  String get name => raw['name']?.toString() ?? '';
  String get description => raw['description']?.toString() ?? '';
  String get price => raw['price']?.toString() ?? '0';
  double get priceValue => double.tryParse(price) ?? 0;
  String get expiryDay => raw['expiryDay']?.toString() ?? '';
  bool get neverExpires => expiryDay == '-1';
  int get days => int.tryParse(expiryDay) ?? 0;
  List<String> get points => raw['plan_points'] is List ? (raw['plan_points'] as List).map((e) => e.toString()).toList() : const [];
  bool get unlocksFullHistory => raw['features'] is Map && (raw['features'] as Map)['fullOrderHistory'] == true;

  /// "Monthly" / "Annual" / "Lifetime" / "N days".
  String get periodLabel => CustomerPlanService.periodLabel(expiryDay);
}

/// The customer's full order-history plan (spec 4.6 / 7.7 / 18.10).
///
/// Decision (blocking Q1): the APP writes the record after a successful
/// payment. Decision (open Q8): a renewal extends from the CURRENT expiry when
/// the customer plan is still active, else from now. `expiryDay == "-1"`
/// means no expiry (`subscriptionExpiryDate: null`).
class CustomerPlanService {
  CustomerPlanService._();

  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  static String periodLabel(String expiryDay) {
    final days = int.tryParse(expiryDay) ?? 0;
    if (expiryDay == '-1') return "Lifetime".tr;
    if (days == 30) return "Monthly".tr;
    if (days == 365) return "Annual".tr;
    if (days <= 0) return "-";
    return "$days ${"days".tr}";
  }

  /// Plans are priced in the customer's current region currency.
  static CurrencyModel? get currency => RegionService.customerCurrency;

  /// `planFor == "customer"`, `isEnable == true`, and `regionIds` empty or
  /// containing the customer's region. Cheapest first.
  static Future<List<CustomerPlan>> availablePlans() async {
    await RegionService.ensureLoaded();
    final snap = await _db.collection(CollectionName.subscriptionPlans).where('planFor', isEqualTo: 'customer').get();
    final regions = RegionService.customerRegionIds;
    final list = <CustomerPlan>[];
    for (final doc in snap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = (data['id']?.toString().isNotEmpty ?? false) ? data['id'] : doc.id;
      if (data['isEnable'] != true) continue;
      if (!RegionService.isAvailableInAnyRegion(data['regionIds'], regions)) continue;
      list.add(CustomerPlan(data));
    }
    list.sort((a, b) => a.priceValue.compareTo(b.priceValue));
    return list;
  }

  /// The current user document (raw), or null.
  static Future<Map<String, dynamic>?> currentUserData() async {
    final doc = await _db.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).get();
    return doc.data();
  }

  /// A customer plan snapshot on the user (null when none, or a vendor plan).
  static Map<String, dynamic>? customerPlanOf(Map<String, dynamic>? user) {
    final dynamic plan = user?['subscription_plan'];
    if (plan is! Map || plan['planFor'] != 'customer') return null;
    return Map<String, dynamic>.from(plan);
  }

  /// Expiry of the customer's plan; null = never expires (or no plan).
  static Timestamp? expiryOf(Map<String, dynamic>? user) {
    final dynamic value = user?['subscriptionExpiryDate'];
    return value is Timestamp ? value : null;
  }

  /// The new expiry when [plan] is bought now. Null = never expires.
  static DateTime? newExpiry(CustomerPlan plan, Map<String, dynamic>? user) {
    if (plan.neverExpires) return null;
    final now = DateTime.now();
    DateTime base = now;
    final current = customerPlanOf(user);
    final expiry = expiryOf(user)?.toDate();
    // Renewing while still active: the remaining days are kept.
    if (current != null && expiry != null && expiry.isAfter(now)) base = expiry;
    return base.add(Duration(days: plan.days));
  }

  /// Writes the purchase after a successful payment: the plan fields on
  /// `users/{uid}` (field update, never a full set) and one
  /// `subscription_history` row, in one batch.
  static Future<void> recordPurchase(CustomerPlan plan, {required String paymentType}) async {
    final uid = FireStoreUtils.getCurrentUid();
    final user = await currentUserData();
    final DateTime? expiry = newExpiry(plan, user);
    final Timestamp? expiryTs = expiry == null ? null : Timestamp.fromDate(expiry);
    final Map<String, dynamic> snapshot = {...plan.raw, 'id': plan.id, 'planFor': 'customer'};

    final batch = _db.batch();
    batch.update(_db.collection(CollectionName.users).doc(uid), {
      'subscriptionPlanId': plan.id,
      'subscription_plan': snapshot,
      'subscriptionExpiryDate': expiryTs,
    });
    final historyId = Constant.getUuid();
    batch.set(_db.collection(CollectionName.subscriptionHistory).doc(historyId), {
      'id': historyId,
      'user_id': uid,
      'subscription_plan': snapshot,
      'expiry_date': expiryTs,
      'payment_type': paymentType,
      'createdAt': Timestamp.now(),
      // Additive: the region the plan was bought in, so the invoice shows
      // the currency it was paid in.
      'regionId': RegionService.customerRegionId,
    });
    await batch.commit();
    log("CustomerPlanService: plan ${plan.id} recorded, expiry $expiry");
  }

  /// Past purchases (invoices) of the signed-in customer, newest first.
  /// Only customer-plan rows (`subscription_plan.planFor == "customer"`).
  static Future<List<Map<String, dynamic>>> purchaseHistory() async {
    final snap = await _db.collection(CollectionName.subscriptionHistory).where('user_id', isEqualTo: FireStoreUtils.getCurrentUid()).get();
    final list = snap.docs.map((d) => d.data()).where((d) => d['subscription_plan'] is Map && (d['subscription_plan'] as Map)['planFor'] == 'customer').toList();
    list.sort((a, b) {
      final ta = a['createdAt'];
      final tb = b['createdAt'];
      if (ta is! Timestamp) return 1;
      if (tb is! Timestamp) return -1;
      return tb.compareTo(ta);
    });
    return list;
  }

  /// `hasFullHistory` (spec 18.10 pseudocode) on a raw user document.
  static bool hasFullHistory(Map<String, dynamic>? user) => OrderHistoryLimit.hasFullHistory(user);
}
