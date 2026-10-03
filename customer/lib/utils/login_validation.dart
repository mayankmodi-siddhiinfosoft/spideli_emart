/// Email / password login: the checks made before the sign-in request and
/// the message shown for a failed sign-in. The same rules are used by the
/// login screens of all five apps (customer, driver, store, provider,
/// worker); only [accountDisabled] uses each app's own wording.
///
/// Pure Dart (no Flutter, Firebase or `dart:io`), so it behaves the same on
/// Android, iOS, the web and desktop. Every message is a translation key:
/// call `.tr` where it is shown.
class LoginValidation {
  LoginValidation._();

  static const String emailAndPasswordRequired = 'Please enter your email and password.';
  static const String emailRequired = 'Please enter your email address.';
  static const String passwordRequired = 'Please enter your password.';
  static const String emailInvalid = 'Please enter a valid email address.';
  static const String invalidCredentials = 'Invalid email or password.';
  static const String tooManyAttempts = 'Too many attempts. Please try again later.';
  static const String noConnection = 'No internet connection. Please check your connection and try again.';
  static const String accountDisabled = 'This user is disabled. Please contact admin.';
  static const String genericError = 'Something went wrong. Please try again.';

  /// The customer app's existing wording for an unknown address on the
  /// "Forgot password" screen.
  static const String resetUserNotFound = 'No user found for that email.';

  /// The pattern sign-up and profile screens already use (`validateEmail`,
  /// `GetUtils.isEmail`), so login never rejects an address they accepted.
  static final RegExp _email = RegExp(
    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
  );

  static bool isValidEmail(String email) => _email.hasMatch(email.trim());

  /// The message for the email field alone ("Forgot password"), or null when
  /// the address may be sent. Spaces only count as empty.
  static String? validateEmail(String email) {
    if (email.trim().isEmpty) return emailRequired;
    if (!isValidEmail(email)) return emailInvalid;
    return null;
  }

  /// The message for the password field alone, or null. Spaces only count as
  /// empty (the login screens trim the password before signing in).
  static String? validatePassword(String password) => password.trim().isEmpty ? passwordRequired : null;

  /// Every problem in the login form: one message per field (shown under
  /// that field) and one [LoginFormErrors.message] for the whole form (the
  /// toast). [LoginFormErrors.isValid] is true only when the sign-in request
  /// may be sent.
  static LoginFormErrors validateForm(String email, String password) {
    final String? emailError = validateEmail(email);
    final String? passwordError = validatePassword(password);
    final String? message = (emailError == emailRequired && passwordError != null) ? emailAndPasswordRequired : (emailError ?? passwordError);
    return LoginFormErrors(email: emailError, password: passwordError, message: message);
  }

  /// The message for the first problem in the form, or null when the sign-in
  /// request may be sent. A field holding only spaces counts as empty.
  static String? validate(String email, String password) => validateForm(email, password).message;

  /// Firebase error codes arrive in several spellings ('invalid-credential'
  /// on iOS and the web, 'invalid-login-credentials' or
  /// 'INVALID_LOGIN_CREDENTIALS' on Android, sometimes with an 'auth/'
  /// prefix on the web), so they are compared lower-case with dashes.
  static String _normalize(String code) {
    String c = code.trim().toLowerCase().replaceAll('_', '-');
    if (c.startsWith('auth/')) c = c.substring(5);
    return c;
  }

  /// The message for a failed sign-in, from a Firebase error [code]
  /// (`FirebaseAuthException.code`, or `FirebaseException.code` from the
  /// profile read that follows it). A wrong email, a wrong password or both
  /// give the same message, so the app never says which one was wrong, and
  /// Firebase's own (technical) text is never shown.
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
      case 'unavailable':
        return noConnection;
      default:
        return genericError;
    }
  }

  /// The message for a failed "Forgot password" request, from a Firebase
  /// Auth error [code]. Firebase's own text is never shown.
  static String passwordResetErrorMessage(String code) {
    switch (_normalize(code)) {
      case 'user-not-found':
        return resetUserNotFound;
      case 'invalid-email':
        return emailInvalid;
      case 'missing-email':
        return emailRequired;
      case 'user-disabled':
        return accountDisabled;
      case 'too-many-requests':
        return tooManyAttempts;
      case 'network-request-failed':
      case 'unavailable':
        return noConnection;
      default:
        return genericError;
    }
  }
}

/// The result of [LoginValidation.validateForm]: a translation key per field
/// (null when that field is fine) and one for the whole form.
class LoginFormErrors {
  final String? email;
  final String? password;
  final String? message;

  const LoginFormErrors({this.email, this.password, this.message});

  bool get isValid => message == null;
}
