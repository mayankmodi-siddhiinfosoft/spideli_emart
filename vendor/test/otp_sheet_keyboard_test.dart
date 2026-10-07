import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';

/// Store app: the delivery / pickup code field must stay above the keyboard.
void main() {
  testWidgets('code sheet field stays above the keyboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(GetMaterialApp(
      theme: DsTheme.light(),
      builder: (context, child) => DsBrandTheme(child: SafeArea(bottom: true, top: false, child: EasyLoading.init()(context, child))),
      home: const Scaffold(body: Center(child: Text('home'))),
    ));
    Get.bottomSheet(
      DsSheet(
        title: 'Enter the pickup code',
        showClose: true,
        actions: DsButton.primary(label: 'Verify', expand: true, onPressed: () {}),
        child: const TextField(key: Key('code'), autofocus: true, keyboardType: TextInputType.number),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    await tester.pumpAndSettle();

    // Keyboard up: 300 logical px.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();

    final double screenH = 2340 / 3.0;
    final Rect field = tester.getRect(find.byKey(const Key('code')));
    final Rect button = tester.getRect(find.text('Verify'));
    // Above the keyboard, and sitting on it (not lifted by twice its height).
    expect(field.bottom, lessThanOrEqualTo(screenH - 300));
    expect(button.bottom, lessThanOrEqualTo(screenH - 300));
    expect(button.bottom, greaterThan(screenH - 300 - 80));
  });
}
