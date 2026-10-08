import 'package:driver/lang/app_ar.dart';
import 'package:driver/lang/app_de.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/lang/app_fr.dart';
import 'package:driver/lang/app_hi.dart';
import 'package:driver/lang/app_ja.dart';
import 'package:driver/lang/app_pt.dart';
import 'package:driver/lang/app_ru.dart';
import 'package:driver/lang/app_zh.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// The job panel docked over the map (every service) can be minimized so
/// the map is free, without ever reaching or triggering its actions.
void main() {
  const toggle = ValueKey('ds-map-panel-toggle');
  const handle = ValueKey('ds-map-panel-handle');

  setUp(DsMapPanel.debugResetMemory);

  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  void useTabletScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(2048, 2732);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Widget host(Widget panel, {double textScale = 1, bool reduceMotion = false}) => GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: DsTheme.light(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
        child: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.green)),
              Align(alignment: Alignment.bottomCenter, child: panel),
            ],
          ),
        ),
      ),
    ),
  );

  /// A trip panel like the cab "In Transit" one.
  Widget tripPanel({Object? stateKey = 'ride-1|In Transit', String? storageId, VoidCallback? onConfirmed, ValueChanged<bool>? onCollapsedChanged, bool? floating}) {
    return DsMapPanel(
      stateKey: stateKey,
      storageId: storageId,
      floating: floating,
      onCollapsedChanged: onCollapsedChanged,
      header: const Row(
        children: [
          Expanded(child: DsStatusChip(label: 'In Transit', tone: DsTone.info)),
          Text('\$12.00'),
        ],
      ),
      actions: DsSlideToConfirm(label: 'Complete Ride', onConfirmed: onConfirmed ?? () {}),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [Text('Route stops'), Text('Payment Type'), SizedBox(height: 200)],
      ),
    );
  }

  double panelHeight(WidgetTester tester) => tester.getSize(find.byType(DsMapPanel)).height;

  group('DsMapPanel minimize', () {
    testWidgets('the minimize button collapses to the header bar, hides details and actions', (tester) async {
      usePhoneScreen(tester);
      var confirmed = 0;
      final changes = <bool>[];
      await tester.pumpWidget(host(tripPanel(onConfirmed: () => confirmed++, onCollapsedChanged: changes.add)));
      await tester.pumpAndSettle();

      final expandedHeight = panelHeight(tester);
      expect(find.text('Route stops'), findsOneWidget);
      expect(find.byType(DsSlideToConfirm), findsOneWidget);
      expect(find.byTooltip('Minimize'), findsOneWidget);

      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();

      expect(find.text('Route stops'), findsNothing);
      expect(find.byType(DsSlideToConfirm), findsNothing, reason: 'Complete Ride cannot be reached while minimized');
      expect(find.text('In Transit'), findsOneWidget, reason: 'the bar keeps the status');
      expect(find.text('\$12.00'), findsOneWidget, reason: 'and the amount');
      expect(find.byTooltip('Show details'), findsOneWidget);
      expect(panelHeight(tester), lessThan(expandedHeight - 200));
      expect(confirmed, 0, reason: 'minimizing never triggers the action');
      expect(changes, [true]);
    });

    testWidgets('expand restores the panel and its actions', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(tripPanel()));
      await tester.pumpAndSettle();
      final expandedHeight = panelHeight(tester);

      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();

      expect(find.text('Route stops'), findsOneWidget);
      expect(find.byType(DsSlideToConfirm), findsOneWidget);
      expect(find.byTooltip('Minimize'), findsOneWidget);
      expect(panelHeight(tester), expandedHeight);
    });

    testWidgets('the change is animated, and actions stop taking taps at once', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(tripPanel()));
      await tester.pumpAndSettle();
      final expandedHeight = panelHeight(tester);

      await tester.tap(find.byKey(toggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midHeight = panelHeight(tester);
      expect(midHeight, lessThan(expandedHeight));
      expect(find.byType(DsSlideToConfirm).hitTestable(), findsNothing, reason: 'ignored while collapsing');

      await tester.pumpAndSettle();
      expect(panelHeight(tester), lessThan(midHeight));
    });

    testWidgets('tapping the minimized bar or the handle expands; the handle also minimizes', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(tripPanel()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(handle));
      await tester.pumpAndSettle();
      expect(find.text('Route stops'), findsNothing);

      await tester.tap(find.text('In Transit'));
      await tester.pumpAndSettle();
      expect(find.text('Route stops'), findsOneWidget);

      await tester.tap(find.byKey(handle));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(handle));
      await tester.pumpAndSettle();
      expect(find.text('Route stops'), findsOneWidget);
    });

    testWidgets('dragging the header down minimizes and up expands', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(tripPanel()));
      await tester.pumpAndSettle();

      await tester.drag(find.text('In Transit'), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(find.text('Route stops'), findsNothing);

      await tester.fling(find.text('In Transit'), const Offset(0, -80), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Route stops'), findsOneWidget);
    });

    testWidgets('a new job state opens a minimized panel again', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(tripPanel(stateKey: 'ride-1|Order Shipped')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();
      expect(find.byType(DsSlideToConfirm), findsNothing);

      // Same state rebuilt: stays minimized.
      await tester.pumpWidget(host(tripPanel(stateKey: 'ride-1|Order Shipped')));
      await tester.pumpAndSettle();
      expect(find.byType(DsSlideToConfirm), findsNothing);

      // Status changed: expanded again.
      await tester.pumpWidget(host(tripPanel(stateKey: 'ride-1|In Transit')));
      await tester.pumpAndSettle();
      expect(find.byType(DsSlideToConfirm), findsOneWidget);
      expect(find.text('Route stops'), findsOneWidget);
    });

    testWidgets('remembered per screen while the job state is unchanged', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(tripPanel(storageId: 'cab.trip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();

      // The screen leaves (tab switch) and comes back: still minimized.
      await tester.pumpWidget(host(const SizedBox()));
      await tester.pumpWidget(host(tripPanel(storageId: 'cab.trip')));
      await tester.pumpAndSettle();
      expect(find.text('Route stops'), findsNothing);
      expect(find.byTooltip('Show details'), findsOneWidget);

      // Another screen id is independent.
      await tester.pumpWidget(host(const SizedBox()));
      await tester.pumpWidget(host(tripPanel(storageId: 'delivery.trip')));
      await tester.pumpAndSettle();
      expect(find.text('Route stops'), findsOneWidget);

      // Back with a new status: expanded.
      await tester.pumpWidget(host(const SizedBox()));
      await tester.pumpWidget(host(tripPanel(storageId: 'cab.trip', stateKey: 'ride-1|completed')));
      await tester.pumpAndSettle();
      expect(find.text('Route stops'), findsOneWidget);
    });

    testWidgets('a request panel without header shows its collapsed bar', (tester) async {
      usePhoneScreen(tester);
      var accepted = 0;
      await tester.pumpWidget(
        host(
          DsMapPanel(
            showHandle: false,
            stateKey: 'request|1',
            collapsedHeader: const DsStatusChip(label: 'New ride request', tone: DsTone.warning),
            child: DsRequestCard(margin: EdgeInsets.zero, title: 'Request card', onAccept: () => accepted++, onReject: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Request card'), findsOneWidget);
      expect(find.text('New ride request'), findsNothing);
      expect(find.byKey(handle), findsOneWidget, reason: 'a collapsible panel always has a handle on phones');

      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();
      expect(find.text('Request card'), findsNothing);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('New ride request'), findsOneWidget);
      expect(accepted, 0);
    });

    testWidgets('collapsible: false keeps the classic panel', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(const DsMapPanel(collapsible: false, showHandle: false, child: Text('Loading'))));
      await tester.pumpAndSettle();
      expect(find.byKey(toggle), findsNothing);
      expect(find.byKey(handle), findsNothing);
      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('the tablet floating card minimizes too', (tester) async {
      useTabletScreen(tester);
      await tester.pumpWidget(host(tripPanel()));
      await tester.pumpAndSettle();
      expect(find.byKey(handle), findsNothing, reason: 'no handle on the floating card');

      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();
      expect(find.byType(DsSlideToConfirm), findsNothing);
      expect(find.text('In Transit'), findsOneWidget);

      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();
      expect(find.byType(DsSlideToConfirm), findsOneWidget);
    });

    testWidgets('no overflow at a large text scale, expanded or minimized', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(tripPanel(), textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(toggle));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce motion switches at once', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(host(tripPanel(), reduceMotion: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(toggle));
      await tester.pump();
      expect(find.byType(DsSlideToConfirm), findsNothing);
      final firstFrame = panelHeight(tester);
      await tester.pumpAndSettle();
      expect(panelHeight(tester), firstFrame, reason: 'already at the minimized size on the first frame');
    });
  });

  group('DsMapPanelArea', () {
    testWidgets('publishes the panel height to the map once it settles', (tester) async {
      usePhoneScreen(tester);
      final insets = <double>[];
      await tester.pumpWidget(
        GetMaterialApp(
          theme: DsTheme.light(),
          home: Scaffold(
            body: DsMapPanelArea(
              map: Builder(
                builder: (context) {
                  insets.add(DsMapInset.bottomOf(context));
                  return const ColoredBox(color: Colors.green);
                },
              ),
              panel: tripPanel(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      final expanded = insets.last;
      expect(expanded, closeTo(tester.getSize(find.byType(DsMapPanel)).height, 1));

      await tester.tap(find.byKey(toggle));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(insets.last, lessThan(expanded), reason: 'minimized: the map gets the space back');
      expect(insets.last, closeTo(tester.getSize(find.byType(DsMapPanel)).height, 1));
    });
  });

  test('the new labels are translated in every language', () {
    for (final lang in [enUS, lnAr, deGR, trFR, hiIN, jaJP, ptPO, ruRU, zhCH]) {
      expect(lang['Minimize'], isNotEmpty);
      expect(lang['Show details'], isNotEmpty);
    }
  });
}
