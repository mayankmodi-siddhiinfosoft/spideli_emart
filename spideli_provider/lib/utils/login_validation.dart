/// Email / password login: the checks made before the sign-in request and
/// the message shown for a failed sign-in. The same rules are used by the
/// login screens of all five apps (customer, driver, store, provider,
/// worker); only [accountDisabled] uses each app's own wording.
///
/// Every message is a translation key: call `.tr` where it is shown.
class LoginValidation {
  LoginValidation._();

  static const String emailAndPasswordRequired = 'Please enter your email and password.';
  static const String emailRequired = 'Please enter your email address.';
  static const String passwordRequired = 'Please enter your password.';
  static const String emailInvalid = 'Please enter a valid email address.';
  static const String invalidCredentials = 'Invalid email or password.';
  static const String tooManyAttempts = 'Too many attempts. Please try again later.';
  static const String noConnection = 'No internet connection. Please check your connection and try again.';
  static const String accountDisabled = 'This account has been disabled. Please contact the administrator.';
  static const String genericError = 'Something went wrong. Please try again.';

  /// The pattern sign-up and profile screens already use (`validateEmail`,
  /// `GetUtils.isEmail`), so login never rejects an address they accepted.
  static final RegExp _email = RegExp(
    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
  );

  static bool isValidEmail(String email) => _email.hasMatch(email.trim());

  /// The message for the first problem in the form, or null when the sign-in
  /// request may be sent. A field holding only spaces counts as empty.
  static String? validate(String email, String password) {
    final bool noEmail = email.trim().isEmpty;
    final bool noPassword = password.trim().isEmpty;
    if (noEmail && noPassword) return emailAndPasswordRequired;
    if (noEmail) return emailRequired;
    if (!isValidEmail(email)) return emailInvalid;
    if (noPassword) return passwordRequired;
    return null;
  }

  /// The message for a Firebase Auth sign-in error [code]. A wrong email, a
  /// wrong password or both give the same message, so the app never says
  /// which one was wrong, and Firebase's own (technical) text is never shown.
  ///
  /// Codes arrive in several spellings ('invalid-credential' on iOS and the
  /// web, 'invalid-login-credentials' or 'INVALID_LOGIN_CREDENTIALS' on
  /// Android), so they are compared lower-case with dashes.
  static String authErrorMessage(String code) {
    switch (code.trim().toLowerCase().replaceAll('_', '-')) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'invalid-password':
        return invalidCredentials;
      case 'invalid-email':
        return emailInvalid;
      case 'missing-email':
        return emailRequired;
      case 'missing-password':
        return passwordRequired;
      case 'user-disabled':
        return accountDisabled;
      case 'too-many-requests':
        return tooManyAttempts;
      case 'network-request-failed':
        return noConnection;
      default:
        return genericError;
    }
  }
}
