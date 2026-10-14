import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The finance design system on the smallest phones the app supports, with
/// large text and in Arabic (right to left), in light and dark: long amounts,
/// labels and statuses must wrap or shorten, never overflow.
void main() {
  String m(num v) => FinanceMoney.format(v, 'XAF');

  Widget kit() => FinBody(children: [
        FinHero(
          label: 'Available balance',
          amount: m(1245000000),
          caption: 'Also: ${m(25000000)} · ${m(1250000)} · a long caption that has to wrap',
          stats: [FinHeroStat('Invested', m(104300000)), FinHeroStat('Saved so far', m(65000000)), FinHeroStat('Still to repay', m(51763000))],
          footer: FinActions(onHero: true, actions: [
            FinAction(Icons.north_east_rounded, 'Send money', () {}),
            FinAction(Icons.receipt_outlined, 'Pay bills', () {}),
            FinAction(Icons.savings_outlined, 'Collective savings', () {}),
            FinAction(Icons.trending_up_rounded, 'Investment', () {}),
          ]),
        ),
        FinSection(
          title: 'Coming up and a long section title',
          actionLabel: 'See all',
          onAction: () {},
          divided: true,
          children: [
            FinListTile(
              icon: Icons.groups_2_outlined,
              title: 'Tontine contribution for the family tontine of the neighbourhood',
              subtitle: 'Every month · 12 members · Next contribution: 18 Oct 2026 · Still to repay ${m(51763000)}',
              amount: m(10000000),
              status: 'awaiting_payment',
              statusLabel: 'Awaiting payment',
              chevron: true,
              onTap: () {},
            ),
            FinRow('Late payment penalty on the remaining instalments', m(1200000), sub: 'Charged from the 8th day after the due date'),
          ],
        ),
        FinMetrics(items: [FinMetric('Money in', m(350000000)), FinMetric('Money out', m(105000000)), FinMetric('Net', m(245000000))]),
        FinMetrics(items: [
          FinMetric('Money in during the month', m(350000000), sub: 'Sep 2026: ${m(1250000000)}'),
          FinMetric('Money out during the month', m(105000000), sub: 'Sep 2026: ${m(980000000)}'),
        ]),
        FinProgress(value: 0.67, label: 'Collected ${m(20000000)} of ${m(30000000)}', trailing: '67%'),
        const FinTrack(steps: ['Submitted', 'Under review', 'Voting', 'Funding', 'Agreement', 'Disbursing', 'Active', 'Repaid'], current: 2),
        FinNotice('Your documents are being reviewed. You can keep using the services that do not need a verified identity.',
            title: 'Identity verification', actionLabel: 'Open verification', onAction: () {}),
        FinBarChart(
          labels: const ['May 2026', 'Jun 2026', 'Jul 2026', 'Aug 2026', 'Sep 2026', 'Oct 2026'],
          a: const [120000, 80000, 200000, 110000, 150000, 350000],
          b: const [90000, 60000, 190000, 90000, 100000, 105000],
          aLabel: 'Money in',
          bLabel: 'Money out',
          aColor: Colors.green,
          bColor: Colors.indigo,
          format: (v) => m(v * 1000),
        ),
        FinBarChart(
          labels: [for (int i = 1; i <= 12; i++) '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][i - 1]} 2026'],
          a: [for (int i = 1; i <= 12; i++) 1250000.0 * i],
          b: [for (int i = 1; i <= 12; i++) 1000000.0 * i],
          aLabel: 'Money in',
          bLabel: 'Money out',
          aColor: Colors.green,
          bColor: Colors.indigo,
          format: (v) => m(v),
        ),
        FinBarChart(labels: const [], a: const [], b: const [], aLabel: 'Money in', bLabel: 'Money out', aColor: Colors.green, bColor: Colors.indigo, format: (v) => m(v)),
        FinShareBar(parts: [('Money market', 0.5, m(52150000)), ('Bonds', 0.3, m(31290000)), ('Equities', 0.15, m(15645000)), ('Real estate', 0.05, m(5215000))]),
        FinShareBar(percent: true, parts: [
          for (int i = 0; i < 8; i++) ('Asset class number ${i + 1} with a long name', 1250000.0 * (i + 1), m(1250000000 * (i + 1))),
        ]),
        FinState.empty(Icons.inventory_2_outlined, 'No opportunity is open right now. Come back later or set your investor preferences.'),
        FinState.error('Could not load your overview. Check your connection and try again.'),
      ]);

  Future<void> pump(WidgetTester tester, {required double scale, required TextDirection dir, required bool dark}) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: DsTheme.light(),
      darkTheme: DsTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(textDirection: dir, child: Scaffold(body: kit())),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final (String name, double scale, TextDirection dir, bool dark) in [
    ('320dp, text 1.0', 1.0, TextDirection.ltr, false),
    ('320dp, text 1.3', 1.3, TextDirection.ltr, false),
    ('320dp, text 1.3, right to left', 1.3, TextDirection.rtl, false),
    ('320dp, text 1.3, dark', 1.3, TextDirection.ltr, true),
  ]) {
    testWidgets('finance components never overflow: $name', (tester) async {
      await pump(tester, scale: scale, dir: dir, dark: dark);
      expect(tester.takeException(), isNull);
      // Scroll through everything: every part gets laid out.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
