import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bug #13 — the chat keyboard covered the text field.
///
/// The composer lives in the Scaffold's `bottomNavigationBar` slot, which is
/// laid out at the bottom of the **screen**: `resizeToAvoidBottomInset` shrinks
/// the body only. `DsStickyBar(avoidKeyboard: true)` is what lifts it, and it
/// must apply the inset exactly once.
void main() {
  const double keyboard = 300;
  const Size screen = Size(400, 800);

  Widget host({required bool avoidKeyboard, double inset = keyboard}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: screen, viewInsets: EdgeInsets.only(bottom: inset)),
      child: DsScaffold(
        body: const SizedBox.expand(),
        bottomBar: DsStickyBar(
          avoidKeyboard: avoidKeyboard,
          child: const SizedBox(key: Key('composer'), height: 48),
        ),
      ),
    ),
  );

  testWidgets('without the flag the bar sits under the keyboard', (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(avoidKeyboard: false));
    await tester.pumpAndSettle();

    final Rect bar = tester.getRect(find.byKey(const Key('composer')));
    expect(bar.bottom, greaterThan(screen.height - keyboard));
  });

  testWidgets('with the flag the bar clears the keyboard, exactly once', (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(avoidKeyboard: true));
    await tester.pumpAndSettle();

    final Rect bar = tester.getRect(find.byKey(const Key('composer')));
    // Above the keyboard...
    expect(bar.bottom, lessThanOrEqualTo(screen.height - keyboard));
    // ...and not pushed up by two keyboards' worth of inset.
    expect(bar.bottom, greaterThan(screen.height - keyboard * 2));
  });

  testWidgets('with no keyboard the bar is laid out exactly as before', (tester) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(avoidKeyboard: false, inset: 0));
    await tester.pumpAndSettle();
    final Rect before = tester.getRect(find.byKey(const Key('composer')));

    await tester.pumpWidget(host(avoidKeyboard: true, inset: 0));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(const Key('composer'))), before);
  });
}
