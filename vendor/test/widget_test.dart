import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/ds/ds.dart';

/// Store (vendor) app smoke test.
///
/// `MyApp` starts Firebase and Firestore listeners, so it is not pumped here.
/// Instead this checks the design system every store screen is built on:
/// the light / dark themes, the status mapping, and a dashboard-style DS
/// screen (KPI tiles, order tabs, settings tiles) that renders and responds
/// to taps, all without Firebase or network.
void main() {
  Widget host(Widget home, {bool dark = false}) => GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: DsTheme.light(),
    darkTheme: DsTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: home,
  );

  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('DsTheme', () {
    test('light and dark themes are built from the DS tokens', () {
      final light = DsTheme.light();
      expect(light.useMaterial3, isTrue);
      expect(light.brightness, Brightness.light);
      expect(light.colorScheme.primary, DsColors.light.brand);
      expect(light.scaffoldBackgroundColor, DsColors.light.background);

      final dark = DsTheme.dark();
      expect(dark.brightness, Brightness.dark);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, DsColors.dark.background);
      expect(dark.scaffoldBackgroundColor, isNot(light.scaffoldBackgroundColor));
    });

    test('follows the brand color loaded at runtime', () {
      final original = AppThemeData.primary300;
      addTearDown(() => AppThemeData.primary300 = original);

      AppThemeData.primary300 = const Color(0xFF7B1FA2);
      expect(DsTheme.light().colorScheme.primary, const Color(0xFF7B1FA2));
      expect(DsTheme.light().colorScheme.onPrimary, Colors.white, reason: 'dark brand gets light text');

      AppThemeData.primary300 = const Color(0xFFFFEB3B);
      expect(DsTheme.light().colorScheme.onPrimary, isNot(Colors.white), reason: 'light brand gets dark text');
    });
  });

  test('DsTone.fromStatus maps store order statuses to tones', () {
    expect(DsTone.fromStatus(null), DsTone.neutral);
    expect(DsTone.fromStatus(''), DsTone.neutral);
    expect(DsTone.fromStatus('Order Placed'), DsTone.brand);
    expect(DsTone.fromStatus('Order Accepted'), DsTone.success);
    expect(DsTone.fromStatus('Order Completed'), DsTone.success);
    expect(DsTone.fromStatus('restaurant_rejected'), DsTone.danger);
    expect(DsTone.fromStatus('pending'), DsTone.warning);
    expect(DsTone.fromStatus('In Transit'), DsTone.info);
    // Dispatch states: waiting for a driver, never shown as rejected.
    expect(DsTone.fromStatus('Driver Pending'), DsTone.warning);
    expect(DsTone.fromStatus('Driver Rejected'), DsTone.warning);
    expect(DsTone.fromStatus('Driver Accepted'), DsTone.success);
    expect(DsTone.fromStatus('Order Shipped'), DsTone.info);
    expect(DsTone.fromStatus('Order Rejected'), DsTone.danger);
  });

  test('DsLayout.fromWidth picks the breakpoint', () {
    expect(DsLayout.fromWidth(const Size(390, 844)).breakpoint, DsBreakpoint.phone);
    expect(DsLayout.fromWidth(const Size(820, 1180)).breakpoint, DsBreakpoint.tablet);
    expect(DsLayout.fromWidth(const Size(1280, 800)).breakpoint, DsBreakpoint.desktop);
  });

  testWidgets('a store dashboard renders its content and reacts to taps', (tester) async {
    usePhoneScreen(tester);
    var tab = -1;
    var opened = 0;
    var adds = 0;

    await tester.pumpWidget(
      host(
        DsScaffold(
          title: 'Dashboard',
          showBack: false,
          body: ListView(
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              const Row(
                children: [
                  Expanded(child: DsStatTile(icon: Icons.receipt_long_rounded, label: 'Total orders', value: '128', tone: DsTone.info)),
                  DsGap(DsSpace.md),
                  Expanded(child: DsStatTile(icon: Icons.payments_outlined, label: 'Earnings', value: '2,450.00')),
                ],
              ),
              const DsSectionHeader(title: 'Orders'),
              DsSegmentedTabs(
                segments: const [DsSegment('New', count: 120), DsSegment('Accepted'), DsSegment('Completed')],
                index: 0,
                onChanged: (i) => tab = i,
              ),
              const DsGap(DsSpace.md),
              DsListTile(
                leadingIcon: Icons.restaurant_menu_rounded,
                title: 'Order #2048',
                subtitle: '2 items',
                trailing: const DsStatusChip(label: 'Placed', status: 'Order Placed'),
                showChevron: true,
                onTap: () => opened++,
              ),
              const DsGap(DsSpace.lg),
              DsButton.primary(label: 'Add product', expand: true, onPressed: () => adds++),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Total orders'), findsOneWidget);
    expect(find.text('128'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('2,450.00'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget, reason: 'segment counts above 99 are capped');
    expect(find.text('Order #2048'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Placed'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(tab, 2);

    await tester.tap(find.text('Order #2048'));
    await tester.pumpAndSettle();
    expect(opened, 1);

    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();
    expect(adds, 1);
  });

  testWidgets('the error state renders in dark mode and retries', (tester) async {
    usePhoneScreen(tester);
    var retries = 0;

    await tester.pumpWidget(host(Scaffold(body: DsErrorState(onRetry: () => retries++)), dark: true));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(DsErrorState))).brightness, Brightness.dark);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Please check your connection and try again.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(retries, 1);
  });
}
