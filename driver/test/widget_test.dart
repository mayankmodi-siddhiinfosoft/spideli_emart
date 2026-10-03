import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Driver app smoke test.
///
/// `MyApp` starts Firebase and Firestore listeners, so it is not pumped here.
/// Instead this checks the design system every driver screen is built on:
/// the light / dark / high-contrast themes, the status mapping, and the
/// driver widgets (online toggle, route, trip metrics) rendering and
/// responding to taps, all without Firebase or network.
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

    test('high-contrast themes use stronger borders', () {
      final normal = DsTheme.light();
      final strong = DsTheme.lightHighContrast();
      expect(strong.brightness, Brightness.light);
      expect(strong.colorScheme.outline, DsColors.lightHighContrast.borderStrong);
      expect(strong.colorScheme.outline, isNot(normal.colorScheme.outline));
      expect(DsTheme.darkHighContrast().brightness, Brightness.dark);
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

  test('DsTone.fromStatus maps driver statuses to tones', () {
    expect(DsTone.fromStatus(null), DsTone.neutral);
    expect(DsTone.fromStatus(''), DsTone.neutral);
    expect(DsTone.fromStatus('Offline'), DsTone.neutral);
    expect(DsTone.fromStatus('Online'), DsTone.success);
    expect(DsTone.fromStatus('Order Placed'), DsTone.brand);
    expect(DsTone.fromStatus('Order Completed'), DsTone.success);
    expect(DsTone.fromStatus('Order Rejected'), DsTone.danger);
    expect(DsTone.fromStatus('pending'), DsTone.warning);
    expect(DsTone.fromStatus('In Transit'), DsTone.info);
  });

  test('DsLayout.fromWidth picks the breakpoint', () {
    expect(DsLayout.fromWidth(const Size(390, 844)).breakpoint, DsBreakpoint.phone);
    expect(DsLayout.fromWidth(const Size(820, 1180)).breakpoint, DsBreakpoint.tablet);
    expect(DsLayout.fromWidth(const Size(1280, 800)).breakpoint, DsBreakpoint.desktop);
  });

  testWidgets('a driver DS screen renders the trip and reacts to taps', (tester) async {
    usePhoneScreen(tester);
    final toggles = <bool>[];
    var accepts = 0;

    await tester.pumpWidget(
      host(
        DsScaffold(
          title: 'Home',
          showBack: false,
          body: ListView(
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              DsOnlineToggle(isOnline: false, onChanged: toggles.add),
              const DsSectionHeader(title: 'New request'),
              const DsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DsRouteStops(
                      stops: [
                        DsRouteStop(kind: DsStopKind.pickup, label: 'Pickup', address: '12 Market Road'),
                        DsRouteStop(kind: DsStopKind.drop, label: 'Drop-off', address: '48 Lake View'),
                      ],
                    ),
                    DsGap(DsSpace.md),
                    DsTripMetrics(
                      items: [
                        DsTripMetric(icon: Icons.route_rounded, value: '4.2 km', label: 'Distance'),
                        DsTripMetric(icon: Icons.schedule_rounded, value: '12 min', label: 'ETA'),
                      ],
                    ),
                    DsInfoRow(label: 'Delivery fee', value: '45.00'),
                    DsStatusChip(label: 'Pending', status: 'pending'),
                  ],
                ),
              ),
              const DsGap(DsSpace.lg),
              DsButton.primary(label: 'Accept', expand: true, onPressed: () => accepts++),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('New request'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('12 Market Road'), findsOneWidget);
    expect(find.text('Drop-off'), findsOneWidget);
    expect(find.text('48 Lake View'), findsOneWidget);
    expect(find.text('4.2 km'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('Delivery fee'), findsOneWidget);
    expect(find.text('45.00'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text("You're offline"));
    await tester.pumpAndSettle();
    expect(toggles, [true], reason: 'tapping the offline toggle asks to go online');

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(accepts, 1);
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
