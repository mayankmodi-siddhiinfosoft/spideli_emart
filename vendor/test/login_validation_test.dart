import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/lang/app_ar.dart';
import 'package:vendor/lang/app_de.dart';
import 'package:vendor/lang/app_en.dart';
import 'package:vendor/lang/app_fr.dart';
import 'package:vendor/lang/app_hi.dart';
import 'package:vendor/lang/app_ja.dart';
import 'package:vendor/lang/app_pt.dart';
import 'package:vendor/lang/app_ru.dart';
import 'package:vendor/lang/app_zh.dart';
import 'package:vendor/utils/login_validation.dart';

/// Login validation and error alerts (user request), owner and employee
/// login: checks before the sign-in request, one message for any wrong
/// credential, no Firebase text.
void main() {
  group('LoginValidation.validate (before any request)', () {
    test('empty fields', () {
      expect(LoginValidation.validate('', ''), 'Please enter your email and password.');
      expect(LoginValidation.validate('  ', ' '), 'Please enter your email and password.');
      expect(LoginValidation.validate('', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('store@example.com', ''), 'Please enter your password.');
    });

    test('email format', () {
      for (final email in ['store', 'store@', '@example.com', 'store@example', 'sto re@example.com', 'store@example.c']) {
        expect(LoginValidation.validate(email, 'secret1'), 'Please enter a valid email address.', reason: email);
      }
      expect(LoginValidation.validate('owner.one+x@example.co.in', 'secret1'), isNull);
    });
  });

  group('LoginValidation.authErrorMessage', () {
    test('a wrong email, a wrong password or both give one message that does not say which', () {
      for (final code in ['invalid-credential', 'INVALID_LOGIN_CREDENTIALS', 'invalid-login-credentials', 'wrong-password', 'user-not-found']) {
        expect(LoginValidation.authErrorMessage(code), 'Invalid email or password.', reason: code);
      }
    });

    test('every other code gets a friendly message', () {
      expect(LoginValidation.authErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.authErrorMessage('too-many-requests'), contains('Too many attempts'));
      expect(LoginValidation.authErrorMessage('network-request-failed'), contains('internet'));
      expect(LoginValidation.authErrorMessage('user-disabled'), 'This user is disable please contact to administrator');
      expect(LoginValidation.authErrorMessage('internal-error'), 'Something went wrong. Please try again.');
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
    ];
    final maps = {'en': enUS, 'ar': lnAr, 'de': deGR, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
    for (final entry in maps.entries) {
      expect(keys.where((k) => (entry.value[k] ?? '').trim().isEmpty), isEmpty, reason: entry.key);
    }
  });
}
