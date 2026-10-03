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

  /// The message shown under the email field (login and "Forgot password"),
  /// or null when the email may be sent. Spaces alone count as empty.
  static String? emailError(String email) {
    if (email.trim().isEmpty) return emailRequired;
    if (!isValidEmail(email)) return emailInvalid;
    return null;
  }

  /// The message shown under the password field, or null when it is filled.
  /// Spaces alone count as empty.
  static String? passwordError(String password) => password.trim().isEmpty ? passwordRequired : null;

  /// The message for the first problem in the form, or null when the sign-in
  /// request may be sent. A field holding only spaces counts as empty; both
  /// fields empty give the one combined message.
  static String? validate(String email, String password) {
    final String? emailProblem = emailError(email);
    final String? passwordProblem = passwordError(password);
    if (emailProblem == emailRequired && passwordProblem != null) return emailAndPasswordRequired;
    return emailProblem ?? passwordProblem;
  }

  /// The message for a failed "Forgot password" request, or null when it is
  /// to be reported as sent. 'user-not-found' is reported as sent so the form
  /// never says whether an account exists for an email (what Firebase itself
  /// does when email enumeration protection is on).
  static String? passwordResetErrorMessage(String code) {
    if (_normalize(code) == 'user-not-found') return null;
    return authErrorMessage(code);
  }

  static String _normalize(String code) => code.trim().toLowerCase().replaceAll('_', '-');

  /// The message for a sign-in error [code] (Firebase Auth's, or Firestore's
  /// for the account read that follows the sign-in). A wrong email, a wrong
  /// password or both give the same message, so the app never says which one
  /// was wrong, and Firebase's own (technical) text is never shown.
  ///
  /// Codes arrive in several spellings ('invalid-credential' on iOS and the
  /// web, 'invalid-login-credentials' or 'INVALID_LOGIN_CREDENTIALS' on
  /// Android), so they are compared lower-case with dashes.
  static String authErrorMessage(String code) {
    switch (_normalize(code)) {
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
      case 'unavailable': // Firestore, offline
        return noConnection;
      default:
        return genericError;
    }
  }
}
