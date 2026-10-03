import 'package:customer/lang/app_ar.dart';
import 'package:customer/lang/app_en.dart';
import 'package:customer/utils/login_validation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Login validation and error alerts (user request): checks before the
/// sign-in request, one message for any wrong credential, no Firebase text.
void main() {
  group('LoginValidation.validate', () {
    test('both fields empty', () {
      expect(LoginValidation.validate('', ''), 'Please enter your email and password.');
      expect(LoginValidation.validate('   ', ' '), 'Please enter your email and password.');
    });

    test('email empty', () {
      expect(LoginValidation.validate('', 'secret1'), 'Please enter your email address.');
    });

    test('password empty', () {
      expect(LoginValidation.validate('user@example.com', ''), 'Please enter your password.');
      expect(LoginValidation.validate('user@example.com', '   '), 'Please enter your password.');
    });

    test('email format invalid', () {
      for (final email in ['user', 'user@', '@example.com', 'user@example', 'user example@mail.com', 'user@@example.com', 'user@example.c']) {
        expect(LoginValidation.validate(email, 'secret1'), 'Please enter a valid email address.', reason: email);
      }
    });

    test('a well-formed email and a password may be sent', () {
      for (final email in ['user@example.com', ' User.Name+tag@sub.example.co.uk ', 'a_b-c@mail-host.io']) {
        expect(LoginValidation.validate(email, 'secret1'), isNull, reason: email);
      }
    });
  });

  group('LoginValidation.authErrorMessage', () {
    test('a wrong email, a wrong password or both give the same message', () {
      for (final code in ['user-not-found', 'wrong-password', 'invalid-credential', 'INVALID_LOGIN_CREDENTIALS', 'invalid-login-credentials']) {
        expect(LoginValidation.authErrorMessage(code), 'Invalid email or password.', reason: code);
      }
    });

    test('other codes get a friendly message, never Firebase text', () {
      expect(LoginValidation.authErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.authErrorMessage('too-many-requests'), 'Too many attempts. Please try again later.');
      expect(LoginValidation.authErrorMessage('network-request-failed'), contains('internet'));
      expect(LoginValidation.authErrorMessage('user-disabled'), LoginValidation.accountDisabled);
      expect(LoginValidation.authErrorMessage('internal-error'), 'Something went wrong. Please try again.');
    });
  });

  test('every login message is translated', () {
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
    for (final map in [enUS, arAR]) {
      expect(keys.where((k) => (map[k] ?? '').trim().isEmpty), isEmpty);
    }
  });
}
