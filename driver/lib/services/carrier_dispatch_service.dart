import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/delivery_carrier_model.dart';
import 'package:driver/services/company_cash_push.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';

/// Carrier-bound parcels and the company's own carrier document.
///
/// An order that names a carrier (`carrierId`) is work of that delivery
/// company, and since 12 Oct 2026 it is never dispatched or searched for: the
/// company OWNER sees it in its Orders list and assigns one of its drivers
/// (`CarrierParcelRules`, `CarrierParcelService`,
/// `.claude/COMPANY-CARRIER-LINK.md` section 5). A company driver — and every
/// other driver — sees a carrier parcel only once the owner assigned it to
/// them. The parcel search and the offers apply `CarrierParcelRules` on the
/// whole order; [driverServesCarrier] is the carrier-id-only form of the same
/// rule.
class CarrierDispatchService {
  CarrierDispatchService._();

  /// Admin spec §11. Not in [CollectionName] because nothing else reads it.
  static const String collectionName = 'delivery_carriers';

  /// Kept for the sign-out / refresh callers; nothing is cached any more
  /// (the carrier→driver links are no longer read: only the owner assigns).
  static void clearCache() {}

  /// True when [driver] may be offered, or find in the open search, an order
  /// carried by [carrierId]: only an order without a carrier. A carrier
  /// parcel reaches a driver solely through its owner's assignment
  /// (`CarrierParcelRules.visibleToDriver`), which this id-only check cannot
  /// see — so it is never "served" here, whoever the driver is.
  static Future<bool> driverServesCarrier(String? carrierId, UserModel? driver) async => (carrierId ?? '').trim().isEmpty;

  // ── The company's own carrier document (client point 18) ────────────────

  /// The `delivery_carriers` row this owner account is bound to
  /// (`users/{uid}.carrierId`, APP-SPEC-CARRIER-OWNER-BINDING), or null when
  /// there is none yet ("set up your carrier"). Never searched for by other
  /// fields: the binding is the admin's, or the owner's own set-up
  /// ([createOwnCarrier]).
  static Future<DeliveryCarrierModel?> myCarrier({UserModel? user}) async {
    final UserModel? me = user ?? Constant.userModel;
    final String carrierId = (me?.carrierId ?? '').trim();
    if (carrierId.isEmpty) return null;
    try {
      final snap = await FireStoreUtils.fireStore.collection(collectionName).doc(carrierId).get();
      if (snap.exists && snap.data() != null) {
        return DeliveryCarrierModel(id: snap.id, raw: Map<String, dynamic>.from(snap.data()!));
      }
    } catch (e) {
      log("CarrierDispatchService.myCarrier failed: $e");
    }
    return null;
  }

  /// "Set up your carrier" (13 Oct 2026): creates the owner's own carrier
  /// from [data] (`CarrierSetupForm.build`: `ownerId` = [ownerId],
  /// `isVerified` / `publish` false) and binds the owner to it
  /// (`users/{ownerId}.carrierId`) in one batch. A carrier this owner
  /// already created (`ownerId` == the owner, e.g. a set-up whose binding did
  /// not land) is bound instead of creating a second one. Returns the carrier
  /// id, or null when nothing could be written.
  static Future<String?> createOwnCarrier({required String ownerId, required Map<String, dynamic> data}) async {
    final String owner = ownerId.trim();
    if (owner.isEmpty || data['ownerId'] != owner) return null;
    final FirebaseFirestore db = FireStoreUtils.fireStore;
    try {
      final existing = await db.collection(collectionName).where('ownerId', isEqualTo: owner).limit(1).get();
      final WriteBatch batch = db.batch();
      final DocumentReference<Map<String, dynamic>> ref;
      if (existing.docs.isNotEmpty) {
        ref = existing.docs.first.reference;
      } else {
        ref = db.collection(collectionName).doc();
        batch.set(ref, {
          ...data,
          'id': ref.id,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(db.collection(CollectionName.users).doc(owner), {'carrierId': ref.id});
      await batch.commit();
      if (Constant.userModel?.id == owner) Constant.userModel?.carrierId = ref.id;
      return ref.id;
    } catch (e) {
      log("CarrierDispatchService.createOwnCarrier failed: $e");
      return null;
    }
  }

  static final Map<String, String> _carrierNames = {};

  /// `{companyName}` for a push about [owner]'s company: the name of the
  /// carrier the owner is bound to (`delivery_carriers/{users.carrierId}`,
  /// read once per carrier), else the owner's `companyName`, else their name
  /// ([CompanyCashPush.companyNameOf]). Never throws.
  static Future<String> companyNameFor(UserModel? owner) async {
    if (owner == null) return '';
    final String carrierId = (owner.carrierId ?? '').trim();
    String? carrierName = carrierId.isEmpty ? null : _carrierNames[carrierId];
    if (carrierName == null && carrierId.isNotEmpty) {
      final DeliveryCarrierModel? carrier = await myCarrier(user: owner);
      carrierName = carrier?.text('name') ?? '';
      if (carrierName.trim().isNotEmpty) _carrierNames[carrierId] = carrierName;
    }
    return CompanyCashPush.companyNameOf(carrierName: carrierName, companyName: owner.companyName, ownerName: owner.fullName());
  }

  /// Saves the settings the owner maintains (brief section 6) with a
  /// field-path `update()` ([DeliveryCarrierModel.updatePaths]): only the keys
  /// that changed, e.g. `regionPricing.<regionId>.homePickupCharge`. Never a
  /// `set()` of the document, so nothing the admin manages is wiped, and
  /// nothing outside the owner's fields can be written.
  static Future<bool> saveCarrierSettings(DeliveryCarrierModel carrier, Map<String, dynamic> changes, {Map<String, Map<String, num?>> regionChanges = const {}}) async {
    final paths = carrier.updatePaths(changes, regionChanges: regionChanges);
    if (paths.isEmpty) return true;
    try {
      await FireStoreUtils.fireStore.collection(collectionName).doc(carrier.id).update({
        for (final entry in paths) FieldPath(entry.key): entry.value,
      });
      return true;
    } catch (e) {
      log("CarrierDispatchService.saveCarrierSettings failed: $e");
      return false;
    }
  }
}
