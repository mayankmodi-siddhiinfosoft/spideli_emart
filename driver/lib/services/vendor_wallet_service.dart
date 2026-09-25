import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/section_model.dart';
import 'package:driver/utils/fire_store_utils.dart';

/// Credits the STORE for an order the DRIVER completes.
///
/// APP-SPEC-STORE.md §2 / APP-SPEC-ADMIN.md §7: *nothing credits
/// `vendors/{id}.wallet_amount` on order completion — the app must do it.*
/// The Store app credits when the store itself moves an order (accept,
/// takeaway delivered, assign to a self-delivery driver, shipped), but an
/// order handed to a platform driver was only ever credited to the DRIVER
/// here — the store's own balance never moved, so the vendor could not
/// withdraw what it earned.
///
/// The write shape is the Store app's
/// (`FireStoreUtils.restaurantVendorWalletSet` / `adjustVendorWallet`):
///
/// * the owner's `users/{ownerId}.wallet_amount` and the store's
///   `vendors/{vendorId}.wallet_amount` move by the same amount **in one
///   transaction**, so a stale in-memory balance can never overwrite a
///   concurrent credit;
/// * two `wallet` rows are written (`payment_method` `Wallet` for the order
///   amount and `tax` for the tax, `transactionUser: vendor`, `isTopUp`) —
///   the same rows the Store app writes, which is what makes its
///   `_isOrderAlreadyCredited` / `netVendorCreditForOrder` see this credit.
///   A refund in the Store panel therefore reverses exactly what was paid
///   here, and never debits an order that was never credited;
/// * the order is stamped `vendorCredited: true` inside the same transaction,
///   so a retry (a second tap, a re-run after a crash) cannot pay twice.
///
/// Everything is additive: an order without `vendorCredited` behaves exactly
/// as before, and the amount is computed with the Store app's own formula so
/// the two apps can never disagree about what an order earned.
class VendorWalletService {
  VendorWalletService._();

  static FirebaseFirestore get _db => FireStoreUtils.fireStore;

  static double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  /// Deterministic ids, so a retry rewrites the same two rows instead of
  /// adding a second pair.
  static String _creditRowId(String orderId) => 'vendorcredit_$orderId';

  static String _taxRowId(String orderId) => 'vendortax_$orderId';

  /// True when some `wallet` row already credits this order to the store —
  /// including one the Store app wrote when it accepted or shipped the order.
  /// Mirrors `FireStoreUtils._isOrderAlreadyCredited` in the Store app.
  static Future<bool> _alreadyCredited(String orderId) async {
    final snapshot = await _db.collection(CollectionName.wallet).where('order_id', isEqualTo: orderId).get();
    return snapshot.docs.any((doc) {
      final data = doc.data();
      return data['transactionUser'] == 'vendor' && data['isTopUp'] == true && data['payment_method'] == 'Wallet';
    });
  }

  /// What the store earns on [orderModel] and the tax passed through to it.
  ///
  /// A line-for-line copy of the Store app's `FireStoreUtils.vendorOrderCredit`
  /// (including its use of the raw `vendor.packagingCharge` in `basePrice`):
  /// the two apps must produce the same figure for the same order, or a refund
  /// would take back more or less than was paid.
  static ({double basePrice, double totalTaxAmount, double total}) creditFor(OrderModel orderModel, {SectionModel? section}) {
    double subTotal = 0.0;
    double productTaxAmount = 0.0;
    double orderTaxAmount = 0.0;
    double packagingTaxAmount = 0.0;

    double unitPrice(dynamic element) {
      final double discount = _num(element.discountPrice);
      return discount > 0 ? discount : _num(element.price);
    }

    for (final element in orderModel.products ?? []) {
      final double qty = _num(element.quantity);
      subTotal += (unitPrice(element) * qty) + (_num(element.extrasPrice) * qty);
    }

    final double couponAmount = _num(orderModel.discount);
    double specialDiscountAmount = 0.0;
    if (orderModel.specialDiscount != null && orderModel.specialDiscount!['special_discount'] != null) {
      specialDiscountAmount = _num(orderModel.specialDiscount!['special_discount']);
    }
    final double totalDiscount = couponAmount + specialDiscountAmount;

    double discountRatio = 0.0;
    if (subTotal > 0 && totalDiscount > 0) {
      discountRatio = totalDiscount / subTotal;
    }

    if (orderModel.taxScope == "product") {
      for (final element in orderModel.products ?? []) {
        final double qty = _num(element.quantity);
        final double itemAmount = (unitPrice(element) * qty) + (_num(element.extrasPrice) * qty);
        final double discountedItemAmount = itemAmount - (itemAmount * discountRatio);
        for (final taxElement in element.taxSetting ?? []) {
          if (taxElement.type == "fix") {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement) * qty;
          } else {
            productTaxAmount += Constant.calculateTax(amount: discountedItemAmount.toString(), taxModel: taxElement);
          }
        }
      }
    }

    if (orderModel.taxScope == "order") {
      for (final taxElement in orderModel.taxSetting ?? []) {
        orderTaxAmount += Constant.calculateTax(amount: (subTotal - totalDiscount).toString(), taxModel: taxElement);
      }
    }

