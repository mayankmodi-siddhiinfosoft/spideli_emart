import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/lang/app_en.dart';
import 'package:spideliworker/utils/login_validation.dart';

/// Login validation and error alerts (user request): checks before the
/// sign-in request, one message for any wrong credential, no Firebase text.
void main() {
  group('LoginValidation.validate (before any request)', () {
    test('empty fields', () {
      expect(LoginValidation.validate('', ''), 'Please enter your email and password.');
      expect(LoginValidation.validate('  ', ' '), 'Please enter your email and password.');
      expect(LoginValidation.validate('', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('worker@example.com', ''), 'Please enter your password.');
    });

    test('email format', () {
      for (final email in ['worker', 'worker@', '@example.com', 'worker@example', 'worker x@example.com', 'worker@example.c']) {
        expect(LoginValidation.validate(email, 'secret1'), 'Please enter a valid email address.', reason: email);
      }
      expect(LoginValidation.validate('worker.one+x@example.co.in', 'secret1'), isNull);
    });
  });

  group('LoginValidation.authErrorMessage', () {
    test('a wrong email, a wrong password or both give one message that does not say which', () {
      for (final code in ['invalid-credential', 'INVALID_LOGIN_CREDENTIALS', 'invalid-login-credentials', 'wrong-password', 'user-not-found']) {
        expect(LoginValidation.authErrorMessage(code), 'Invalid email or password.', reason: code);
      }
    });

    test('every other code gets a friendly message, never "Unexpected firebase error"', () {
      expect(LoginValidation.authErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.authErrorMessage('too-many-requests'), contains('Too many attempts'));
      expect(LoginValidation.authErrorMessage('network-request-failed'), contains('internet'));
      expect(LoginValidation.authErrorMessage('user-disabled'), LoginValidation.accountDisabled);
      expect(LoginValidation.authErrorMessage('internal-error'), 'Something went wrong. Please try again.');
    });
  });

  test('every login message is in the English map', () {
    const keys = [
      LoginValidation.emailAndPasswordRequired,
      LoginValidation.emailRequired,
      LoginValidation.passwordRequired,
      LoginValidation.emailInvalid,
      LoginValidation.invalidCredentials,
      LoginValidation.tooManyAttempts,
      LoginValidation.noConnection,
      LoginValidation.accountDisabled,
      LoginValidation.genericError,
    ];
    expect(keys.where((k) => (enUS[k] ?? '').trim().isEmpty), isEmpty);
  });
}
