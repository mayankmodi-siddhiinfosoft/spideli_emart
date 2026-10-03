import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/app/auth_screen/login_screen.dart';
import 'package:vendor/controller/login_controller.dart';
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

/// Login validation and error alerts (client request, 3 Oct 2026), owner and
/// employee login and forgot password: checks before the request, one
/// message for any wrong credential, no Firebase text.
void main() {
  group('LoginValidation.validate (before any request)', () {
    test('empty fields', () {
      expect(LoginValidation.validate('', ''), 'Please enter your email and password.');
      expect(LoginValidation.validate('', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('store@example.com', ''), 'Please enter your password.');
    });

    test('a field holding only spaces counts as empty', () {
      expect(LoginValidation.validate('  ', ' '), 'Please enter your email and password.');
      expect(LoginValidation.validate('\t \n', 'secret1'), 'Please enter your email address.');
      expect(LoginValidation.validate('store@example.com', '   '), 'Please enter your password.');
      expect(LoginValidation.validate('  store@example.com  ', 'secret1'), isNull, reason: 'the email is trimmed');
    });

    test('email format', () {
      for (final email in ['store', 'store@', '@example.com', '@x.com', 'a@b', 'a b@c.com', 'sto re@example.com', 'store@example', 'store@example.c']) {
        expect(LoginValidation.validate(email, 'secret1'), 'Please enter a valid email address.', reason: email);
        expect(LoginValidation.isValidEmail(email), isFalse, reason: email);
      }
      for (final email in ['a@b.co', 'user.name+tag@example.com', 'owner.one+x@example.co.in', 'STORE@Example.COM']) {
        expect(LoginValidation.validate(email, 'secret1'), isNull, reason: email);
        expect(LoginValidation.isValidEmail(email), isTrue, reason: email);
      }
    });

    test('a malformed email is reported before a missing password', () {
      expect(LoginValidation.validate('a@b', ''), 'Please enter a valid email address.');
    });
  });

  group('LoginValidation.fieldErrors (shown under each field)', () {
    test('each field gets its own message', () {
      expect(LoginValidation.fieldErrors('', ''), (email: 'Please enter your email address.', password: 'Please enter your password.'));
      expect(LoginValidation.fieldErrors(' ', 'secret1'), (email: 'Please enter your email address.', password: null));
      expect(LoginValidation.fieldErrors('a b@c.com', ' '), (email: 'Please enter a valid email address.', password: 'Please enter your password.'));
      expect(LoginValidation.fieldErrors('a@b.co', ''), (email: null, password: 'Please enter your password.'));
      expect(LoginValidation.fieldErrors('a@b.co', 'secret1'), (email: null, password: null));
    });

    test('no field error exactly when the request may be sent', () {
      for (final email in ['', ' ', 'a@b', 'a@b.co', 'user.name+tag@example.com']) {
        for (final password in ['', '  ', 'x', 'secret1']) {
          final errors = LoginValidation.fieldErrors(email, password);
          expect(errors.email == null && errors.password == null, LoginValidation.validate(email, password) == null, reason: '"$email" / "$password"');
        }
      }
    });
  });

  test('LoginValidation.validateEmail (forgot password)', () {
    expect(LoginValidation.validateEmail(''), 'Please enter your email address.');
    expect(LoginValidation.validateEmail('   '), 'Please enter your email address.');
    expect(LoginValidation.validateEmail('@x.com'), 'Please enter a valid email address.');
    expect(LoginValidation.validateEmail('a b@c.com'), 'Please enter a valid email address.');
    expect(LoginValidation.validateEmail(' a@b.co '), isNull);
  });

  group('LoginValidation.authErrorMessage', () {
    test('a wrong email, a wrong password or both give one message that does not say which', () {
      for (final code in ['invalid-credential', 'INVALID_LOGIN_CREDENTIALS', 'invalid-login-credentials', 'wrong-password', 'user-not-found', 'WRONG_PASSWORD']) {
        expect(LoginValidation.authErrorMessage(code), 'Invalid email or password.', reason: code);
      }
    });

    test('every other code gets a friendly message', () {
      expect(LoginValidation.authErrorMessage('invalid-email'), 'Please enter a valid email address.');
      expect(LoginValidation.authErrorMessage('too-many-requests'), 'Too many attempts. Please try again later.');
      expect(LoginValidation.authErrorMessage('network-request-failed'), 'No internet connection. Please check your connection and try again.');
      expect(LoginValidation.authErrorMessage('user-disabled'), 'This user is disable please contact to administrator');
      for (final code in ['internal-error', 'operation-not-allowed', 'unknown', '']) {
        expect(LoginValidation.authErrorMessage(code), 'Something went wrong. Please try again.', reason: code);
      }
    });
  });

  test('LoginValidation.resetErrorMessage (forgot password)', () {
    expect(LoginValidation.resetErrorMessage('user-not-found'), 'No user found for that email.');
    expect(LoginValidation.resetErrorMessage('invalid-email'), 'Please enter a valid email address.');
    expect(LoginValidation.resetErrorMessage('missing-email'), 'Please enter your email address.');
    expect(LoginValidation.resetErrorMessage('too-many-requests'), 'Too many attempts. Please try again later.');
    expect(LoginValidation.resetErrorMessage('network-request-failed'), 'No internet connection. Please check your connection and try again.');
    expect(LoginValidation.resetErrorMessage('user-disabled'), 'This user is disable please contact to administrator');
    expect(LoginValidation.resetErrorMessage('internal-error'), 'Something went wrong. Please try again.');
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
      LoginValidation.resetLinkSent,
      // The owner and employee "wrong app" messages of the login controller.
      'This user is not created in store application.',
      'This user is not created in restaurant application.',
    ];
    final maps = {'en': enUS, 'ar': lnAr, 'de': deGR, 'fr': trFR, 'hi': hiIN, 'ja': jaJP, 'pt': ptPO, 'ru': ruRU, 'zh': zhCH};
    for (final entry in maps.entries) {
      expect(keys.where((k) => (entry.value[k] ?? '').trim().isEmpty), isEmpty, reason: entry.key);
      expect(entry.value[LoginValidation.resetLinkSent], contains('@email'), reason: '${entry.key} keeps the placeholder');
      if (entry.key != 'en') {
        expect(keys.where((k) => k != LoginValidation.accountDisabled && entry.value[k] == k), isEmpty, reason: '${entry.key} is translated, not English');
      }
    }
  });

  group('login screen', () {
    Future<LoginController> pumpForm(WidgetTester tester, {required bool employee}) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = LoginController();
      await tester.pumpWidget(
        MaterialApp(
          builder: EasyLoading.init(),
          home: Scaffold(
            body: SingleChildScrollView(child: employee ? EmployeeLoginForm(controller: controller) : OwnerLoginForm(controller: controller)),
          ),
        ),
      );
      return controller;
    }

    Future<void> tapLogin(WidgetTester tester) async {
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> letToastClose(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
    }

    Finder inField(String text) => find.descendant(of: find.byType(TextField), matching: find.text(text));

    for (final employee in [false, true]) {
      final String who = employee ? 'employee' : 'owner';

      testWidgets('$who: both fields empty shows the messages and sends nothing', (tester) async {
        await pumpForm(tester, employee: employee);
        await tapLogin(tester);

        expect(inField('Please enter your email address.'), findsOneWidget);
        expect(inField('Please enter your password.'), findsOneWidget);
        expect(find.text('Please enter your email and password.'), findsOneWidget, reason: 'toast');
        // A request would have failed here (no Firebase in tests) and shown
        // the generic message: nothing was sent.
        expect(find.text('Something went wrong. Please try again.'), findsNothing);
        await letToastClose(tester);
      });

      testWidgets('$who: a malformed email is flagged under the email field, and editing clears it', (tester) async {
        final controller = await pumpForm(tester, employee: employee);
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'a b@c.com');
        await tester.enterText(fields.at(1), 'secret1');
        await tapLogin(tester);

        expect(inField('Please enter a valid email address.'), findsOneWidget);
        expect(inField('Please enter your password.'), findsNothing);
        expect(find.text('Something went wrong. Please try again.'), findsNothing);

        await tester.enterText(fields.at(0), 'ab@c.com');
        await tester.pump();
        expect(inField('Please enter a valid email address.'), findsNothing);
        final errors = employee ? controller.employeeErrors : controller.ownerErrors;
        expect(errors.email.value, isNull);
        await letToastClose(tester);
      });

      testWidgets('$who: a sign-in failure is shown above the button until a field is edited', (tester) async {
        final controller = await pumpForm(tester, employee: employee);
        final errors = employee ? controller.employeeErrors : controller.ownerErrors;
        errors.form.value = LoginValidation.invalidCredentials;
        await tester.pump();
        expect(find.text('Invalid email or password.'), findsOneWidget);

        await tester.enterText(find.byType(TextField).at(1), 'x');
        await tester.pump();
        expect(find.text('Invalid email or password.'), findsNothing);
      });
    }
  });

  test('LoginFormErrors', () {
    final errors = LoginFormErrors();
    errors.form.value = LoginValidation.invalidCredentials;
    errors.show(LoginValidation.fieldErrors('', ''));
    expect(errors.email.value, LoginValidation.emailRequired);
    expect(errors.password.value, LoginValidation.passwordRequired);
    expect(errors.form.value, isNull);
    errors.form.value = LoginValidation.invalidCredentials;
    errors.emailEdited();
    expect(errors.email.value, isNull);
    expect(errors.password.value, LoginValidation.passwordRequired);
    expect(errors.form.value, isNull);
    errors.passwordEdited();
    expect(errors.password.value, isNull);
  });
}
