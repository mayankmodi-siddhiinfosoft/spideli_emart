import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_subscription_model.dart';
import 'package:vendor/models/vendor_subscription_payment_model.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

/// Data access for "Customer Subscriptions" (plans a store sells to its own
/// customers). Queries filter by the current store only and are sorted
/// newest-first on the client, so no composite index is required.
class CustomerSubscriptionService {
  // Same (named-database) Firestore instance the rest of the app uses.
  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  static String get currentVendorId => Constant.userModel?.vendorID ?? '';

  static int _newestFirst(Timestamp? a, Timestamp? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  // ---------------------------------------------------------------- Plans

  static Future<List<VendorSubscriptionPlanModel>> getPlans() async {
    if (currentVendorId.isEmpty) return [];
    final snap = await _db.collection(CollectionName.vendorSubscriptionPlans).where('vendorID', isEqualTo: currentVendorId).get();
    final list = snap.docs.map((d) {
      final model = VendorSubscriptionPlanModel.fromJson(d.data());
      model.id ??= d.id;
      return model;
    }).toList();
    list.sort((a, b) => _newestFirst(a.createdAt, b.createdAt));
    return list;
  }

  static Future<void> savePlan(VendorSubscriptionPlanModel plan) async {
    await _db.collection(CollectionName.vendorSubscriptionPlans).doc(plan.id).set(plan.toJson());
  }

  static Future<void> setPlanEnabled(String planId, bool isEnable) async {
    await _db.collection(CollectionName.vendorSubscriptionPlans).doc(planId).update({'isEnable': isEnable});
  }

  static Future<void> deletePlan(String planId) async {
    await _db.collection(CollectionName.vendorSubscriptionPlans).doc(planId).delete();
  }

  /// The store's regionId, read from the raw vendor document so this feature
  /// does not depend on a VendorModel field.
  static Future<String?> getVendorRegionId(String vendorId) async {
    try {
      final doc = await _db.collection(CollectionName.vendors).doc(vendorId).get();
      final value = doc.data()?['regionId'];
      return value?.toString();
    } catch (e) {
      log("getVendorRegionId :: $e");
      return null;
    }
  }

  // ---------------------------------------------------------------- Subscribers (read-only)

  static Future<List<VendorSubscriptionModel>> getSubscribers() async {
    if (currentVendorId.isEmpty) return [];
    final snap = await _db.collection(CollectionName.vendorSubscriptions).where('vendorID', isEqualTo: currentVendorId).get();
    final list = snap.docs.map((d) {
      final model = VendorSubscriptionModel.fromJson(d.data());
      model.id ??= d.id;
      return model;
    }).toList();
    list.sort((a, b) => _newestFirst(a.startDate, b.startDate));
    return list;
  }

  // ---------------------------------------------------------------- Payments (read-only)

  static Future<List<VendorSubscriptionPaymentModel>> getPayments() async {
    if (currentVendorId.isEmpty) return [];
    final snap = await _db.collection(CollectionName.vendorSubscriptionPayments).where('vendorID', isEqualTo: currentVendorId).get();
    final list = snap.docs.map((d) {
      final model = VendorSubscriptionPaymentModel.fromJson(d.data());
      model.id ??= d.id;
      return model;
    }).toList();
    list.sort((a, b) => _newestFirst(a.createdAt, b.createdAt));
    return list;
  }

  // ---------------------------------------------------------------- Customers

  static final Map<String, UserModel?> _customerCache = {};

  /// Looks up a customer lazily; returns null (never throws) if missing.
  static Future<UserModel?> getCustomer(String? customerId) async {
    if (customerId == null || customerId.isEmpty) return null;
    if (_customerCache.containsKey(customerId)) return _customerCache[customerId];
    UserModel? user;
    try {
      final doc = await _db.collection(CollectionName.users).doc(customerId).get();
      if (doc.exists && doc.data() != null) user = UserModel.fromJson(doc.data()!);
    } catch (e) {
      log("getCustomer :: $e");
    }
    _customerCache[customerId] = user;
    return user;
  }
}
