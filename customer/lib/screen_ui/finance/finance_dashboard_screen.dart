import 'package:customer/screen_ui/finance/bill_screens.dart';
import 'package:customer/screen_ui/finance/card_screens.dart';
import 'package:customer/screen_ui/finance/coach_screens.dart';
import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/finance/fin_kit.dart';
import 'package:customer/screen_ui/finance/finance_home_screen.dart';
import 'package:customer/screen_ui/finance/finance_profile_tab.dart';
import 'package:customer/screen_ui/finance/finance_region_gate.dart';
import 'package:customer/screen_ui/finance/insurance_screens.dart';
import 'package:customer/screen_ui/finance/intelligence_screens.dart';
import 'package:customer/screen_ui/finance/investment_screens.dart';
import 'package:customer/screen_ui/finance/lending_screens.dart';
import 'package:customer/screen_ui/finance/savings_screens.dart';
import 'package:customer/screen_ui/finance/tontine_screens.dart';
import 'package:customer/screen_ui/finance/transactions_screen.dart';
import 'package:customer/screen_ui/finance/transfer_screens.dart';
import 'package:customer/service/finance_region_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_region_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The Finance dashboard's tabs, in bar order.
enum FinanceTab { home, wallet, services, insights, profile }

/// The selected tab of the open Finance dashboard.
class FinanceDashboardController extends GetxController {
  FinanceDashboardController(FinanceTab initial) : tab = initial.obs;

  final Rx<FinanceTab> tab;

  /// Shows [target] on the open dashboard; without one (a screen opened from
  /// elsewhere) pushes [orOpen] instead.
  static void showTab(FinanceTab target, {required Widget Function() orOpen}) {
    if (Get.isRegistered<FinanceDashboardController>()) {
      Get.find<FinanceDashboardController>().tab.value = target;
    } else {
      Get.to(orOpen);
    }
  }
}

/// Spideli Finance, opened from the service list like Restaurants or Parcel
/// Service (FinanceSection): Home, Wallet, Services, Insights and Profile in
/// a bottom bar, in the Finance navy. A tab is built the first time it is
/// opened and kept after; Back on another tab returns to Home first.
///
/// Only where the customer's region offers Finance (FinanceRegion; the
/// admin's `regions.financeEnabled`), live: while it is open, the admin's
/// changes to the region and its settings reach every screen.
class FinanceDashboardScreen extends StatefulWidget {
  final FinanceTab initialTab;

  const FinanceDashboardScreen({super.key, this.initialTab = FinanceTab.home});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  late final FinanceDashboardController _controller = Get.put(FinanceDashboardController(widget.initialTab));
  final Set<FinanceTab> _built = {};

  /// One scroll position per tab: the tabs share this route, whose primary
  /// scroll controller would otherwise move them all together.
  final Map<FinanceTab, ScrollController> _scroll = {for (final t in FinanceTab.values) t: ScrollController()};

  late Stream<FinanceRegionPick> _region = FinanceRegion.watch();

  @override
  void initState() {
    super.initState();
    FinanceRegion.retain();
  }

  /// Resolves the region again (the customer may have chosen a location).
  Future<void> _retryRegion() async {
    await RegionService.ensureCustomerCountry(force: true);
    if (mounted) setState(() => _region = FinanceRegion.watch());
  }

  static Widget _page(FinanceTab tab) => switch (tab) {
        FinanceTab.home => const FinanceHomeScreen(),
        FinanceTab.wallet => const TransactionsScreen(asTab: true),
        FinanceTab.services => const FinanceServicesTab(),
        FinanceTab.insights => const FinanceInsightsTab(),
        FinanceTab.profile => const FinanceProfileTab(),
      };

  @override
  void dispose() {
    for (final c in _scroll.values) {
      c.dispose();
    }
    Get.delete<FinanceDashboardController>();
    FinanceRegion.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return DsAccentScope(
      color: dark ? FinColors.navyDark : FinColors.navy,
      child: StreamBuilder<FinanceRegionPick>(
        stream: _region,
        builder: (context, region) {
          final pick = region.data;
          if (pick == null) {
            final Widget state = region.hasError
                ? FinState.error("Could not load this service. Check your connection and try again.".tr, onRetry: _retryRegion)
                : FinState.loading(rows: 4);
            return FinScaffold(title: "Spideli Finance".tr, body: FinBody(children: [state]));
          }
          if (!pick.isReady) return FinanceRegionUnavailable(pick: pick, onRetry: _retryRegion);
          return _tabs();
        },
      ),
    );
  }

  /// The tabs, once the region offers Finance.
  Widget _tabs() => Obx(() {
        final FinanceTab current = _controller.tab.value;
        _built.add(current);
        return PopScope(
          canPop: current == FinanceTab.home,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _controller.tab.value = FinanceTab.home;
          },
          child: Scaffold(
            backgroundColor: FinColors.page(context),
            body: IndexedStack(
              index: current.index,
              children: [
                for (final t in FinanceTab.values) _built.contains(t) ? PrimaryScrollController(controller: _scroll[t]!, child: _page(t)) : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: _FinanceNavBar(current: current, onSelect: (t) => _controller.tab.value = t),
          ),
        );
      });
}

/// The bottom bar: a hairline over a surface, the active tab in a soft navy
/// well (as on the other services' dashboards).
class _FinanceNavBar extends StatelessWidget {
  final FinanceTab current;
  final ValueChanged<FinanceTab> onSelect;

  const _FinanceNavBar({required this.current, required this.onSelect});

