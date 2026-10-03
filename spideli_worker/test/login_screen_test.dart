import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:spideliworker/controller/login_controller.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/login/login_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/utils/login_validation.dart';

/// The Login screen: field checks before any request, inline messages under
/// the fields, one "Invalid email or password." for any wrong credential, no
/// loader left up. Sign-in and the reset email are fakes (no Firebase).
void main() {
  late List<List<String>> signIns;
  late List<String> resets;
  late Future<dynamic> Function(String email, String password) signInResult;
  late Future<void> Function(String email) resetResult;

  setUp(() {
    signIns = [];
    resets = [];
    signInResult = (_, _) async => LoginValidation.invalidCredentials;
    resetResult = (_) async {};
  });

  tearDown(Get.reset);

  Future<LoginController> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final controller = Get.put(LoginController(
      signIn: (email, password) {
        signIns.add([email, password]);
        return signInResult(email, password);
      },
      sendResetEmail: (email) {
        resets.add(email);
        return resetResult(email);
      },
    ));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DarkThemeProvider(),
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: DsTheme.light(),
          builder: EasyLoading.init(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Finder emailField() => find.byType(TextFormField).at(0);
  Finder passwordField() => find.byType(TextFormField).at(1);
  Finder logIn() => find.byIcon(Icons.login_rounded);
  Finder inlineAlert(String message) => find.descendant(of: find.byType(DsInlineAlert), matching: find.text(message));

  /// A few frames: EasyLoading shows, dismisses and swaps its overlay one
  /// queued step per frame (well inside the toast's 2 s).
  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Lets the toast time out, so no timer is left pending.
  Future<void> settleToasts(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('both fields empty: inline messages, the combined toast, no request', (tester) async {
    await pumpLogin(tester);
    await tester.tap(logIn());
    await pumpUi(tester);

    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(find.text('Please enter your email and password.'), findsOneWidget, reason: 'toast');
    expect(signIns, isEmpty);
    expect(EasyLoading.isShow, isTrue, reason: 'the toast, not a loader');
    await settleToasts(tester);
    expect(EasyLoading.isShow, isFalse);
  });

  testWidgets('spaces only count as empty', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(emailField(), '   ');
    await tester.enterText(passwordField(), '  ');
    await tester.tap(logIn());
    await pumpUi(tester);

    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(signIns, isEmpty);
    await settleToasts(tester);
  });

  testWidgets('a malformed email: inline message, no request; typing clears it', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(emailField(), 'a b@c.com');
    await tester.enterText(passwordField(), 'secret1');
    await tester.tap(logIn());
    await pumpUi(tester);

    expect(find.text('Please enter a valid email address.'), findsNWidgets(2), reason: 'inline and toast');
    expect(find.text('Please enter your password.'), findsNothing);
    expect(signIns, isEmpty);
    await settleToasts(tester);
    expect(find.text('Please enter a valid email address.'), findsOneWidget);

    await tester.enterText(emailField(), 'a@b.co');
    await tester.pump();
    expect(find.text('Please enter a valid email address.'), findsNothing);
  });

  testWidgets('password empty only', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(emailField(), 'worker@example.com');
    await tester.tap(logIn());
    await pumpUi(tester);

    expect(find.text('Please enter your password.'), findsNWidgets(2), reason: 'inline and toast');
    expect(find.text('Please enter your email address.'), findsNothing);
    expect(signIns, isEmpty);
    await settleToasts(tester);
  });

  testWidgets('wrong credentials: one message, shown inline and as a toast, loader closed', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(emailField(), '  Worker@Example.com ');
    await tester.enterText(passwordField(), 'wrong');
    await tester.tap(logIn());
    await pumpUi(tester);

    expect(signIns, [
      ['worker@example.com', 'wrong'],
    ], reason: 'trimmed, lower-case email');
    expect(inlineAlert('Invalid email or password.'), findsOneWidget);
    expect(find.text('Invalid email or password.'), findsNWidgets(2), reason: 'inline and toast');
    expect(find.text('Logging in, please wait...'), findsNothing, reason: 'loader closed');
    await settleToasts(tester);
    expect(EasyLoading.isShow, isFalse);
    expect(inlineAlert('Invalid email or password.'), findsOneWidget, reason: 'stays until edited');

    await tester.enterText(passwordField(), 'wrong2');
    await tester.pump();
    expect(find.byType(DsInlineAlert), findsNothing);
  });

  testWidgets('an unexpected error shows the friendly message, never its text, and closes the loader', (tester) async {
    signInResult = (_, _) async => throw Exception('[firebase_auth/internal-error] An internal error has occurred.');
    await pumpLogin(tester);
    await tester.enterText(emailField(), 'worker@example.com');
    await tester.enterText(passwordField(), 'secret1');
    await tester.tap(logIn());
    await pumpUi(tester);

    expect(inlineAlert('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.textContaining('internal error'), findsNothing);
    expect(find.textContaining('firebase'), findsNothing);
    await settleToasts(tester);
    expect(EasyLoading.isShow, isFalse);
  });

  testWidgets('Forgot password: empty and malformed emails are stopped before the request', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();
    final Finder sendLink = find.text('Send Link');
    final Finder dialogEmail = find.byType(TextField).last;

    await tester.tap(sendLink);
    await pumpUi(tester);
    expect(find.text('Please enter your email address.'), findsNWidgets(2), reason: 'inline and toast');
    expect(resets, isEmpty);
    await settleToasts(tester);

    await tester.enterText(dialogEmail, '@x.com');
    await tester.pump();
    expect(find.text('Please enter your email address.'), findsNothing, reason: 'cleared while typing');
    await tester.tap(sendLink);
    await pumpUi(tester);
    expect(find.text('Please enter a valid email address.'), findsWidgets);
    expect(resets, isEmpty);
    await settleToasts(tester);

    await tester.enterText(dialogEmail, ' Worker@Example.com ');
    await tester.tap(sendLink);
    await pumpUi(tester);
    expect(resets, ['worker@example.com']);
    expect(find.text('Please check your email.'), findsOneWidget);
    expect(sendLink, findsNothing, reason: 'the dialog closed');
    await settleToasts(tester);
  });

  testWidgets('Forgot password: a failed request keeps the dialog open with a friendly message', (tester) async {
    resetResult = (_) async => throw Exception('socket closed');
    await pumpLogin(tester);
    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'worker@example.com');
    await tester.tap(find.text('Send Link'));
    await pumpUi(tester);

    expect(resets, ['worker@example.com']);
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.textContaining('socket'), findsNothing);
    expect(find.text('Send Link'), findsOneWidget, reason: 'still open');
    await settleToasts(tester);
    expect(EasyLoading.isShow, isFalse);
  });
}
