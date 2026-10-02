import 'package:bottom_picker/bottom_picker.dart';
import 'package:customer/main.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/widget/schedule_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Client video, 1 Oct: tapping "Booking Date & Slot" did nothing and Confirm
/// said "Please select time slot". The field mounted the way the app mounts it -
/// GetMaterialApp, the app's delegates, theme and outer wrapper, a read-only
/// DsTextField - including the French locales the client's phone uses.
void main() {
  Widget app({Locale locale = const Locale('en', 'US')}) {
    final controller = TextEditingController();
    return GetMaterialApp(
      locale: locale,
      fallbackLocale: const Locale('en', 'US'),
      localizationsDelegates: appLocalizationsDelegates,
      theme: DsTheme.light(),
      // The app's own outer wrapper (main.dart): brand theme, safe area and
      // the EasyLoading overlay, so nothing there can swallow the tap.
      builder: (context, child) => DsBrandTheme(child: SafeArea(bottom: true, top: false, child: EasyLoading.init()(context, child))),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: DsTextField(
              hint: 'Choose Date and Time',
              controller: controller,
              readOnly: true,
              onTap: () => showSchedulePicker(
                context: context,
                title: 'Booking Date & Slot',
                minDateTime: DateTime.now(),
                onPicked: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final locale in const [Locale('en', 'US'), Locale('fr'), Locale('fr', 'CM')]) {
    testWidgets('booking slot picker opens with locale $locale', (tester) async {
      await tester.pumpWidget(app(locale: locale));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DsTextField));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BottomPicker<DateTime>), findsOneWidget);
    });
  }
}
