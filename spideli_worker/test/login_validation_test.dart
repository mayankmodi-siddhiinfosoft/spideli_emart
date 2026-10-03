import 'package:flutter_test/flutter_test.dart';
import 'package:spideliworker/lang/app_ar.dart';
import 'package:spideliworker/lang/app_en.dart';
import 'package:spideliworker/utils/login_validation.dart';

/// Login validation and error alerts (user request): checks before the
/// sign-in request, one message for any wrong credential, no Firebase text.
void main() {
  const allMessages = [
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

  group('LoginValidation.validate (before any request)', () {
    test('the client wording', () {
      expect(LoginValidation.emailAndPasswordRequired, 'Please enter your email and password.');
      expect(LoginValidation.emailRequired, 'Please enter your email address.');
      expect(LoginValidation.passwordRequired, 'Please enter your password.');
      expect(LoginValidation.emailInvalid, 'Please enter a valid email address.');
      expect(LoginValidation.invalidCredentials, 'Invalid email or password.');
    });

    test('both empty gives the one combined message', () {
      expect(LoginValidation.validate('', ''), 'Please enter your email and password.');
    });

    test('email empty', () {
      expect(LoginValidation.validate('', 'secret1'), 'Please enter your email address.');
    });

    test('password empty', () {
      expect(LoginValidation.validate('worker@example.com', ''), 'Please enter your password.');
    });

    test('spaces alone count as empty', () {
      expect(LoginValidation.validate('  ', ' '), 'Please enter your email and password.');
      expect(LoginValidation.validate(' \t ', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('worker@example.com', '   '), 'Please enter your password.');
    });

    test('the email is trimmed before the format check', () {
      expect(LoginValidation.validate('  a@b.co  ', 'secret1'), isNull);
    });

    test('a malformed email is reported before an empty password', () {
      expect(LoginValidation.validate('a@b', ''), 'Please enter a valid email address.');
    });

    test('email format', () {
      for (final email in ['a@b', 'a b@c.com', '@x.com', 'worker', 'worker@', 'worker@example', 'worker@example.c', 'a@@b.co']) {
        expect(LoginValidation.validate(email, 'secret1'), 'Please enter a valid email address.', reason: email);
        expect(LoginValidation.isValidEmail(email), isFalse, reason: email);
      }
      for (final email in ['a@b.co', 'user.name+tag@example.com', 'worker.one+x@example.co.in', 'Worker@Example.COM']) {
        expect(LoginValidation.validate(email, 'secret1'), isNull, reason: email);
        expect(LoginValidation.isValidEmail(email), isTrue, reason: email);
      }
    });

    test('a filled, well-formed form may be sent', () {
      expect(LoginValidation.validate('worker@example.com', 'secret1'), isNull);
    });
  });

  group('inline field messages', () {
    test('emailError', () {
      expect(LoginValidation.emailError(''), 'Please enter your email address.');
      expect(LoginValidation.emailError('   '), 'Please enter your email address.');
      expect(LoginValidation.emailError('a b@c.com'), 'Please enter a valid email address.');
      expect(LoginValidation.emailError(' a@b.co '), isNull);
    });

    test('passwordError', () {
      expect(LoginValidation.passwordError(''), 'Please enter your password.');
      expect(LoginValidation.passwordError('  '), 'Please enter your password.');
      expect(LoginValidation.passwordError(' secret '), isNull);
    });
  });

  group('LoginValidation.authErrorMessage', () {
    test('a wrong email, a wrong password or both give one message that does not say which', () {
      for (final code in [
        'invalid-credential',
        'INVALID_LOGIN_CREDENTIALS',
        'invalid-login-credentials',
        'wrong-password',
        'user-not-found',
        'WRONG_PASSWORD',
        ' invalid-credential ',
      ]) {
        expect(LoginValidation.authErrorMessage(code), 'Invalid email or password.', reason: code);
      }
    });

    test('every other code gets a friendly message, never "Unexpected firebase error"', () {
      expect(LoginValidation.authErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.authErrorMessage('too-many-requests'), 'Too many attempts. Please try again later.');
      expect(LoginValidation.authErrorMessage('network-request-failed'), 'No internet connection. Please check your connection and try again.');
      expect(LoginValidation.authErrorMessage('unavailable'), LoginValidation.noConnection, reason: 'Firestore offline');
      expect(LoginValidation.authErrorMessage('user-disabled'), LoginValidation.accountDisabled);
      expect(LoginValidation.authErrorMessage('internal-error'), 'Something went wrong. Please try again.');
      expect(LoginValidation.authErrorMessage(''), 'Something went wrong. Please try again.');
    });

    test('never returns the code or any text outside the known messages', () {
      for (final code in ['operation-not-allowed', 'permission-denied', 'unknown', 'channel-error', 'app-not-authorized', 'internal-error', 'invalid-api-key']) {
        final String message = LoginValidation.authErrorMessage(code);
        expect(allMessages, contains(message), reason: code);
        expect(message, isNot(contains(code)), reason: code);
      }
    });
  });

  group('LoginValidation.passwordResetErrorMessage (Forgot password)', () {
    test('an unknown account is reported as sent, so the form does not reveal it', () {
      expect(LoginValidation.passwordResetErrorMessage('user-not-found'), isNull);
      expect(LoginValidation.passwordResetErrorMessage('USER_NOT_FOUND'), isNull);
    });

    test('other failures give friendly messages', () {
      expect(LoginValidation.passwordResetErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.passwordResetErrorMessage('missing-email'), 'Please enter your email address.');
      expect(LoginValidation.passwordResetErrorMessage('network-request-failed'), LoginValidation.noConnection);
      expect(LoginValidation.passwordResetErrorMessage('too-many-requests'), LoginValidation.tooManyAttempts);
      expect(LoginValidation.passwordResetErrorMessage('internal-error'), LoginValidation.genericError);
    });
  });

  test('every login message is in every language map', () {
    for (final entry in {'en': enUS, 'ar': lnAr}.entries) {
      expect(allMessages.where((k) => (entry.value[k] ?? '').trim().isEmpty), isEmpty, reason: entry.key);
    }
    // Arabic is translated, not copied.
    expect(allMessages.where((k) => lnAr[k] == k), isEmpty);
  });
}