  static const Map<FinanceTab, (IconData, IconData, String)> _items = {
    FinanceTab.home: (Icons.home_outlined, Icons.home_rounded, 'Home'),
    FinanceTab.wallet: (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Wallet'),
    FinanceTab.services: (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Services'),
    FinanceTab.insights: (Icons.insights_outlined, Icons.insights_rounded, 'Insights'),
    FinanceTab.profile: (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  };

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.divider)),
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: dark ? 0.3 : 0.05), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: Colors.transparent,
        currentIndex: current.index,
        selectedItemColor: c.brandStrong,
        unselectedItemColor: c.textMuted,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: DsTypography.labelSm.copyWith(fontSize: 12),
        unselectedLabelStyle: DsTypography.labelSm.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
        onTap: (i) => onSelect(FinanceTab.values[i]),
        items: [
          for (final t in FinanceTab.values)
            BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: DsMotion.base,
                curve: DsMotion.emphasized,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 5),
                decoration: BoxDecoration(color: t == current ? c.brandSoft : Colors.transparent, borderRadius: DsRadius.brPill),
                child: Icon(t == current ? _items[t]!.$2 : _items[t]!.$1, size: 22),
              ),
              label: _items[t]!.$3.tr,
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- services

/// Services tab: the nine services of the finance workflow, each with what
/// it is for.
class FinanceServicesTab extends StatelessWidget {
  const FinanceServicesTab({super.key});

  static final List<(String, FinAccent, List<(IconData, String, String, Widget Function())>)> _groups = [
    (
      "Pay and send",
      FinAccent.pay,
      [
        (Icons.north_east_rounded, "Money transfer", "To a Spideli user, Mobile Money, Wave or a bank", () => const TransfersScreen()),
        (Icons.receipt_outlined, "Payment", "Electricity, water, TV, internet, taxes and more", () => const BillsScreen()),
        (Icons.credit_card_outlined, "Virtual card", "Create cards for online payments and manage them", () => const CardsScreen()),
      ]
    ),
    (
      "Save and invest",
      FinAccent.save,
      [
        (Icons.savings_outlined, "Collective savings", "Save towards a goal, alone or with others", () => const SavingsListScreen()),
        (Icons.groups_2_outlined, "Tontine", "Save in a group and take turns receiving the pot", () => const TontineListScreen()),
        (Icons.trending_up_rounded, "Investment", "Funds, projects to back and the markets", () => const InvestmentsScreen()),
      ]
    ),
    (
      "Borrow and protect",
      FinAccent.borrow,
      [
        (Icons.handshake_outlined, "Loan", "Borrow from your groups, with your credit score", () => const LoansScreen()),
        (Icons.health_and_safety_outlined, "Online insurance", "Buy cover and follow your claims", () => const InsuranceScreen()),
      ]
    ),
    (
      "Get help",
      FinAccent.help,
      [
        (Icons.auto_awesome_outlined, "AI assistant", "Your financial coach and simulators", () => const AiAssistantScreen()),
      ]
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Services".tr,
      showBack: false,
      body: FinBody(children: [
        Text("What would you like to do?".tr, style: DsTypography.headline.copyWith(color: DsColors.of(context).textPrimary)),
        const DsGap(DsSpace.xxs),
        Text("Every Spideli Finance service, by what it helps you do.".tr, style: DsTypography.body.copyWith(color: DsColors.of(context).textSecondary)),
        for (final (name, accent, items) in _groups)
          FinServiceGroup(
            title: name.tr,
            accent: accent,
            services: [for (final (icon, title, subtitle, page) in items) FinService(icon, title.tr, subtitle.tr, () => Get.to(page))],
          ),
      ]),
    );
  }
}

// ----------------------------------------------------------------- insights

/// Insights tab: money in and out over the months and the last 30 days, then
/// the tools to understand and plan (the AI assistant, the markets) and the
/// statement.
class FinanceInsightsTab extends StatelessWidget {
  const FinanceInsightsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Insights".tr,
      showBack: false,
      actions: [
        DsIconButton(icon: Icons.picture_as_pdf_outlined, semanticLabel: "Download statement".tr, onPressed: () => shareFinanceStatement(context)),
      ],
      body: StreamBuilder<FinanceSummary?>(
        stream: FinanceService.summary(),
        builder: (context, snap) {
          final s = snap.data;
          return FinBody(children: [
            if (snap.connectionState == ConnectionState.waiting)
              FinState.loading(rows: 3)
            else if (snap.hasError)
              FinState.error("Could not load your overview.".tr, onRetry: FinanceService.retry)
            else if (s == null || (s.monthly.isEmpty && s.last30Days.isEmpty))
              FinState.empty(Icons.insights_outlined, "Your cash flow appears here once you use Spideli Finance services.".tr)
            else
              FinanceCashFlow(summary: s),
            FinServiceGroup(
              title: "Plan and understand".tr,
              accent: FinAccent.help,
              services: [
                FinService(Icons.auto_awesome_outlined, "AI assistant".tr, "Ask the coach, try the simulators".tr, () => Get.to(() => const AiAssistantScreen())),
                FinService(Icons.query_stats_rounded, "Markets".tr, "Indicators, exchange rates, stocks, bonds, IPOs and news".tr,
                    () => Get.to(() => const IntelligenceScreen(view: IntelligenceView.markets))),
                FinService(Icons.picture_as_pdf_outlined, "Account statement".tr, "PDF of your transactions for a period".tr, () => shareFinanceStatement(context)),
              ],
            ),
          ]);
        },
      ),
    );
  }
}
