import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

/// Stores owned by one vendor account.
///
/// An account may own several stores. The list is derived from
/// `vendors where author == ownerId` and never stored, so it cannot drift from
/// the `vendors` collection. `users.vendorID` holds the store currently
/// selected: every screen already reads it, so switching store only has to
/// rewrite that one field.
class StoreService {
  StoreService._();

  static Future<List<VendorModel>> getOwnerStores(String ownerId) async {
    final snapshot = await FireStoreUtils.fireStore.collection(CollectionName.vendors).where('author', isEqualTo: ownerId).get();
    final stores = snapshot.docs.map((doc) => VendorModel.fromJson(doc.data())).toList();
    stores.sort((a, b) => (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
    return stores;
  }

  /// Makes [storeId] the store the app works on. Only the owner's own
  /// `vendorID` changes; employees keep the store they were created for.
  static Future<void> selectStore(String storeId) async {
    final String ownerId = FireStoreUtils.getCurrentUid();
    await FireStoreUtils.fireStore.collection(CollectionName.users).doc(ownerId).update({'vendorID': storeId});
    Constant.userModel?.vendorID = storeId;
  }
}
