import 'package:customer/screen_ui/multi_vendor_service/home_screen/widgets/store_widgets.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Report #15, screenshot (b): ONE floating capsule over the multivendor home
/// holding — left to right — the list / map toggle, the search field (taking
/// the remaining width) and the QR scan action.
void main() {
  const String hint = 'Search the store, item and more...';

  Widget host({
    required ThemeData theme,
    double textScale = 1.0,
    bool isListView = true,
    VoidCallback? onSearch,
    VoidCallback? onList,
    VoidCallback? onMap,
    VoidCallback? onScan,
  }) => MaterialApp(
    theme: theme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  children: [
                    for (int i = 0; i < 30; i++) SizedBox(key: ValueKey('store-$i'), height: 60, child: Text('Store $i')),
                    const SizedBox(height: HomeSearchToolBar.reservedHeight),
                  ],
                ),
              ),
              Builder(
                builder: (context) => HomeSearchToolBar.overlay(
                  context,
                  HomeSearchToolBar(
                    hint: hint,
                    isListView: isListView,
                    onSearch: onSearch ?? () {},
                    onList: onList ?? () {},
                    onMap: onMap ?? () {},
                    onScan: onScan ?? () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Rect rectOf(WidgetTester tester, String label) => tester.getRect(find.bySemanticsLabel(label));

  testWidgets('toggle, then search, then scan — in one capsule', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(theme: DsTheme.light()));
    await tester.pumpAndSettle();

    final capsule = tester.getRect(find.byType(HomeSearchToolBar));
    final list = rectOf(tester, 'List view');
    final map = rectOf(tester, 'Map view');
    final search = rectOf(tester, hint);
    final scan = rectOf(tester, 'Scan QR Code');

    for (final r in [list, map, search, scan]) {
      expect(capsule.contains(r.center), isTrue);
    }
    expect(list.right, lessThanOrEqualTo(map.left + 0.5));
    expect(map.right, lessThan(search.left));
    expect(search.right, lessThan(scan.left));
    // The search field takes the remaining width.
    expect(search.width, greaterThan(capsule.width / 2));
    // Floating: inset from both edges and from the bottom, not a full-width bar.
    expect(capsule.left, greaterThan(0));
    expect(capsule.right, lessThan(375));
    expect(capsule.bottom, lessThan(812));
    expect(capsule.height, HomeSearchToolBar.height);
  });

  testWidgets('every handler is wired to its own control', (tester) async {
    phone(tester);
    final taps = <String>[];
    await tester.pumpWidget(
      host(
        theme: DsTheme.light(),
        onSearch: () => taps.add('search'),
        onList: () => taps.add('list'),
        onMap: () => taps.add('map'),
        onScan: () => taps.add('scan'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('List view'));
    await tester.tap(find.bySemanticsLabel('Map view'));
    await tester.tap(find.bySemanticsLabel(hint));
    await tester.tap(find.bySemanticsLabel('Scan QR Code'));
    expect(taps, ['list', 'map', 'search', 'scan']);
  });

  testWidgets('the last list item can scroll clear of the capsule', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(theme: DsTheme.light()));
    await tester.pumpAndSettle();

    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    // A lazy list only learns its true extent once the end is laid out.
    for (int i = 0; i < 3; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
    }

    final last = tester.getRect(find.byKey(const ValueKey('store-29')));
    final capsule = tester.getRect(find.byType(HomeSearchToolBar));
    expect(last.bottom, lessThanOrEqualTo(capsule.top));
  });

  for (final (name, theme) in [('light', DsTheme.light()), ('dark', DsTheme.dark())]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('lays out without overflow — $name, ${scale}x text, phone width', (tester) async {
        phone(tester);
        await tester.pumpWidget(host(theme: theme, textScale: scale, isListView: false));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.byType(HomeSearchToolBar)).height, HomeSearchToolBar.height);
      });
    }
  }
}
