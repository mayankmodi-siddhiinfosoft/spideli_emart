/// The verification flags an account created in the Store app starts with
/// (report Doc 37).
///
/// `isDocumentVerify` is the administrator's verdict: the panel sets it true
/// only once every required document is approved. The app never sets it true
/// itself - a store with no documents and no decision used to be created
/// "verified" whenever store verification was switched off, which is the
/// misleading state Doc 37 describes. "No verification needed" is carried by
/// `isAutoVerify` instead, and every pending gate in the app reads both
/// (`isAutoVerify == false && isDocumentVerify == false`), so such a store is
/// not held.
abstract final class AccountVerification {
  /// A store owner signing up (email, Google, Apple or phone).
  /// [storeVerificationOn]: `isStoreVerification` in the panel's settings.
  static ({bool isDocumentVerify, bool isAutoVerify}) newStoreOwner({required bool storeVerificationOn}) => (isDocumentVerify: false, isAutoVerify: !storeVerificationOn);

  /// An employee the store adds. They upload no documents and the
  /// administrator never reviews them, so they are not "verified" either;
  /// `isAutoVerify` stays unset, which no pending gate holds.
  static const bool newEmployeeDocumentVerify = false;
}
