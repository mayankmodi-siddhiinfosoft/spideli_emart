import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/ds/ds.dart';

/// Provider app smoke test.
///
/// `MyApp` starts Firebase and Firestore listeners, so it is not pumped here.
/// Instead this checks the design system every provider screen is built on:
/// the light / dark themes, the status mapping, and a booking-style DS
/// screen (alert, booking timeline, action button) that renders and responds
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
      final original = AppColors.colorPrimary;
      addTearDown(() => AppColors.colorPrimary = original);

      AppColors.colorPrimary = const Color(0xFF7B1FA2);
      expect(DsPalette.brand, const Color(0xFF7B1FA2));
      expect(DsTheme.light().colorScheme.primary, const Color(0xFF7B1FA2));
      expect(DsTheme.light().colorScheme.onPrimary, Colors.white, reason: 'dark brand gets light text');

      AppColors.colorPrimary = const Color(0xFFFFEB3B);
      expect(DsTheme.light().colorScheme.onPrimary, isNot(Colors.white), reason: 'light brand gets dark text');
    });
  });

  test('DsTone.fromStatus maps booking statuses to tones', () {
    expect(DsTone.fromStatus(null), DsTone.neutral);
    expect(DsTone.fromStatus(''), DsTone.neutral);
    expect(DsTone.fromStatus('Order Placed'), DsTone.brand);
    expect(DsTone.fromStatus('Order Assigned'), DsTone.info);
    expect(DsTone.fromStatus('Order Ongoing'), DsTone.info);
    expect(DsTone.fromStatus('Order Completed'), DsTone.success);
    expect(DsTone.fromStatus('Order Rejected'), DsTone.danger);
    expect(DsTone.fromStatus('pending'), DsTone.warning);
  });

  test('DsLayout.fromWidth picks the breakpoint', () {
    expect(DsLayout.fromWidth(const Size(390, 844)).breakpoint, DsBreakpoint.phone);
    expect(DsLayout.fromWidth(const Size(820, 1180)).breakpoint, DsBreakpoint.tablet);
    expect(DsLayout.fromWidth(const Size(1280, 800)).breakpoint, DsBreakpoint.desktop);
  });

  testWidgets('a provider booking screen renders its content and reacts to taps', (tester) async {
    usePhoneScreen(tester);
    var uploads = 0;
    var starts = 0;

    await tester.pumpWidget(
      host(
        DsScaffold(
          title: 'Booking details',
          showBack: false,
          body: ListView(
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              DsInlineAlert(
                tone: DsTone.warning,
                title: 'Documents needed',
                message: 'Upload your ID to receive more bookings.',
                actionLabel: 'Upload now',
                onAction: () => uploads++,
              ),
              const DsSectionHeader(title: 'Booking status'),
              const DsCard(
                child: DsTimeline(
                  steps: [
                    DsTimelineStep(title: 'Booking placed', meta: '10:24', state: DsStepState.done),
                    DsTimelineStep(title: 'Accepted', state: DsStepState.current),
                    DsTimelineStep(title: 'Service completed'),
                  ],
                ),
              ),
              const DsGap(DsSpace.md),
              const DsStatusChip(label: 'Assigned', status: 'Order Assigned'),
              const DsGap(DsSpace.lg),
              DsButton.primary(label: 'Start service', expand: true, onPressed: () => starts++),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking details'), findsOneWidget);
    expect(find.text('Documents needed'), findsOneWidget);
    expect(find.text('Upload your ID to receive more bookings.'), findsOneWidget);
    expect(find.text('Booking status'), findsOneWidget);
    expect(find.text('Booking placed'), findsOneWidget);
    expect(find.text('10:24'), findsOneWidget);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Service completed'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Upload now'));
    await tester.pumpAndSettle();
    expect(uploads, 1);

    await tester.tap(find.text('Start service'));
    await tester.pumpAndSettle();
    expect(starts, 1);
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
