import 'package:driver/constant/constant.dart';
import 'package:driver/models/user_model.dart';

/// Who may work while their documents are still being reviewed (report Doc 37).
///
/// `users.isDocumentVerify` belongs to the administrator: the panel sets it to
/// `true` only once every required document has been approved. This app never
/// sets it to `true` — a registration, or a company creating a driver, starts
/// at `false` — and never writes it back on a later save
/// (`FireStoreUtils.updateUser`).
///
/// `isAutoVerify` is stamped at registration from the admin's
/// `document_verification_settings` (`true` = verification was off). The live
/// setting is consulted too, so turning verification OFF in the panel releases
/// a driver registered while it was on. A setting that has not loaded (null)
/// counts as "on": the stored flags decide, exactly as before.
class DocumentVerification {
  DocumentVerification._();

  /// The admin's current setting for [user]: `isOwnerVerification` for a
  /// company account, `isDriverVerification` for everyone else. `null` until
  /// the settings have loaded.
  static bool? settingFor(UserModel user, {bool? driverSetting, bool? ownerSetting}) {
    return user.isOwner == true ? (ownerSetting ?? Constant.isOwnerVerification) : (driverSetting ?? Constant.isDriverVerification);
  }

  /// True when [user] must provide documents that the admin reviews: they
  /// registered with verification on, and it has not been switched off since.
  static bool checksDocuments(UserModel? user, {bool? driverSetting, bool? ownerSetting}) {
    if (user == null) return false;
    if (user.isAutoVerify != false) return false;
    return settingFor(user, driverSetting: driverSetting, ownerSetting: ownerSetting) != false;
  }

  /// True while [user] is waiting for the administrator: documents are
  /// checked and the account is not verified yet.
  ///
  /// Never for a store's own delivery man (`vendorID` set): the store created
  /// him with `isDocumentVerify: false` (Doc 37) and assigns him its own
  /// orders, so he is not held back waiting for an approval, as the home
  /// screen and the offers gate already treat him. Expired or rejected
  /// documents still block going online (dashboard, [checksDocuments]).
  static bool isPending(UserModel? user, {bool? driverSetting, bool? ownerSetting}) {
    if (user == null) return false;
    if ((user.vendorID ?? '').isNotEmpty) return false;
    return user.isDocumentVerify != true && checksDocuments(user, driverSetting: driverSetting, ownerSetting: ownerSetting);
  }

  /// The values a NEW account starts with. [isCompany] picks the owner
  /// setting. `isDocumentVerify` is always `false`: only the admin sets it.
  static ({bool isDocumentVerify, bool isAutoVerify}) initialFlags({required bool isCompany, bool? driverSetting, bool? ownerSetting}) {
    final bool? setting = isCompany ? (ownerSetting ?? Constant.isOwnerVerification) : (driverSetting ?? Constant.isDriverVerification);
    // Auto-verified only when the admin has explicitly switched verification
    // off; an unknown setting asks for documents.
    return (isDocumentVerify: false, isAutoVerify: setting == false);
  }
}
