import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Customer app smoke test.
///
/// `MyApp` starts Firebase and Firestore listeners, so it is not pumped here.
/// Instead this checks the design system every customer screen is built on:
/// the light / dark themes, the status and section mappings, and a
/// representative DS screen that renders and responds to taps, all without
/// Firebase or network.
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

    test('follows the brand color loaded at runtime and a section accent override', () {
      final original = AppThemeData.primary300;
      addTearDown(() => AppThemeData.primary300 = original);

      AppThemeData.primary300 = const Color(0xFF7B1FA2);
      expect(DsTheme.light().colorScheme.primary, const Color(0xFF7B1FA2));
      expect(DsTheme.light().colorScheme.onPrimary, Colors.white, reason: 'dark brand gets light text');

      AppThemeData.primary300 = const Color(0xFFFFEB3B);
      expect(DsTheme.light().colorScheme.onPrimary, isNot(Colors.white), reason: 'light brand gets dark text');

      expect(DsTheme.build(false, brand: const Color(0xFF00897B)).colorScheme.primary, const Color(0xFF00897B));
    });
  });

  test('DsTone.fromStatus maps order statuses to tones', () {
    expect(DsTone.fromStatus(null), DsTone.neutral);
    expect(DsTone.fromStatus(''), DsTone.neutral);
    expect(DsTone.fromStatus('Order Placed'), DsTone.brand);
    expect(DsTone.fromStatus('Order Completed'), DsTone.success);
    expect(DsTone.fromStatus('Order Rejected'), DsTone.danger);
    expect(DsTone.fromStatus('Order Cancelled'), DsTone.danger);
    expect(DsTone.fromStatus('pending'), DsTone.warning);
    expect(DsTone.fromStatus('In Transit'), DsTone.info);
  });

  test('DsSection.fromServiceFlag maps section flags', () {
    expect(DsSection.fromServiceFlag('delivery-service'), DsSection.food);
    expect(DsSection.fromServiceFlag('ecommerce-service'), DsSection.ecommerce);
    expect(DsSection.fromServiceFlag('cab-service'), DsSection.cab);
    expect(DsSection.fromServiceFlag('parcel_delivery'), DsSection.parcel);
    expect(DsSection.fromServiceFlag('rental-service'), DsSection.rental);
    expect(DsSection.fromServiceFlag(' OnDemand-Service '), DsSection.onDemand);
    expect(DsSection.fromServiceFlag(null), DsSection.none);
    expect(DsSection.fromServiceFlag('unknown'), DsSection.none);
  });

  test('DsLayout.fromWidth picks the breakpoint', () {
    expect(DsLayout.fromWidth(const Size(390, 844)).breakpoint, DsBreakpoint.phone);
    expect(DsLayout.fromWidth(const Size(820, 1180)).breakpoint, DsBreakpoint.tablet);
    expect(DsLayout.fromWidth(const Size(1280, 800)).breakpoint, DsBreakpoint.desktop);
  });

  testWidgets('a DS screen renders its content and reacts to taps', (tester) async {
    usePhoneScreen(tester);
    var reorders = 0;
    var tab = -1;

    await tester.pumpWidget(
      host(
        DsScaffold(
          title: 'My orders',
          showBack: false,
          body: ListView(
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              DsSegmentedTabs(segments: const [DsSegment('Active', count: 120), DsSegment('Past')], index: 0, onChanged: (i) => tab = i),
              const DsSectionHeader(title: 'Today'),
              const DsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #1024'),
                    DsGap(DsSpace.sm),
                    DsStatusChip(label: 'Delivered', status: 'Order Completed'),
                    DsGap(DsSpace.sm),
                    DsBadge(label: 'New', tone: DsTone.brand),
                  ],
                ),
              ),
              const DsGap(DsSpace.lg),
              DsButton.primary(label: 'Reorder', expand: true, onPressed: () => reorders++),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My orders'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget, reason: 'segment counts above 99 are capped');
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Order #1024'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(tab, 1);

    await tester.tap(find.text('Reorder'));
    await tester.pumpAndSettle();
    expect(reorders, 1);
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
