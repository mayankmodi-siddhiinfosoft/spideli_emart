import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/models/company_cash_model.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/carrier_dispatch_service.dart';
import 'package:driver/services/company_cash_push.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';
import 'package:flutter/foundation.dart';

/// Service managing company driver cash collections, settlements, and auditable balances.
/// Enforces:
/// 1. Outstanding Cash = Total Confirmed Cash Collections - Total Confirmed Cash Settlements
/// 2. Atomic Firestore transactions for settlements and prevents duplicates
/// 3. Owner-only authorization for settlement confirmation & adjustments
/// 4. Push notifications across driver and company owner, text only from the
///    `dynamic_notification` templates in [CompanyCashPush]
class CompanyCashService {
  static CollectionReference<Map<String, dynamic>> get _collection =>
      FireStoreUtils.fireStore.collection(CollectionName.companyCashLedger);

  /// Records a confirmed COD collection when a company driver completes a COD order.
  /// Idempotent: refuses duplicate collection records for the same orderId.
  static Future<bool> recordCodCollection({
    required ParcelOrderModel order,
    required UserModel driver,
    required double amount,
  }) async {
    final String? orderId = order.id;
    final String? ownerId = driver.ownerId;
    if (orderId == null || orderId.isEmpty || ownerId == null || ownerId.isEmpty || amount <= 0) {
      return false;
    }

    try {
      // Check for existing collection record for this order
      final existing = await _collection
          .where('orderId', isEqualTo: orderId)
          .where('type', isEqualTo: CompanyCashTransactionType.collection)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        debugPrint('CompanyCashService: Collection already recorded for order $orderId');
        return true;
      }

      final String txId = Constant.getUuid();
      final tx = CompanyCashTransactionModel(
        id: txId,
        ownerId: ownerId,
        driverId: driver.id ?? FireStoreUtils.getCurrentUid(),
        driverName: driver.fullName(),
        orderId: orderId,
        orderType: 'parcel',
        type: CompanyCashTransactionType.collection,
        amount: amount,
        paymentMethod: order.paymentMethod ?? 'cod',
        status: CompanyCashTransactionStatus.confirmed,
        createdAt: Timestamp.now(),
        confirmedAt: Timestamp.now(),
        notes: 'Cash collected on delivery for order #$orderId',
      );

      await _collection.doc(txId).set(tx.toJson());

      // Notify the Company Owner (template, amount in the order's currency).
      final UserModel? owner = await FireStoreUtils.getUserProfile(ownerId);
      await _push(
        CompanyCashPush.collected,
        recipient: owner,
        payload: {
          'type': 'company_cash_collection',
          'orderId': orderId,
          'driverId': driver.id ?? '',
          'amount': amount.toString(),
        },
        placeholders: CompanyCashPush.values(
          amount: Constant.amountShow(amount: amount.toString(), currency: RegionService.currencyForRecord(order.regionId)),
          driverName: driver.fullName(),
          companyName: await CarrierDispatchService.companyNameFor(owner),
          orderId: orderId,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('CompanyCashService.recordCodCollection error: $e');
      return false;
    }
  }

  /// Submits a settlement request from the driver to the owner.
  /// Status is initially `pending`.
  static Future<bool> submitSettlementRequest({
    required String ownerId,
    required double amount,
    String? notes,
  }) async {
    final user = Constant.userModel;
    if (user == null || amount <= 0 || ownerId.isEmpty) return false;

    try {
      final String txId = Constant.getUuid();
      final tx = CompanyCashTransactionModel(
        id: txId,
        ownerId: ownerId,
        driverId: user.id ?? FireStoreUtils.getCurrentUid(),
        driverName: user.fullName(),
        type: CompanyCashTransactionType.settlement,
        amount: amount,
        status: CompanyCashTransactionStatus.pending,
        createdAt: Timestamp.now(),
        notes: notes ?? 'Cash settlement handed over by driver',
      );

      await _collection.doc(txId).set(tx.toJson());

      // Notify Company Owner (template).
      final UserModel? owner = await FireStoreUtils.getUserProfile(ownerId);
      await _push(
        CompanyCashPush.settlementSubmitted,
        recipient: owner,
        payload: {
          'type': 'company_settlement_submitted',
          'settlementId': txId,
          'driverId': user.id ?? '',
          'amount': amount.toString(),
        },
        placeholders: CompanyCashPush.values(
          amount: _money(amount, user),
          driverName: user.fullName(),
          companyName: await CarrierDispatchService.companyNameFor(owner),
          reference: txId,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('CompanyCashService.submitSettlementRequest error: $e');
      return false;
    }
  }

  /// Owner-only: Confirms receipt of cash settlement in an atomic Firestore transaction.
  static Future<bool> confirmSettlement({
    required String transactionId,
  }) async {
    final ownerUid = FireStoreUtils.getCurrentUid();
    try {
      String? driverId;
      String? driverName;
      double amount = 0.0;

      await FireStoreUtils.fireStore.runTransaction((transaction) async {
        final ref = _collection.doc(transactionId);
        final snap = await transaction.get(ref);
        if (!snap.exists || snap.data() == null) {
          throw 'Settlement transaction not found';
        }
        final data = snap.data()!;
        if (data['ownerId'] != ownerUid) {
          throw 'Unauthorized: Only the company owner can confirm settlements';
        }
        if (data['status'] == CompanyCashTransactionStatus.confirmed) {
          return; // Already confirmed
        }

        driverId = data['driverId']?.toString();
        driverName = data['driverName']?.toString();
        amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        transaction.update(ref, {
          'status': CompanyCashTransactionStatus.confirmed,
          'confirmedAt': Timestamp.now(),
          'verifiedBy': ownerUid,
        });
      });

      // Notify Driver (template).
      if (driverId != null && driverId!.isNotEmpty) {
        final UserModel? driver = await FireStoreUtils.getUserProfile(driverId!);
        await _push(
          CompanyCashPush.settlementConfirmed,
          recipient: driver,
          payload: {
            'type': 'company_settlement_confirmed',
            'settlementId': transactionId,
          },
          placeholders: CompanyCashPush.values(
            amount: _money(amount, driver),
            driverName: driverName ?? driver?.fullName(),
            companyName: await _myCompanyName(),
            reference: transactionId,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('CompanyCashService.confirmSettlement error: $e');
      rethrow;
    }
  }

  /// Owner-only: Rejects a cash settlement with a mandatory rejection reason.
  static Future<bool> rejectSettlement({
    required String transactionId,
    required String reason,
  }) async {
    final ownerUid = FireStoreUtils.getCurrentUid();
    try {
      final doc = await _collection.doc(transactionId).get();
      if (!doc.exists || doc.data() == null) throw 'Settlement transaction not found';
      final data = doc.data()!;
      if (data['ownerId'] != ownerUid) {
        throw 'Unauthorized: Only the company owner can reject settlements';
      }

      await _collection.doc(transactionId).update({
        'status': CompanyCashTransactionStatus.rejected,
        'confirmedAt': Timestamp.now(),
        'verifiedBy': ownerUid,
        'rejectionReason': reason,
      });

      final String? driverId = data['driverId']?.toString();
      final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

      // Notify Driver (template).
      if (driverId != null && driverId.isNotEmpty) {
        final UserModel? driver = await FireStoreUtils.getUserProfile(driverId);
        await _push(
          CompanyCashPush.settlementRejected,
          recipient: driver,
          payload: {
            'type': 'company_settlement_rejected',
            'settlementId': transactionId,
          },
          placeholders: CompanyCashPush.values(
            amount: _money(amount, driver),
            driverName: data['driverName']?.toString() ?? driver?.fullName(),
            companyName: await _myCompanyName(),
            reference: transactionId,
            reason: reason,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('CompanyCashService.rejectSettlement error: $e');
      rethrow;
    }
  }

  /// Owner-only: Records an auditable balance adjustment.
  static Future<bool> recordOwnerAdjustment({
    required String driverId,
    required String driverName,
    required double amount,
    required String reason,
    required bool isCredit,
  }) async {
    final ownerUid = FireStoreUtils.getCurrentUid();
    try {
      final String txId = Constant.getUuid();
      final tx = CompanyCashTransactionModel(
        id: txId,
        ownerId: ownerUid,
        driverId: driverId,
        driverName: driverName,
        type: CompanyCashTransactionType.adjustment,
        amount: amount,
        isCredit: isCredit,
        status: CompanyCashTransactionStatus.confirmed,
        createdAt: Timestamp.now(),
        confirmedAt: Timestamp.now(),
        verifiedBy: ownerUid,
        notes: reason,
      );

      await _collection.doc(txId).set(tx.toJson());

      // Notify Driver (template).
      final UserModel? driver = await FireStoreUtils.getUserProfile(driverId);
      await _push(
        CompanyCashPush.adjustment,
        recipient: driver,
        payload: {
          'type': 'company_cash_adjustment',
          'adjustmentId': txId,
        },
        placeholders: CompanyCashPush.values(
          amount: _money(amount, driver),
          driverName: driverName,
          companyName: await _myCompanyName(),
          reference: txId,
          reason: reason,
          isCredit: isCredit,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('CompanyCashService.recordOwnerAdjustment error: $e');
      rethrow;
    }
  }

  /// The templated company cash push [template] (`CompanyCashPush`) to
  /// [recipient] (its live token), on the driver app's general channel, with
  /// [placeholders] filled in. No template, or no token: no push (logged by
  /// `SendNotification`). Never throws: the ledger write already happened.
  static Future<void> _push(String template, {required UserModel? recipient, required Map<String, dynamic> payload, required Map<String, String> placeholders}) async {
    try {
      await SendNotification.sendFcmMessage(template, (recipient?.fcmToken ?? '').trim(), payload, recipient: PushRecipient.driver, placeholders: placeholders);
    } catch (e) {
      debugPrint('CompanyCashService push $template failed: $e');
    }
  }

  /// [amount] formatted in [driver]'s region currency (the ledger has no
  /// currency of its own; a company's drivers work in its region), else the
  /// app's live currency.
  static String _money(double amount, UserModel? driver) => Constant.amountShow(amount: amount.toString(), currency: RegionService.currencyForRecord(driver?.regionId));

  /// `{companyName}` for pushes the signed-in owner sends.
  static Future<String> _myCompanyName() => CarrierDispatchService.companyNameFor(Constant.userModel);

  /// Stream of transactions for a specific driver, newest first.
  ///
  /// One equality filter and the order applied on the device: an
  /// `orderBy('createdAt')` next to the filter needs a composite index that
  /// `company_cash_ledger` (a new collection) does not have, and the query
  /// then failed - the settlement screens showed only an error.
  static Stream<List<CompanyCashTransactionModel>> streamDriverTransactions(String driverId) {
    return _collection
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snap) => CompanyCashTransactionModel.newestFirst(snap.docs.map((d) => CompanyCashTransactionModel.fromJson(d.data()))));
  }

  /// Stream of transactions for a company owner across all drivers, newest
  /// first (sorted on the device, see [streamDriverTransactions]).
  static Stream<List<CompanyCashTransactionModel>> streamOwnerTransactions(String ownerId) {
    return _collection
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) => CompanyCashTransactionModel.newestFirst(snap.docs.map((d) => CompanyCashTransactionModel.fromJson(d.data()))));
  }
}