    final double packagingCharge = orderModel.packagingChargeEnable == true ? _num(orderModel.vendor?.packagingCharge) : 0.0;
    if (packagingCharge > 0) {
      for (final taxElement in orderModel.packagingTax ?? []) {
        packagingTaxAmount += Constant.calculateTax(amount: packagingCharge.toString(), taxModel: taxElement);
      }
    }

    final double totalTaxAmount = productTaxAmount + orderTaxAmount + packagingTaxAmount;

    // The commission is embedded in the item prices, so it is removed from the
    // subtotal rather than subtracted from the total.
    final double adminCommission = _num(orderModel.adminCommission);
    final bool commissionApplied = section?.adminCommision?.isEnabled == true;
    final double rawPackaging = _num(orderModel.vendor?.packagingCharge);
    final double basePrice = commissionApplied
        ? (subTotal / (1 + (adminCommission / 100))) - couponAmount - specialDiscountAmount + rawPackaging
        : subTotal - couponAmount - specialDiscountAmount + rawPackaging;

    return (basePrice: basePrice, totalTaxAmount: totalTaxAmount, total: basePrice + totalTaxAmount);
  }

  /// Credits the store that fulfilled [orderModel], exactly once.
  ///
  /// Safe to call on every completion path: it is a no-op when the order was
  /// already credited (by this app or by the Store app), when the store or its
  /// owner cannot be resolved, or when the credit is not positive.
  static Future<void> creditStoreForCompletedOrder(OrderModel orderModel) async {
    final String orderId = orderModel.id ?? '';
    final String vendorId = (orderModel.vendorID ?? orderModel.vendor?.id ?? '').toString();
    if (orderId.isEmpty || vendorId.isEmpty) return;

    try {
      if (await _alreadyCredited(orderId)) {
        log("VendorWalletService: order $orderId already credited to the store, skipping");
        return;
      }

      // Commission is charged only when the order's section switched it on —
      // the Store app reads the same flag off the section it has selected.
      SectionModel? section;
      if ((orderModel.sectionId ?? '').isNotEmpty) {
        section = await FireStoreUtils.getSectionBySectionId(orderModel.sectionId!);
      }

      final credit = creditFor(orderModel, section: section);
      if (credit.total <= 0) {
        log("VendorWalletService: order $orderId earns the store nothing, skipping");
        return;
      }

      final DocumentReference<Map<String, dynamic>> orderRef = _db.collection(CollectionName.vendorOrders).doc(orderId);
      final DocumentReference<Map<String, dynamic>> storeRef = _db.collection(CollectionName.vendors).doc(vendorId);

      await _db.runTransaction((transaction) async {
        // All reads first, as Firestore requires.
        final orderSnap = await transaction.get(orderRef);
        if (orderSnap.data()?['vendorCredited'] == true) {
          log("VendorWalletService: order $orderId is already stamped vendorCredited, skipping");
          return;
        }
        final storeSnap = await transaction.get(storeRef);
        if (!storeSnap.exists) {
          log("VendorWalletService: store $vendorId no longer exists, skipping");
          return;
        }
        // APP-SPEC-STORE.md §2: the owner is `vendors/{id}.author`, never
        // `users where vendorID == storeId` (that asks whose SELECTED store
        // this is, which is wrong once a vendor holds several).
        final String ownerId = (storeSnap.data()?['author'] ?? orderModel.vendor?.author ?? '').toString();
        if (ownerId.isEmpty) {
          log("VendorWalletService: store $vendorId has no owner, skipping");
          return;
        }
        final DocumentReference<Map<String, dynamic>> ownerRef = _db.collection(CollectionName.users).doc(ownerId);
        final ownerSnap = await transaction.get(ownerRef);

        // Writes.
        final Timestamp now = Timestamp.now();
        transaction.set(_db.collection(CollectionName.wallet).doc(_creditRowId(orderId)), {
          'id': _creditRowId(orderId),
          'user_id': ownerId,
          'payment_method': 'Wallet',
          'amount': credit.basePrice,
          'isTopUp': true,
          'order_id': orderId,
          'payment_status': 'success',
          'date': now,
          'transactionUser': 'vendor',
          'note': 'Order Amount credited',
        });
        transaction.set(_db.collection(CollectionName.wallet).doc(_taxRowId(orderId)), {
          'id': _taxRowId(orderId),
          'user_id': ownerId,
          'payment_method': 'tax',
          'amount': credit.totalTaxAmount,
          'isTopUp': true,
          'order_id': orderId,
          'payment_status': 'success',
          'date': now,
          'transactionUser': 'vendor',
          'note': 'Order Tax credited',
        });

        final num storeTotal = _num(storeSnap.data()?['wallet_amount']) + credit.total;
        transaction.update(storeRef, {'wallet_amount': storeTotal});
        if (ownerSnap.exists) {
          final num ownerTotal = _num(ownerSnap.data()?['wallet_amount']) + credit.total;
          transaction.update(ownerRef, {'wallet_amount': ownerTotal});
        }
        transaction.set(orderRef, {'vendorCredited': true}, SetOptions(merge: true));
      });
    } catch (e, s) {
      // Never block the driver from finishing a delivery over a wallet write.
      log("VendorWalletService.creditStoreForCompletedOrder failed for $orderId: $e", stackTrace: s);
    }
  }
}
