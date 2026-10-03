import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/themes/ds/ds.dart';

/// Worker app smoke test.
///
/// `MyApp` starts Firebase and Firestore listeners, so it is not pumped here.
/// Instead this checks the design system every worker screen is built on:
/// the light / dark themes, the status mapping, and a profile-style DS
/// screen (progress, settings tiles, empty state) that renders and responds
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
      expect(DsTheme.light().colorScheme.primary, const Color(0xFF7B1FA2));
      expect(DsTheme.light().colorScheme.onPrimary, Colors.white, reason: 'dark brand gets light text');

      AppColors.colorPrimary = const Color(0xFFFFEB3B);
      expect(DsTheme.light().colorScheme.onPrimary, isNot(Colors.white), reason: 'light brand gets dark text');
    });
  });

  test('DsTone.fromStatus maps job statuses to tones', () {
    expect(DsTone.fromStatus(null), DsTone.neutral);
    expect(DsTone.fromStatus(''), DsTone.neutral);
    expect(DsTone.fromStatus('Offline'), DsTone.neutral);
    expect(DsTone.fromStatus('Online'), DsTone.success);
    expect(DsTone.fromStatus('Order Placed'), DsTone.brand);
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

  testWidgets('a worker profile screen renders its content and reacts to taps', (tester) async {
    usePhoneScreen(tester);
    final tapped = <String>[];

    await tester.pumpWidget(
      host(
        DsScaffold(
          title: 'Profile',
          showBack: false,
          body: ListView(
            padding: const EdgeInsets.all(DsSpace.lg),
            children: [
              const DsCard(child: DsProgressBar(label: 'Profile completion', value: 0.5, showPercent: true)),
              const DsGap(DsSpace.lg),
              DsTileGroup(
                title: 'Account',
                children: [
                  DsListTile(leadingIcon: Icons.badge_outlined, title: 'My documents', subtitle: 'Verified', showChevron: true, onTap: () => tapped.add('documents')),
                  DsListTile(leadingIcon: Icons.logout_rounded, title: 'Log out', destructive: true, onTap: () => tapped.add('logout')),
                ],
              ),
              const DsGap(DsSpace.lg),
              const DsStatusChip(label: 'Online', status: 'Online'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Profile completion'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget, reason: 'tile group titles render as an overline');
    expect(find.text('My documents'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('My documents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(tapped, ['documents', 'logout']);
  });

  testWidgets('the empty jobs state offers its action', (tester) async {
    usePhoneScreen(tester);
    var refreshes = 0;

    await tester.pumpWidget(
      host(
        Scaffold(
          body: DsEmptyState(
            icon: Icons.work_outline_rounded,
            title: 'No jobs yet',
            message: 'New bookings assigned to you will show up here.',
            actionLabel: 'Refresh',
            onAction: () => refreshes++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No jobs yet'), findsOneWidget);
    expect(find.text('New bookings assigned to you will show up here.'), findsOneWidget);

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(refreshes, 1);
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
