import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/login/login_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';

/// Login screen (user request "Improve Login Validation & Error Alerts").
///
/// Firebase is not initialised in tests, so any sign-in or reset request
/// that is sent fails: "Something went wrong" proves a request was made and
/// its absence proves validation stopped it before the request.
void main() {
  Widget host() => ChangeNotifierProvider(
        create: (_) => DarkThemeProvider(),
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: DsTheme.light(),
          builder: EasyLoading.init(),
          home: const LoginScreen(),
        ),
      );

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(Get.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  Finder field(int i) => find.byType(TextField).at(i);

  /// EasyLoading runs its overlays one after another (loader in, loader
  /// out, then the toast), each animated: a few frames bring the toast up.
  Future<void> pumpOverlay(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapLogin(WidgetTester tester) async {
    await tester.tap(find.text('Login'));
    await tester.pump();
    await pumpOverlay(tester);
  }

  /// Lets the toast time out so no timer is left pending.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  const both = 'Please enter your email and password.';
  const emailRequired = 'Please enter your email address.';
  const passwordRequired = 'Please enter your password.';
  const emailInvalid = 'Please enter a valid email address.';
  const generic = 'Something went wrong. Please try again.';

  testWidgets('both empty: a message under each field and the summary toast, no request', (tester) async {
    await pumpLogin(tester);
    await tapLogin(tester);

    expect(find.text(both), findsOneWidget, reason: 'toast');
    expect(find.text(emailRequired), findsOneWidget, reason: 'under the email field');
    expect(find.text(passwordRequired), findsOneWidget, reason: 'under the password field');
    expect(find.text(generic), findsNothing, reason: 'no sign-in request');
    expect(find.text('Logging in, please wait...'), findsNothing);

    // Typing clears that field's message only.
    await tester.enterText(field(0), 'p');
    await tester.pump();
    expect(find.text(emailRequired), findsNothing);
    expect(find.text(passwordRequired), findsOneWidget);
    await tester.enterText(field(1), 'x');
    await tester.pump();
    expect(find.text(passwordRequired), findsNothing);
    await finish(tester);
  });

  testWidgets('whitespace only, a single empty field, an invalid email: no request', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(field(0), '   ');
    await tester.enterText(field(1), '   ');
    await tapLogin(tester);
    expect(find.text(both), findsOneWidget);

    await tester.enterText(field(0), 'provider@example.com');
    await tester.enterText(field(1), '');
    await tapLogin(tester);
    expect(find.text(passwordRequired), findsNWidgets(2), reason: 'under the field and as the toast');
    expect(find.text(emailRequired), findsNothing);

    await tester.enterText(field(0), '');
    await tester.enterText(field(1), 'secret1');
    await tapLogin(tester);
    expect(find.text(emailRequired), findsNWidgets(2));

    for (final email in ['a@b', 'a b@c.com', '@x.com']) {
      await tester.enterText(field(0), email);
      await tapLogin(tester);
      expect(find.text(emailInvalid), findsNWidgets(2), reason: email);
    }
    expect(find.text(generic), findsNothing, reason: 'no sign-in request');
    await finish(tester);
  });

  testWidgets('a valid form is sent; a failure shows a friendly message and no loader', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(field(0), '  Provider@Example.com ');
    await tester.enterText(field(1), 'secret1');
    await tapLogin(tester);

    // Toast and the alert above the Login button; never Firebase's text.
    expect(find.text(generic), findsNWidgets(2));
    expect(find.byType(DsInlineAlert), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);
    expect(find.textContaining('no-app'), findsNothing);
    expect(find.text('Logging in, please wait...'), findsNothing, reason: 'the loader is closed');

    // Editing a field clears the alert.
    await tester.enterText(field(1), 'secret2');
    await tester.pump();
    expect(find.byType(DsInlineAlert), findsNothing);
    await finish(tester);
  });

  testWidgets('Forgot password: same email checks before any request', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();
    expect(find.text('Send Link'), findsOneWidget);
    final Finder resetField = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));

    await tester.tap(find.text('Send Link'));
    await tester.pump();
    expect(find.descendant(of: find.byType(Dialog), matching: find.text(emailRequired)), findsOneWidget);

    await tester.enterText(resetField, '   ');
    await tester.tap(find.text('Send Link'));
    await tester.pump();
    expect(find.descendant(of: find.byType(Dialog), matching: find.text(emailRequired)), findsOneWidget);

    await tester.enterText(resetField, 'a b@c.com');
    await tester.pump();
    expect(find.descendant(of: find.byType(Dialog), matching: find.text(emailRequired)), findsNothing, reason: 'cleared while typing');
    await tester.tap(find.text('Send Link'));
    await tester.pump();
    expect(find.descendant(of: find.byType(Dialog), matching: find.text(emailInvalid)), findsOneWidget);
    expect(find.text(generic), findsNothing, reason: 'no reset request');

    // A valid email is sent; the failure is friendly and the loader closes.
    await tester.enterText(resetField, 'a@b.co');
    await tester.tap(find.text('Send Link'));
    await tester.pump();
    await pumpOverlay(tester);
    expect(find.text(generic), findsOneWidget);
    expect(find.text('Sending Email...'), findsNothing);
    expect(find.textContaining('Firebase'), findsNothing);
    await finish(tester);
  });
}
