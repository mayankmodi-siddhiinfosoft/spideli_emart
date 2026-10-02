import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/utils/fire_store_utils.dart';

/// One wallet movement per order and purpose, whatever the number of tries.
///
/// A delivery's completion pays several people (the driver, the customer's
/// cashback, the referrer). It can fail half-way and be retried, and the
/// Driver and Store apps can both complete a self-delivery order. Each
/// payment therefore has a deterministic `wallet` row id (e.g.
/// `cashback_<orderId>`); the row and the user's `wallet_amount` are written
/// in ONE transaction that first checks the row does not exist. A second run
/// is a no-op, and a run that fails part-way writes nothing.
abstract final class WalletOnce {
  /// The `wallet` row ids shared with the Store app.
  static String cashbackRowId(String orderId) => 'cashback_$orderId';
  static String driverRowId(String orderId) => 'driver_$orderId';
  static String referralRowId(String orderId) => 'referral_$orderId';

  /// Writes [row] as `wallet/{rowId}` and adds [amount] to `users/{userId}.wallet_amount`,
  /// unless that row already exists. Returns true when it paid now.
  static Future<bool> pay({required String rowId, required Map<String, dynamic> row, required String? userId, required num amount}) async {
    final FirebaseFirestore db = FireStoreUtils.fireStore;
    final DocumentReference<Map<String, dynamic>> rowRef = db.collection(CollectionName.wallet).doc(rowId);
    final DocumentReference<Map<String, dynamic>>? userRef = (userId == null || userId.isEmpty) ? null : db.collection(CollectionName.users).doc(userId);
    num? newTotal;
    final bool paid = await db.runTransaction<bool>((tx) async {
      newTotal = null;
      final DocumentSnapshot<Map<String, dynamic>> existing = await tx.get(rowRef);
      if (existing.exists) return false;
      final DocumentSnapshot<Map<String, dynamic>>? user = userRef == null ? null : await tx.get(userRef);
      tx.set(rowRef, {...row, 'id': rowId});
      if (user != null && user.exists) {
        newTotal = (num.tryParse(user.data()?['wallet_amount']?.toString() ?? '') ?? 0) + amount;
        tx.update(userRef!, {'wallet_amount': newTotal});
      }
      return true;
    });
    // Keep the signed-in user's copy in step, so a later full save of it
    // does not write the old balance back.
    if (paid && newTotal != null && userId != null && Constant.userModel?.id == userId) {
      Constant.userModel!.walletAmount = newTotal;
    }
    return paid;
  }
}
