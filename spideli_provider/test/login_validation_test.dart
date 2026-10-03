import 'package:flutter_test/flutter_test.dart';
import 'package:spideliprovider/lang/app_ar.dart';
import 'package:spideliprovider/lang/app_en.dart';
import 'package:spideliprovider/utils/login_validation.dart';

/// Login validation and error alerts (user request): checks before the
/// sign-in request, one message for any wrong credential, no Firebase text.
void main() {
  group('LoginValidation.validate (before any request)', () {
    test('empty fields', () {
      expect(LoginValidation.validate('', ''), 'Please enter your email and password.');
      expect(LoginValidation.validate('', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('provider@example.com', ''), 'Please enter your password.');
    });

    test('whitespace only counts as empty', () {
      expect(LoginValidation.validate('  ', ' '), 'Please enter your email and password.');
      expect(LoginValidation.validate('\t\n', '   '), 'Please enter your email and password.');
      expect(LoginValidation.validate('   ', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('provider@example.com', '  \t'), 'Please enter your password.');
    });

    test('email format', () {
      for (final email in ['a@b', 'a b@c.com', '@x.com', 'provider', 'provider@', 'provider@example', 'provider x@example.com', 'provider@example.c', 'a@@b.co', 'a@b..co']) {
        expect(LoginValidation.validate(email, 'secret1'), 'Please enter a valid email address.', reason: email);
      }
      for (final email in ['a@b.co', 'user.name+tag@example.com', 'provider.one+x@example.co.in', 'UPPER@Example.COM', '  padded@example.com  ']) {
        expect(LoginValidation.validate(email, 'secret1'), isNull, reason: email);
      }
    });

    test('an invalid email is reported before an empty password', () {
      expect(LoginValidation.validate('a@b', ''), 'Please enter a valid email address.');
    });
  });

  group('LoginValidation.fieldErrors (messages under each field)', () {
    test('both empty: one message under each field', () {
      final e = LoginValidation.fieldErrors(' ', '');
      expect(e.email, 'Please enter your email address.');
      expect(e.password, 'Please enter your password.');
    });

    test('only the offending field gets a message', () {
      expect(LoginValidation.fieldErrors('', 'secret1'), (email: 'Please enter your email address.', password: null));
      expect(LoginValidation.fieldErrors('a@b.co', ' '), (email: null, password: 'Please enter your password.'));
      expect(LoginValidation.fieldErrors('a b@c.com', 'secret1'), (email: 'Please enter a valid email address.', password: null));
      expect(LoginValidation.fieldErrors('a@b.co', 'secret1'), (email: null, password: null));
    });

    test('no field message exactly when validate lets the request through', () {
      const emails = ['', ' ', 'a@b', 'a b@c.com', '@x.com', 'a@b.co', 'user.name+tag@example.com'];
      const passwords = ['', '  ', 'x', 'secret1'];
      for (final email in emails) {
        for (final password in passwords) {
          final e = LoginValidation.fieldErrors(email, password);
          expect(e.email == null && e.password == null, LoginValidation.validate(email, password) == null, reason: '"$email" / "$password"');
        }
      }
    });
  });

  test('LoginValidation.validateEmail (Forgot password field)', () {
    expect(LoginValidation.validateEmail(''), 'Please enter your email address.');
    expect(LoginValidation.validateEmail('   '), 'Please enter your email address.');
    expect(LoginValidation.validateEmail('a@b'), 'Please enter a valid email address.');
    expect(LoginValidation.validateEmail('a b@c.com'), 'Please enter a valid email address.');
    expect(LoginValidation.validateEmail('@x.com'), 'Please enter a valid email address.');
    expect(LoginValidation.validateEmail('a@b.co'), isNull);
    expect(LoginValidation.validateEmail(' user.name+tag@example.com '), isNull);
  });

  group('LoginValidation.authErrorMessage', () {
    test('a wrong email, a wrong password or both give one message that does not say which', () {
      for (final code in ['invalid-credential', 'INVALID_LOGIN_CREDENTIALS', 'invalid-login-credentials', 'wrong-password', 'user-not-found', 'auth/invalid-credential', 'ERROR_WRONG_PASSWORD', 'ERROR_USER_NOT_FOUND']) {
        expect(LoginValidation.authErrorMessage(code), 'Invalid email or password.', reason: code);
      }
    });

    test('older Android builds: INVALID_LOGIN_CREDENTIALS inside an unknown error', () {
      expect(LoginValidation.authErrorMessage('unknown', 'An internal error has occurred. [ INVALID_LOGIN_CREDENTIALS ]'), 'Invalid email or password.');
      expect(LoginValidation.authErrorMessage('internal-error', '{"error":{"message":"INVALID_LOGIN_CREDENTIALS"}}'), 'Invalid email or password.');
      expect(LoginValidation.authErrorMessage('unknown', 'An internal error has occurred.'), 'Something went wrong. Please try again.');
    });

    test('every other code gets a friendly message, never "Unexpected firebase error"', () {
      expect(LoginValidation.authErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.authErrorMessage('too-many-requests'), 'Too many attempts. Please try again later.');
      expect(LoginValidation.authErrorMessage('network-request-failed'), 'No internet connection. Please check your connection and try again.');
      expect(LoginValidation.authErrorMessage('auth/network-request-failed'), LoginValidation.noConnection);
      expect(LoginValidation.authErrorMessage('unavailable'), LoginValidation.noConnection, reason: 'Firestore offline while reading the profile');
      expect(LoginValidation.authErrorMessage('user-disabled'), LoginValidation.accountDisabled);
      for (final code in ['internal-error', 'operation-not-allowed', 'no-app', 'permission-denied', 'channel-error', '', 'something-new']) {
        expect(LoginValidation.authErrorMessage(code), 'Something went wrong. Please try again.', reason: code);
      }
    });

    test('the technical detail is never part of the message', () {
      const detail = 'A network error (such as timeout, interrupted connection or unreachable host) has occurred.';
      expect(LoginValidation.authErrorMessage('network-request-failed', detail), isNot(contains('timeout')));
      expect(LoginValidation.authErrorMessage('weird', 'PlatformException(xyz)'), LoginValidation.genericError);
    });
  });

  test('LoginValidation.passwordResetErrorMessage', () {
    // An email without an account gets the same answer as one with an
    // account (null = "Please check your email.").
    expect(LoginValidation.passwordResetErrorMessage('user-not-found'), isNull);
    expect(LoginValidation.passwordResetErrorMessage('ERROR_USER_NOT_FOUND'), isNull);
    expect(LoginValidation.passwordResetErrorMessage('invalid-email'), LoginValidation.emailInvalid);
    expect(LoginValidation.passwordResetErrorMessage('missing-email'), LoginValidation.emailRequired);
    expect(LoginValidation.passwordResetErrorMessage('too-many-requests'), LoginValidation.tooManyAttempts);
    expect(LoginValidation.passwordResetErrorMessage('network-request-failed'), LoginValidation.noConnection);
    expect(LoginValidation.passwordResetErrorMessage('invalid-credential'), LoginValidation.genericError);
    expect(LoginValidation.passwordResetErrorMessage('internal-error'), LoginValidation.genericError);
  });

  test('every login message is in every language map', () {
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
      'Please check your email.',
    ];
    expect(keys.where((k) => (enUS[k] ?? '').trim().isEmpty), isEmpty);
    expect(keys.where((k) => (lnAr[k] ?? '').trim().isEmpty), isEmpty);
    for (final k in keys) {
      expect(enUS[k], k, reason: 'English shows the message as written');
      expect(lnAr[k], isNot(k), reason: 'Arabic is translated: $k');
    }
  });
}
