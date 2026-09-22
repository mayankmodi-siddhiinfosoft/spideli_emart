import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Free order-history limit (spec 7.7 / 18.9 / 18.10).
///
/// `settings/OrderHistory { isLimitEnabled, freeOrderLimit }`; a missing
/// document means `{ true, 5 }`. Customers with an active customer plan
/// (`subscription_plan.planFor == "customer"`, not expired,
/// `features.fullOrderHistory == true`) see everything.
///
/// SCOPE: use this ONLY in the customer's own order-history screens. It must
/// never move into FireStoreUtils or any shared data layer.
class OrderHistoryLimit {
  OrderHistoryLimit._();

  static const int defaultFreeOrderLimit = 5;

  /// How many of the newest orders the customer may see; null = all.
  static Future<int?> visibleCount() async {
    try {
      final db = FireStoreUtils.fireStore;
      final results = await Future.wait([
        db.collection(CollectionName.settings).doc('OrderHistory').get(),
        db.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).get(),
      ]);
      if (hasFullHistory(results[1].data())) return null;
      final settings = results[0].data();
      if (settings == null) return defaultFreeOrderLimit;
      if (settings['isLimitEnabled'] == false) return null;
      final dynamic raw = settings['freeOrderLimit'];
      final int? limit = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
      if (limit == null || limit < 0) return defaultFreeOrderLimit;
      return limit;
    } catch (e) {
      log("OrderHistoryLimit: $e");
      // Could not read the setting: apply the documented default.
      return defaultFreeOrderLimit;
    }
  }

  /// `hasFullHistory(customer)` from spec 18.10, on the raw user document so a
  /// customer plan snapshot of any shape is read tolerantly.
  static bool hasFullHistory(Map<String, dynamic>? user) {
    final dynamic plan = user?['subscription_plan'];
    if (plan is! Map || plan['planFor'] != 'customer') return false; // a vendor plan never counts
    final dynamic expiry = user?['subscriptionExpiryDate'];
    if (expiry is Timestamp && expiry.toDate().isBefore(DateTime.now())) return false;
    final dynamic features = plan['features'];
    return features is Map && features['fullOrderHistory'] == true;
  }

  /// The newest [limit] items of [items] (sorted newest first by [createdAt]).
  static List<T> newest<T>(List<T> items, int? limit, Timestamp? Function(T) createdAt) {
    if (limit == null || items.length <= limit) return items;
    final sorted = [...items]..sort((a, b) {
      final ta = createdAt(a);
      final tb = createdAt(b);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return sorted.take(limit).toList();
  }
}

/// "See older orders" prompt shown under a limited history. Buying the plan is
/// blocked (spec blocking question 1), so this only informs: it writes
/// nothing.
class OlderOrdersPrompt extends StatelessWidget {
  final int hiddenCount;
  final bool isDark;

  const OlderOrdersPrompt({super.key, required this.hiddenCount, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: ShapeDecoration(
          color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "See older orders".tr,
              style: TextStyle(fontSize: 16, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
            ),
            const SizedBox(height: 4),
            Text(
              "${"Older orders hidden:".tr} $hiddenCount. ${"A subscription to view your complete order history is coming soon.".tr}",
              style: TextStyle(fontSize: 14, fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey300 : AppThemeData.grey600),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: null, // plan purchase is not available yet (blocked Q1)
              child: Text("Coming soon".tr),
            ),
          ],
        ),
      ),
    );
  }
}
