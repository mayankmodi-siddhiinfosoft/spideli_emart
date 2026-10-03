import 'package:customer/controllers/login_controller.dart';
import 'package:customer/screen_ui/auth_screens/login_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/login_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// The login screen shows the validation message under the offending field
/// and never starts the sign-in request (Firebase is not initialised here, so
/// a request would end in the generic error and leave the loader up).
void main() {
  Widget host() => GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: DsTheme.light(),
    builder: EasyLoading.init(),
    home: const LoginScreen(),
  );

  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> tapLogIn(WidgetTester tester) async {
    final button = find.widgetWithText(DsButton, 'Log in');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Lets the toast time out so no timer is left pending.
  Future<void> settleToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  }

  // A message shown under the [index]th field (0 = email, 1 = password).
  Finder under(int index, String text) => find.descendant(of: find.byType(TextFormField).at(index), matching: find.text(text));

  tearDown(Get.reset);

  testWidgets('both fields empty: a message under each field, no request', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tapLogIn(tester);

    expect(under(0, LoginValidation.emailRequired), findsOneWidget);
    expect(under(1, LoginValidation.passwordRequired), findsOneWidget);
    expect(find.text(LoginValidation.emailAndPasswordRequired), findsOneWidget); // toast
    expect(find.text(LoginValidation.genericError), findsNothing);
    expect(Get.find<LoginController>().isLoading.value, isFalse);
    expect(EasyLoading.isShow, isTrue); // the toast, not a loader
    await settleToast(tester);
  });

  testWidgets('invalid email: message under the email field, cleared on edit', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'a b@c.com');
    await tester.enterText(fields.at(1), 'secret1');
    await tapLogIn(tester);

    // Under the field and in the toast.
    expect(under(0, LoginValidation.emailInvalid), findsOneWidget);
    expect(find.text(LoginValidation.emailInvalid), findsNWidgets(2));
    expect(find.text(LoginValidation.passwordRequired), findsNothing);
    expect(find.text(LoginValidation.genericError), findsNothing);
    final controller = Get.find<LoginController>();
    expect(controller.emailError.value, LoginValidation.emailInvalid);
    expect(controller.isLoading.value, isFalse);
    await settleToast(tester);

    await tester.enterText(fields.at(0), 'a b@c.co');
    await tester.pump();
    expect(controller.emailError.value, isNull);
    expect(under(0, LoginValidation.emailInvalid), findsNothing);
  });

  testWidgets('password empty: message under the password field only', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '  user@example.com ');
    await tapLogIn(tester);

    final controller = Get.find<LoginController>();
    expect(controller.emailError.value, isNull);
    expect(controller.passwordError.value, LoginValidation.passwordRequired);
    expect(under(1, LoginValidation.passwordRequired), findsOneWidget);
    expect(under(0, LoginValidation.emailRequired), findsNothing);
    expect(find.text(LoginValidation.genericError), findsNothing);
    await settleToast(tester);
  });
}
