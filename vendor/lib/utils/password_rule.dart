/// Password length rule of the accounts the store creates for others (an
/// employee, a delivery man), checked BEFORE Firebase is called.
///
/// Report 56: a too-short password went straight to
/// `createUserWithEmailAndPassword`, which refuses it (`weak-password`), so the
/// owner only learnt about it after the round trip, if at all. Six is
/// Firebase's own floor; the hint under the field and the error use the same
/// [minLength], so the stated and the enforced number cannot differ.
///
/// The controllers trim the password before creating the account, so the
/// trimmed length is what counts. Pure (test/password_rule_test.dart).
class PasswordRule {
  PasswordRule._();

  static const int minLength = 6;

  /// Shown under the password field (translation key).
  static const String hint = 'At least 6 characters.';

  /// Shown next to the field when the password is too short (translation key).
  static const String tooShort = 'Password must be at least 6 characters.';

  /// The password is long enough to be sent to Firebase.
  static bool isLongEnough(String? password) => (password ?? '').trim().length >= minLength;

  /// The field's error for [password]: [tooShort] when it is too short, none
  /// when it is long enough - or empty, which the form's own "Please enter
  /// password" covers (two messages for one field reads as broken).
  static String? errorFor(String? password) {
    final String p = (password ?? '').trim();
    if (p.isEmpty) return null;
    return p.length < minLength ? tooShort : null;
  }
}
