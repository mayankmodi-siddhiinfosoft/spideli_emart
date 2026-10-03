import 'package:driver/lang/app_ar.dart';
import 'package:driver/lang/app_de.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/lang/app_fr.dart';
import 'package:driver/lang/app_hi.dart';
import 'package:driver/lang/app_ja.dart';
import 'package:driver/lang/app_pt.dart';
import 'package:driver/lang/app_ru.dart';
import 'package:driver/lang/app_zh.dart';
import 'package:driver/utils/login_validation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client requirement (3 Oct): "Improve Login Validation & Error Alerts".
/// The checks made before the sign-in request (pure Dart, so the same on
/// Android, iOS, web and desktop) and the messages for a failed request.
void main() {
  const valid = ['a@b.co', 'user.name+tag@example.com', 'driver.one+x@example.co.in', 'a_b-c@mail-host.io', '  padded@example.com  '];
  const invalid = ['a@b', 'a b@c.com', '@x.com', 'driver', 'driver@', 'user@@example.com', 'user@example.c', 'user@exa mple.com'];

  group('LoginValidation.validate (the toast, before any request)', () {
    test('both fields empty', () {
      expect(LoginValidation.validate('', ''), 'Please enter your email and password.');
    });

    test('email empty', () {
      expect(LoginValidation.validate('', 'secret1'), 'Please enter your email address.');
    });

    test('password empty', () {
      expect(LoginValidation.validate('driver@example.com', ''), 'Please enter your password.');
    });

    test('only spaces counts as empty', () {
      expect(LoginValidation.validate('   ', ' \t '), 'Please enter your email and password.');
      expect(LoginValidation.validate('  ', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('driver@example.com', '    '), 'Please enter your password.');
    });

    test('email format invalid', () {
      for (final email in invalid) {
        expect(LoginValidation.validate(email, 'secret1'), 'Please enter a valid email address.', reason: email);
      }
    });

    test('an invalid email is reported before an empty password', () {
      expect(LoginValidation.validate('a@b', ''), 'Please enter a valid email address.');
    });

    test('a well-formed email and a password may be sent', () {
      for (final email in valid) {
        expect(LoginValidation.validate(email, 'secret1'), isNull, reason: email);
      }
    });
  });

  group('LoginValidation.isValidEmail', () {
    test('accepts well-formed addresses (surrounding spaces ignored)', () {
      for (final email in valid) {
        expect(LoginValidation.isValidEmail(email), isTrue, reason: email);
      }
    });

    test('rejects malformed addresses', () {
      for (final email in [...invalid, '', '   ']) {
        expect(LoginValidation.isValidEmail(email), isFalse, reason: email);
      }
    });
  });

  group('field errors (shown under each field)', () {
    test('email field', () {
      expect(LoginValidation.emailError(''), 'Please enter your email address.');
      expect(LoginValidation.emailError('   '), 'Please enter your email address.');
      for (final email in invalid) {
        expect(LoginValidation.emailError(email), 'Please enter a valid email address.', reason: email);
      }
      for (final email in valid) {
        expect(LoginValidation.emailError(email), isNull, reason: email);
      }
    });

    test('password field', () {
      expect(LoginValidation.passwordError(''), 'Please enter your password.');
      expect(LoginValidation.passwordError('   '), 'Please enter your password.');
      expect(LoginValidation.passwordError(' secret1 '), isNull);
    });

    test('both empty: each field shows its own message', () {
      expect(LoginValidation.emailError(''), LoginValidation.emailRequired);
      expect(LoginValidation.passwordError(''), LoginValidation.passwordRequired);
    });

    test('the form may be sent exactly when neither field has an error', () {
      const emails = ['', '  ', 'a@b', '@x.com', 'a@b.co', 'user.name+tag@example.com'];
      const passwords = ['', '   ', 'secret1'];
      for (final email in emails) {
        for (final password in passwords) {
          final bool fieldsOk = LoginValidation.emailError(email) == null && LoginValidation.passwordError(password) == null;
          expect(LoginValidation.validate(email, password) == null, fieldsOk, reason: '"$email" / "$password"');
        }
      }
    });
  });

  group('LoginValidation.authErrorMessage (a failed sign-in)', () {
    test('a wrong email, a wrong password or both give the same message', () {
      for (final code in ['user-not-found', 'wrong-password', 'invalid-credential', 'INVALID_LOGIN_CREDENTIALS', 'invalid-login-credentials', 'invalid-password', ' Invalid-Credential ']) {
        expect(LoginValidation.authErrorMessage(code), 'Invalid email or password.', reason: code);
      }
    });

    test('other codes get a friendly message, never Firebase text', () {
      expect(LoginValidation.authErrorMessage('network-request-failed'), 'No internet connection. Please check your connection and try again.');
      expect(LoginValidation.authErrorMessage('too-many-requests'), 'Too many attempts. Please try again later.');
      expect(LoginValidation.authErrorMessage('user-disabled'), LoginValidation.accountDisabled);
      expect(LoginValidation.authErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.authErrorMessage('missing-email'), 'Please enter your email address.');
      expect(LoginValidation.authErrorMessage('missing-password'), 'Please enter your password.');
      for (final code in ['internal-error', 'unknown', 'operation-not-allowed', 'app-check-token-invalid', '']) {
        expect(LoginValidation.authErrorMessage(code), 'Something went wrong. Please try again.', reason: code);
      }
    });
  });

  group('LoginValidation.resetErrorMessage (Forgot password)', () {
    test('an unknown address keeps the existing message', () {
      expect(LoginValidation.resetErrorMessage('user-not-found'), 'No user found for that email.');
    });

    test('other codes get a friendly message', () {
      expect(LoginValidation.resetErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.resetErrorMessage('missing-email'), 'Please enter your email address.');
      expect(LoginValidation.resetErrorMessage('network-request-failed'), LoginValidation.noConnection);
      expect(LoginValidation.resetErrorMessage('too-many-requests'), LoginValidation.tooManyAttempts);
      expect(LoginValidation.resetErrorMessage('user-disabled'), LoginValidation.accountDisabled);
      expect(LoginValidation.resetErrorMessage('invalid-credential'), LoginValidation.genericError);
      expect(LoginValidation.resetErrorMessage('internal-error'), LoginValidation.genericError);
    });
  });

  test('every login message is translated in every language', () {
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
      LoginValidation.noAccountForEmail,
    ];
    final maps = {'en': enUS, 'ar': lnAr, 'de': deGR, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
    for (final entry in maps.entries) {
      expect(keys.where((k) => (entry.value[k] ?? '').trim().isEmpty), isEmpty, reason: entry.key);
      if (entry.key != 'en') {
        // A real translation, not the English text copied over.
        expect(keys.where((k) => entry.value[k] == k), isEmpty, reason: entry.key);
      }
    }
  });
}
