import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/forgot_password_screen/forgot_password_screen.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Client requirement (3 Oct): "Improve Login Validation & Error Alerts".
/// The Login screen checks the fields before any request, shows each message
/// under its field (cleared as the user types) and in the usual toast, and
/// never leaves the loader up or shows technical text.
///
/// Firebase is not started here, so a sign-in request that is sent fails;
/// the validation cases show none was sent.
void main() {
  tearDown(Get.reset);

  Future<void> pumpLogin(WidgetTester tester, {Widget home = const LoginScreen()}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: DsTheme.light(),
      builder: EasyLoading.init(),
      home: home,
    ));
    await tester.pump();
  }

  Finder field(int index) => find.byType(TextFormField).at(index);

  Future<void> tapLogIn(WidgetTester tester) async {
    await tester.tap(find.text('Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The loader's show / dismiss animations, well within the toast's 2 s.
  Future<void> overlaysSettle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Lets the last toast time out, so no timer is left pending.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('both fields empty: a message under each field and the combined toast', (tester) async {
    await pumpLogin(tester);
    await tapLogIn(tester);

    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(find.text('Please enter your email and password.'), findsOneWidget);
    expect(find.text('Something went wrong. Please try again.'), findsNothing, reason: 'no request was sent');
    expect(find.text('Please wait'), findsNothing);

    // Typing in a field clears its own message only.
    await tester.enterText(field(0), 'driver@example.com');
    await tester.pump();
    expect(find.text('Please enter your email address.'), findsNothing);
    expect(find.text('Please enter your password.'), findsOneWidget);

    await tester.enterText(field(1), 'secret1');
    await tester.pump();
    expect(find.text('Please enter your password.'), findsNothing);
    await finish(tester);
  });

  testWidgets('whitespace only counts as empty', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(field(0), '   ');
    await tester.enterText(field(1), '   ');
    await tapLogIn(tester);
    expect(find.text('Please enter your email and password.'), findsOneWidget);
    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('email empty / password empty / email malformed', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(field(1), 'secret1');
    await tapLogIn(tester);
    expect(find.text('Please enter your email address.'), findsNWidgets(2), reason: 'under the field and in the toast');
    expect(find.text('Please enter your password.'), findsNothing);

    await tester.enterText(field(0), 'a b@c.com');
    await tapLogIn(tester);
    expect(find.text('Please enter a valid email address.'), findsNWidgets(2));
    expect(find.text('Please enter your email address.'), findsNothing);

    await tester.enterText(field(0), 'driver@example.com');
    await tester.enterText(field(1), '');
    await tapLogIn(tester);
    expect(find.text('Please enter your password.'), findsNWidgets(2));
    expect(find.text('Please enter a valid email address.'), findsNothing);
    expect(find.text('Something went wrong. Please try again.'), findsNothing, reason: 'no request was sent');
    await finish(tester);
  });

  testWidgets('a failed request shows a friendly message, never technical text, and closes the loader', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(field(0), 'driver@example.com');
    await tester.enterText(field(1), 'secret1');
    await tapLogIn(tester);
    await overlaysSettle(tester);

    expect(find.text('Please wait'), findsNothing, reason: 'the loader is closed');
    // Firebase is not started, so the request fails: under the form and in
    // the toast, as the app's generic message.
    expect(find.text('Something went wrong. Please try again.'), findsNWidgets(2));
    expect(find.textContaining('core/'), findsNothing);
    expect(find.textContaining('Firebase'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);

    // Editing a field removes the alert under the form.
    await tester.enterText(field(1), 'secret12');
    await tester.pump();
    await finish(tester);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });

  group('Forgot password', () {
    Future<void> send(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(DsButton, 'Forgot Password'));
      await tester.pump();
      await overlaysSettle(tester);
    }

    testWidgets('an empty or malformed address is shown under the field and not sent', (tester) async {
      await pumpLogin(tester, home: const ForgotPasswordScreen());

      await tester.enterText(field(0), '   ');
      await send(tester);
      expect(find.text('Please enter your email address.'), findsNWidgets(2));

      await tester.enterText(field(0), '@x.com');
      await tester.pump();
      expect(find.text('Please enter your email address.'), findsOneWidget, reason: 'only the toast is left');
      await send(tester);
      expect(find.text('Please enter a valid email address.'), findsNWidgets(2));
      expect(find.text('Something went wrong. Please try again.'), findsNothing, reason: 'no request was sent');
      await finish(tester);
    });

    testWidgets('a failed request closes the loader and shows a friendly message', (tester) async {
      await pumpLogin(tester, home: const ForgotPasswordScreen());
      await tester.enterText(field(0), ' driver@example.com ');
      await send(tester);
      expect(find.text('Please wait'), findsNothing);
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.textContaining('core/'), findsNothing);
      await finish(tester);
    });
  });
}
