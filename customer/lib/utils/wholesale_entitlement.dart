import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/business_account.dart';

/// **Wholesale is for approved business accounts only** - WEB spec §19, the
/// client's decision of 30 September, which closed the question §10 left open.
///
/// | Product | An ordinary customer sees |
/// |---|---|
/// | wholesale-only (`saleType: "wholesale"`) | nothing - it is hidden |
/// | mixed (a retail price *and* tiers) | the product, at RETAIL: no badge, no ladder, no tier price however many they buy, no pack minimum |
/// | retail | unchanged |
///
/// "Approved" is the ADMIN panel's decision, not the customer's request:
/// `users/{uid}.accountType == "business"` **AND**
/// `businessProfile.status == "approved"`. Pending or rejected buys nothing.
///
/// **This is ONE switch, read in one place.** Every screen reads it through
/// `ProductModel.wholesaleAvailableToCustomer` - the app's equivalent of the
/// website's `wholesaleEnabled && customerMayBuyWholesale` in
/// `processVendorData` - so withholding it here withholds the badge, the
/// ladder, the minimum quantity and the price charged across every screen at
/// once instead of in seven places.
///
/// **It fails CLOSED.** Signed out, a read error, a missing document or a
/// document that has not been looked at yet all mean retail. Withholding a
/// discount from someone entitled to it is a support call; handing it to
/// everyone when Firestore hiccups is the client's margin.
class WholesaleEntitlement {
  WholesaleEntitlement._();

  static const String accountTypeBusiness = 'business';

  /// The answer of the one Firestore read this session makes, and the uid it
  /// was made for (so it can never survive a sign-out or a different account).
  static bool? _lookup;
  static String? _lookupUid;

  /// Whether wholesale applies to the customer signed in right now.
  ///
  /// The session's own copy of `users/{uid}` ([Constant.userModel], read at
  /// launch and refreshed by [BusinessAccount.refresh]) answers it until
  /// [load] has run; both paths fail closed, and a null user - signed out, or
  /// a profile that could not be read - is never approved.
  static bool get mayBuyWholesale {
    final String uid = (Constant.userModel?.id ?? '').trim();
    if (uid.isEmpty) return false;
    if (_lookupUid == uid && _lookup != null) return _lookup!;
    return isApprovedUser(Constant.userModel);
  }

  /// True only for `accountType: "business"` + `businessProfile.status:
  /// "approved"` (ADMIN §18). Anything else - pending, rejected, absent,
  /// a personal account, no user at all - is false.
  static bool isApprovedUser(UserModel? user) {
    if (user == null) return false;
    if ((user.accountType ?? '').trim().toLowerCase() != accountTypeBusiness) return false;
    return (user.businessProfile?['status']?.toString().trim().toLowerCase() ?? '') == BusinessAccount.statusApproved;
  }

  /// The same verdict straight off a `users/{uid}` document.
  static bool isApprovedDocument(Map<String, dynamic>? data) {
    if (data == null) return false;
    if ((data['accountType']?.toString().trim().toLowerCase() ?? '') != accountTypeBusiness) return false;
    final dynamic raw = data['businessProfile'];
    if (raw is! Map) return false;
    return (raw['status']?.toString().trim().toLowerCase() ?? '') == BusinessAccount.statusApproved;
  }

  /// Looks the status up ONCE per session and caches it, the shape WEB §19's
  /// `loadBusinessAccountStatus()` / `businessAccountReady` has: awaited at
  /// launch so nothing renders on a guess, and re-run (with [force]) when the
  /// account's business status changes rather than on every listing.
  ///
  /// Every failure path answers false.
  static Future<bool> load({bool force = false}) async {
    final String uid = (Constant.userModel?.id ?? '').trim();
    if (uid.isEmpty) {
      invalidate();
      return false;
    }
    if (!force && _lookupUid == uid && _lookup != null) return _lookup!;
    try {
      final doc = await FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).get();
      _lookupUid = uid;
      _lookup = doc.exists && isApprovedDocument(doc.data());
    } catch (e) {
      // Fails closed: retail, and the session copy is not trusted either.
      log('WholesaleEntitlement.load failed, wholesale withheld: $e');
      _lookupUid = uid;
      _lookup = false;
    }
    return _lookup!;
  }

  /// Sets the verdict from a `users/{uid}` document already in hand, so a
  /// refresh costs no second read.
  static void applyDocument(String uid, Map<String, dynamic>? data) {
    if (uid.trim().isEmpty) return invalidate();
    _lookupUid = uid.trim();
    _lookup = isApprovedDocument(data);
  }

  /// Drops the cached answer: signing out, or a business status that has just
  /// changed and has to be looked at again.
  static void invalidate() {
    _lookup = null;
    _lookupUid = null;
  }
}
