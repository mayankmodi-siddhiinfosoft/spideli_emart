import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/models/vendor_subscription_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/region_service.dart';

/// The commission split of one subscription payment.
class SubscriptionCommission {
  final double amount;
  final double adminCommission;
  final String adminCommissionType;

  const SubscriptionCommission({required this.amount, required this.adminCommission, required this.adminCommissionType});

  double get vendorEarning => amount - adminCommission;
}

/// Store-sold subscriptions (spec 4.7 / 7.9, APP-DEV-BRIEF Part B).
///
/// Client decisions: a subscription is a RECORD only (the store fulfils from
/// its daily production list - no generated orders, no server, no automatic
/// renewal charging). The customer can pause, skip a day and cancel. A
/// renewal is a new `vendor_subscriptions` document for the same customer +
/// plan. Never writes the platform plan fields on `users`.
class StoreSubscriptionService {
  StoreSubscriptionService._();

  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  static String get _uid => FireStoreUtils.getCurrentUid();

  static int _newestFirst(Timestamp? a, Timestamp? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  // ---------------------------------------------------------------- Plans

  /// Enabled plans of the store with [vendorId], cheapest first.
  static Future<List<VendorSubscriptionPlanModel>> plansForStore(String vendorId) async {
    if (vendorId.isEmpty) return [];
    final snap = await _db.collection(CollectionName.vendorSubscriptionPlans).where('vendorID', isEqualTo: vendorId).get();
    final list = <VendorSubscriptionPlanModel>[];
    for (final d in snap.docs) {
      final plan = VendorSubscriptionPlanModel.fromJson(d.data());
      plan.id ??= d.id;
      if (plan.isEnable != true) continue;
      list.add(plan);
    }
    list.sort((a, b) => a.priceValue.compareTo(b.priceValue));
    return list;
  }

  static String periodLabel(String? expiryDay) {
    final days = int.tryParse(expiryDay ?? '') ?? 0;
    if (days == 30) return "Monthly";
    if (days == 365) return "Annual";
    if (days <= 0) return "-";
    return "$days days";
  }

  // ---------------------------------------------------------------- Commission

  static double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  static bool _isPercent(String? type) {
    final t = (type ?? '').toLowerCase();
    return t == 'percent' || t == 'percentage';
  }

  /// The store's order commission, computed exactly as the order flow reads
  /// it (cart_controller): the section's commission disabled -> 0 (fixed);
  /// else `vendors.adminCommission` when present, else the section's
  /// (global) setting. Keys are read tolerantly:
  /// `enable|isEnabled`, `type|commissionType`, `commission|amount`.
  static Future<SubscriptionCommission> commissionFor(String vendorId, double amount) async {
    Map<String, dynamic>? vendorCommission;
    Map<String, dynamic>? sectionCommission;
    try {
      final vendorDoc = await _db.collection(CollectionName.vendors).doc(vendorId).get();
      final vendor = vendorDoc.data();
      if (vendor?['adminCommission'] is Map) vendorCommission = Map<String, dynamic>.from(vendor!['adminCommission']);
      final String sectionId = vendor?['section_id']?.toString() ?? vendor?['sectionId']?.toString() ?? '';
      final current = Constant.sectionConstantModel;
      if (sectionId.isNotEmpty && sectionId != current?.id) {
        final sectionDoc = await _db.collection(CollectionName.sections).doc(sectionId).get();
        final raw = sectionDoc.data()?['adminCommision'];
        if (raw is Map) sectionCommission = Map<String, dynamic>.from(raw);
      }
      if (sectionCommission == null && current?.adminCommision != null) {
        final c = current!.adminCommision!;
        sectionCommission = {'enable': c.isEnabled, 'type': c.commissionType, 'commission': c.amount};
      }
    } catch (_) {}

    bool? enabled(Map<String, dynamic>? m) => m == null ? null : (m['enable'] ?? m['isEnabled']) as bool?;
    String? type(Map<String, dynamic>? m) => m == null ? null : (m['type'] ?? m['commissionType'])?.toString();
    double rate(Map<String, dynamic>? m) => m == null ? 0 : _num(m['commission'] ?? m['amount']);

    if (enabled(sectionCommission) == false) {
      return SubscriptionCommission(amount: amount, adminCommission: 0, adminCommissionType: 'fixed');
    }
    final source = vendorCommission ?? sectionCommission;
    final String commissionType = type(source) ?? 'fixed';
    final double r = rate(source);
    double commission = _isPercent(commissionType) ? amount * r / 100 : r;
    if (commission < 0) commission = 0;
    if (commission > amount) commission = amount;
    return SubscriptionCommission(amount: amount, adminCommission: commission, adminCommissionType: commissionType);
  }

  // ---------------------------------------------------------------- Purchase

  /// The customer's latest still-running subscription to [planId], if any.
  static Future<VendorSubscriptionModel?> currentFor(String planId) async {
    final subs = await mySubscriptions();
    for (final s in subs) {
      final st = s.effectiveStatus;
      if (s.effectivePlanId == planId && (st == VendorSubscriptionModel.statusActive || st == VendorSubscriptionModel.statusPaused)) return s;
    }
    return null;
  }

  /// Writes `vendor_subscriptions` + `vendor_subscription_payments` after a
  /// successful payment, in one batch. Returns the subscription id.
  static Future<String> recordPurchase({
    required VendorSubscriptionPlanModel plan,
    required VendorModel vendor,
    required ShippingAddress address,
    required DateTime startDate,
    required String paymentMethod,
    required SubscriptionCommission commission,
  }) async {
    final String? regionId = RegionService.regionOfVendor(vendor) ?? plan.regionId;
    final int decimals = (RegionService.currencyForRegion(regionId) ?? RegionService.globalCurrency)?.decimal ?? 2;
    String money(double v) => v.toStringAsFixed(decimals);

    final DateTime start = DateTime(startDate.year, startDate.month, startDate.day);
    final DateTime? expiry = plan.expiryDays > 0 ? start.add(Duration(days: plan.expiryDays)) : null;
    final Timestamp now = Timestamp.now();

    final subRef = _db.collection(CollectionName.vendorSubscriptions).doc();
    final payRef = _db.collection(CollectionName.vendorSubscriptionPayments).doc();
    final batch = _db.batch();
    batch.set(subRef, {
      'id': subRef.id,
      'planId': plan.id,
      'vendorID': vendor.id,
      'customerId': _uid,
      'plan': plan.snapshot(),
      'startDate': Timestamp.fromDate(start),
      'expiryDate': expiry == null ? null : Timestamp.fromDate(expiry),
      'status': VendorSubscriptionModel.statusActive,
      'regionId': regionId,
      'deliveryAddress': address.toJson(),
      'autoRenew': false,
      'skippedDates': <String>[],
      'createdAt': now,
    });
    batch.set(payRef, {
      'id': payRef.id,
      'subscriptionId': subRef.id,
      'planId': plan.id,
      'vendorID': vendor.id,
      'customerId': _uid,
      'amount': money(commission.amount),
      'adminCommission': money(commission.adminCommission),
      'adminCommissionType': commission.adminCommissionType,
      'vendorEarning': money(commission.vendorEarning),
      'payment_method': paymentMethod,
      'status': 'paid',
      'regionId': regionId,
      'createdAt': now,
    });
    await batch.commit();
    return subRef.id;
  }

  // ---------------------------------------------------------------- Mine

  static Future<List<VendorSubscriptionModel>> mySubscriptions() async {
    final snap = await _db.collection(CollectionName.vendorSubscriptions).where('customerId', isEqualTo: _uid).get();
    final list = snap.docs.map((d) {
      final m = VendorSubscriptionModel.fromJson(d.data());
      m.id ??= d.id;
      return m;
    }).toList();
    list.sort((a, b) => _newestFirst(a.startDate, b.startDate));
    return list;
  }

  static Future<List<VendorSubscriptionPaymentModel>> myPayments() async {
    final snap = await _db.collection(CollectionName.vendorSubscriptionPayments).where('customerId', isEqualTo: _uid).get();
    final list = snap.docs.map((d) {
      final m = VendorSubscriptionPaymentModel.fromJson(d.data());
      m.id ??= d.id;
      return m;
    }).toList();
    list.sort((a, b) => _newestFirst(a.createdAt, b.createdAt));
    return list;
  }

  // ---------------------------------------------------------------- Actions (field updates only)

  static DocumentReference<Map<String, dynamic>> _ref(String id) => _db.collection(CollectionName.vendorSubscriptions).doc(id);

  /// `status: "paused"`, `pausedFrom`, optional `pausedUntil` (inclusive;
  /// absent = until resumed).
  static Future<void> pause(String id, {required DateTime from, DateTime? until}) {
    return _ref(id).update({
      'status': VendorSubscriptionModel.statusPaused,
      'pausedFrom': Timestamp.fromDate(DateTime(from.year, from.month, from.day)),
      'pausedUntil': until == null ? FieldValue.delete() : Timestamp.fromDate(DateTime(until.year, until.month, until.day)),
    });
  }

  static Future<void> resume(String id) {
    return _ref(id).update({'status': VendorSubscriptionModel.statusActive, 'pausedFrom': FieldValue.delete(), 'pausedUntil': FieldValue.delete()});
  }

  /// Appends `yyyy-MM-dd` to `skippedDates`.
  static Future<void> skipDay(String id, DateTime day) {
    return _ref(id).update({
      'skippedDates': FieldValue.arrayUnion([VendorSubscriptionModel.dayFormat.format(day)]),
    });
  }

  static Future<void> unskipDay(String id, String day) {
    return _ref(id).update({
      'skippedDates': FieldValue.arrayRemove([day]),
    });
  }

  /// Cancels the subscription and its renewal: `status: "cancelled"`,
  /// `cancelledAt`, `autoRenew: false`. Nothing is refunded.
  static Future<void> cancel(String id) {
    return _ref(id).update({'status': VendorSubscriptionModel.statusCancelled, 'cancelledAt': Timestamp.now(), 'autoRenew': false});
  }
}
