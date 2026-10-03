import 'package:customer/lang/app_ar.dart';
import 'package:customer/lang/app_en.dart';
import 'package:customer/utils/login_validation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Login validation and error alerts (client request, 3 Oct 2026): checks
/// before the sign-in request, one message for any wrong credential, no
/// Firebase text.
void main() {
  group('LoginValidation.validate', () {
    test('both fields empty', () {
      expect(LoginValidation.validate('', ''), 'Please enter your email and password.');
      expect(LoginValidation.validate('   ', ' '), 'Please enter your email and password.');
      expect(LoginValidation.validate('\t', '\n'), 'Please enter your email and password.');
    });

    test('email empty', () {
      expect(LoginValidation.validate('', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('    ', 'secret1'), 'Please enter your email address.');
    });

    test('password empty', () {
      expect(LoginValidation.validate('user@example.com', ''), 'Please enter your password.');
      expect(LoginValidation.validate('user@example.com', '   '), 'Please enter your password.');
    });

    test('email format invalid', () {
      for (final email in ['a@b', 'a b@c.com', '@x.com', 'user', 'user@', 'user@example', 'user@@example.com', 'user@example.c', 'user@.com', 'user@exa mple.com']) {
        expect(LoginValidation.validate(email, 'secret1'), 'Please enter a valid email address.', reason: email);
      }
    });

    test('an invalid email is reported before an empty password', () {
      expect(LoginValidation.validate('a@b', ''), 'Please enter a valid email address.');
    });

    test('a well-formed email and a password may be sent', () {
      for (final email in ['a@b.co', 'user.name+tag@example.com', 'user@example.com', ' User.Name+tag@sub.example.co.uk ', 'a_b-c@mail-host.io']) {
        expect(LoginValidation.validate(email, 'secret1'), isNull, reason: email);
      }
    });
  });

  group('LoginValidation.validateForm', () {
    test('both empty: a message under each field and the combined toast', () {
      final e = LoginValidation.validateForm(' ', '');
      expect(e.isValid, isFalse);
      expect(e.email, LoginValidation.emailRequired);
      expect(e.password, LoginValidation.passwordRequired);
      expect(e.message, LoginValidation.emailAndPasswordRequired);
    });

    test('only the offending field gets a message', () {
      final noEmail = LoginValidation.validateForm('', 'secret1');
      expect(noEmail.email, LoginValidation.emailRequired);
      expect(noEmail.password, isNull);
      expect(noEmail.message, LoginValidation.emailRequired);

      final noPassword = LoginValidation.validateForm('user@example.com', '  ');
      expect(noPassword.email, isNull);
      expect(noPassword.password, LoginValidation.passwordRequired);
      expect(noPassword.message, LoginValidation.passwordRequired);

      final badEmail = LoginValidation.validateForm('a b@c.com', 'secret1');
      expect(badEmail.email, LoginValidation.emailInvalid);
      expect(badEmail.password, isNull);
      expect(badEmail.message, LoginValidation.emailInvalid);
    });

    test('invalid email and empty password: both fields marked', () {
      final e = LoginValidation.validateForm('@x.com', '');
      expect(e.email, LoginValidation.emailInvalid);
      expect(e.password, LoginValidation.passwordRequired);
      expect(e.message, LoginValidation.emailInvalid);
    });

    test('valid form', () {
      final e = LoginValidation.validateForm('a@b.co', 'x');
      expect(e.isValid, isTrue);
      expect(e.email, isNull);
      expect(e.password, isNull);
      expect(e.message, isNull);
    });
  });

  group('LoginValidation.validateEmail (forgot password)', () {
    test('empty, whitespace, invalid and valid', () {
      expect(LoginValidation.validateEmail(''), LoginValidation.emailRequired);
      expect(LoginValidation.validateEmail('   '), LoginValidation.emailRequired);
      expect(LoginValidation.validateEmail('a@b'), LoginValidation.emailInvalid);
      expect(LoginValidation.validateEmail('a b@c.com'), LoginValidation.emailInvalid);
      expect(LoginValidation.validateEmail('@x.com'), LoginValidation.emailInvalid);
      expect(LoginValidation.validateEmail(' a@b.co '), isNull);
      expect(LoginValidation.validateEmail('user.name+tag@example.com'), isNull);
    });
  });

  group('LoginValidation.authErrorMessage', () {
    test('a wrong email, a wrong password or both give the same message', () {
      for (final code in [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
        'INVALID_LOGIN_CREDENTIALS',
        'invalid-login-credentials',
        'auth/invalid-credential',
        'auth/wrong-password',
        ' Wrong-Password ',
      ]) {
        expect(LoginValidation.authErrorMessage(code), 'Invalid email or password.', reason: code);
      }
    });

    test('other codes get a friendly message, never Firebase text', () {
      expect(LoginValidation.authErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.authErrorMessage('too-many-requests'), 'Too many attempts. Please try again later.');
      expect(LoginValidation.authErrorMessage('network-request-failed'), 'No internet connection. Please check your connection and try again.');
      expect(LoginValidation.authErrorMessage('unavailable'), LoginValidation.noConnection);
      expect(LoginValidation.authErrorMessage('user-disabled'), 'This user is disabled. Please contact admin.');
      for (final code in ['internal-error', 'operation-not-allowed', 'channel-error', 'unknown', '', 'permission-denied']) {
        expect(LoginValidation.authErrorMessage(code), 'Something went wrong. Please try again.', reason: code);
      }
    });
  });

  group('LoginValidation.passwordResetErrorMessage', () {
    test('friendly messages for every code', () {
      expect(LoginValidation.passwordResetErrorMessage('user-not-found'), 'No user found for that email.');
      expect(LoginValidation.passwordResetErrorMessage('invalid-email'), LoginValidation.emailInvalid);
      expect(LoginValidation.passwordResetErrorMessage('missing-email'), LoginValidation.emailRequired);
      expect(LoginValidation.passwordResetErrorMessage('too-many-requests'), LoginValidation.tooManyAttempts);
      expect(LoginValidation.passwordResetErrorMessage('network-request-failed'), LoginValidation.noConnection);
      expect(LoginValidation.passwordResetErrorMessage('internal-error'), LoginValidation.genericError);
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
      LoginValidation.resetUserNotFound,
    ];
    for (final map in [enUS, arAR]) {
      expect(keys.where((k) => (map[k] ?? '').trim().isEmpty), isEmpty);
    }
    // Arabic is a real translation, not the English text copied over.
    expect(keys.where((k) => arAR[k] == k), isEmpty);
  });
}
