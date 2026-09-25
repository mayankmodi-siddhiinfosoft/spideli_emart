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

  /// Worth selling: unlocks full history and either never expires or lasts
  /// at least one day.
  bool get isSellable => unlocksFullHistory && (neverExpires || days > 0);

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

  /// The offer, exactly as the web panel builds it (WEB spec 5, "Offering
  /// plans"): `planFor == "customer"`, `isEnable == true`, then dropped only
  /// when `regionIds` is non-empty AND excludes the customer's region. Absent
  /// or empty `regionIds` = sold everywhere, and a customer whose region could
  /// not be resolved is shown EVERY plan rather than none
  /// ([RegionService.isAvailableInAnyRegion] returns true on an empty region
  /// list). Cheapest first.
  ///
  /// No other gate: a plan the admin enabled is offered even when it carries
  /// no `features.fullOrderHistory`, so the app and the website never show a
  /// different catalogue.
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

  /// The note the wallet row of a plan purchase carries (WEB spec 5).
  static const String purchaseNote = 'Subscription purchase';

  /// The gateway name as the panels write it: "Wallet", "Stripe", "Razorpay"
  /// ... (WEB spec 5 writes `payment_type`/`payment_method` capitalised).
  static String gatewayLabel(String paymentType) {
    final String trimmed = paymentType.trim();
    if (trimmed.isEmpty) return 'Wallet';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Writes the purchase after a successful payment, matching the shape the
  /// web panel writes (WEB spec 5):
  ///
  /// * `users/{uid}` - `subscriptionPlanId`, `subscription_plan` (the whole
  ///   plan document as a snapshot) and `subscriptionExpiryDate`
  ///   (`Timestamp`, or null when `expiryDay == "-1"`). A field update, never
  ///   a full set; `wallet_amount` was already debited inside
  ///   `FireStoreUtils.debitWalletIfSufficient`, which re-reads the balance in
  ///   its own transaction and refuses the debit if it moved.
  /// * `wallet/{newId}` - the purchase row. The wallet debit writes its own
  ///   row, so it is only written here for the card gateways, which move no
  ///   wallet money but must still leave the same record.
  /// * `subscription_history/{newId}` - the invoice row.
  ///
  /// The plan documents are written in ONE batch: all of them or none.
  static Future<void> recordPurchase(CustomerPlan plan, {required String paymentType}) async {
    final uid = FireStoreUtils.getCurrentUid();
    final user = await currentUserData();
    final DateTime? expiry = newExpiry(plan, user);
    final Timestamp? expiryTs = expiry == null ? null : Timestamp.fromDate(expiry);
    final Map<String, dynamic> snapshot = {...plan.raw, 'id': plan.id, 'planFor': 'customer'};
    final String method = gatewayLabel(paymentType);
    final String? regionId = RegionService.customerRegionId;

    final batch = _db.batch();
    batch.update(_db.collection(CollectionName.users).doc(uid), {
      'subscriptionPlanId': plan.id,
      'subscription_plan': snapshot,
      'subscriptionExpiryDate': expiryTs,
    });
    // Card gateways: the wallet was never touched, so the purchase row the
    // wallet debit would have written is written here instead. Paying FROM the
    // wallet already wrote it inside the debit transaction - never twice.
    if (paymentType.trim().toLowerCase() != 'wallet') {
      final String walletId = Constant.getUuid();
      batch.set(_db.collection(CollectionName.wallet).doc(walletId), {
        'id': walletId,
        'user_id': uid,
        'amount': plan.priceValue,
        'date': FieldValue.serverTimestamp(),
        'isTopUp': false,
        'note': purchaseNote,
        'payment_method': method,
        'payment_status': 'success',
        'transactionUser': 'user',
        // Additive: the region the money was taken in (spec 18.12).
        'regionId': ?regionId,
      });
    }
    final historyId = Constant.getUuid();
    batch.set(_db.collection(CollectionName.subscriptionHistory).doc(historyId), {
      'id': historyId,
      'user_id': uid,
      'subscription_plan': snapshot,
      'expiry_date': expiryTs,
      'payment_type': method,
      'createdAt': FieldValue.serverTimestamp(),
      // Additive: the region the plan was bought in, so the invoice shows
      // the currency it was paid in.
      'regionId': regionId,
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
