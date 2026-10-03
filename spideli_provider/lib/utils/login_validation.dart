/// Email / password login: the checks made before the sign-in request and
/// the message shown for a failed sign-in. The same rules are used by the
/// login screens of all five apps (customer, driver, store, provider,
/// worker); only [accountDisabled] uses each app's own wording.
///
/// Pure Dart (no Flutter, Firebase or `dart:io`), so it behaves the same on
/// Android, iOS, the web and desktop and is unit tested directly.
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
  /// This app's existing wording (Google / Apple / phone login, OTP screen).
  static const String accountDisabled = 'This user is disable please contact to administrator';
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

  /// The message shown under each field (null when that field is fine).
  /// Sign-in may be sent only when both are null, exactly when [validate]
  /// returns null.
  static ({String? email, String? password}) fieldErrors(String email, String password) {
    return (
      email: validateEmail(email),
      password: password.trim().isEmpty ? passwordRequired : null,
    );
  }

  /// The email check on its own (the "Forgot password" field): empty or
  /// whitespace only, then the format. Null when the address may be sent.
  static String? validateEmail(String email) {
    if (email.trim().isEmpty) return emailRequired;
    if (!isValidEmail(email)) return emailInvalid;
    return null;
  }

  /// `INVALID_LOGIN_CREDENTIALS`, `auth/invalid-credential` or
  /// `ERROR_WRONG_PASSWORD` all become `invalid-login-credentials`,
  /// `invalid-credential` and `wrong-password`: the code spellings differ
  /// between Android, iOS, the web and plugin versions.
  static String _normalise(String code) {
    String c = code.trim().toLowerCase().replaceAll('_', '-');
    if (c.startsWith('auth/')) c = c.substring(5);
    if (c.startsWith('error-')) c = c.substring(6);
    return c;
  }

  /// The message for a Firebase sign-in error [code]. A wrong email, a
  /// wrong password or both give the same message, so the app never says
  /// which one was wrong, and Firebase's own (technical) text is never shown.
  ///
  /// [detail] is the exception's own message. It is never shown; it is only
  /// read for older Android builds that report a wrong password as an
  /// 'unknown' / 'internal-error' code carrying `INVALID_LOGIN_CREDENTIALS`.
  static String authErrorMessage(String code, [String? detail]) {
    switch (_normalise(code)) {
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
      case 'unavailable':
        return noConnection;
      default:
        if ((detail ?? '').toUpperCase().contains('INVALID_LOGIN_CREDENTIALS')) return invalidCredentials;
        return genericError;
    }
  }

  /// The message for a failed "Forgot password" request, or null when the
  /// app should answer as if the email was sent: an address without an
  /// account gets the same answer as one with an account, so the screen does
  /// not reveal which emails are registered.
  static String? passwordResetErrorMessage(String code, [String? detail]) {
    if (_normalise(code) == 'user-not-found') return null;
    final String message = authErrorMessage(code, detail);
    // Not a sign-in: "Invalid email or password." would not make sense here.
    return message == invalidCredentials ? genericError : message;
  }
}
