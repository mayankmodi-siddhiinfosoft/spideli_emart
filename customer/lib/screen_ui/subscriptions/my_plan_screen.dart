import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/screen_ui/subscriptions/gateway_checkout_screen.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/customer_plan_service.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "My plan" (spec 7.7): status of the full order-history plan, renewal
/// date, the plans on sale in the customer's region, and past purchases
/// (the `subscription_history` rows serve as invoices).
class MyPlanScreen extends StatefulWidget {
  const MyPlanScreen({super.key});

  @override
  State<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends State<MyPlanScreen> {
  bool _loading = true;
  Map<String, dynamic>? _user;
  List<CustomerPlan> _plans = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([CustomerPlanService.currentUserData(), CustomerPlanService.availablePlans(), CustomerPlanService.purchaseHistory()]);
      _user = results[0] as Map<String, dynamic>?;
      _plans = results[1] as List<CustomerPlan>;
      _history = results[2] as List<Map<String, dynamic>>;
    } catch (e) {
      ShowToastDialog.showToast("${'Something went wrong:'.tr} $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _buy(CustomerPlan plan) async {
    final result = await Get.to(
      () => GatewayCheckoutScreen(
        title: "${"Full order history".tr} - ${plan.name}",
        amount: plan.price,
        currency: CustomerPlanService.currency,
        regionId: RegionService.customerRegionId,
        onPaid: (method) => CustomerPlanService.recordPurchase(plan, paymentType: method),
      ),
    );
    if (result == true) {
      ShowToastDialog.showToast("Your plan is active. Your complete order history is now visible.".tr);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    return Scaffold(
      backgroundColor: SubUi.surface(isDark),
      appBar: SubUi.appBar("My plan".tr, isDark),
      body:
          _loading
              ? Constant.loader()
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [_status(isDark), SubUi.heading("Plans".tr, isDark), ..._planCards(isDark), SubUi.heading("Past purchases".tr, isDark), ..._historyCards(isDark)]),
              ),
    );
  }

  Widget _status(bool isDark) {
    final plan = CustomerPlanService.customerPlanOf(_user);
    final Timestamp? expiry = CustomerPlanService.expiryOf(_user);
    final bool active = CustomerPlanService.hasFullHistory(_user);
    String statusText;
    Color color;
    if (plan == null) {
      statusText = "No plan".tr;
      color = AppThemeData.grey500;
    } else if (active) {
      statusText = "Active".tr;
      color = AppThemeData.success400;
    } else {
      statusText = "Expired".tr;
      color = AppThemeData.danger300;
    }
    return SubUi.card(
      isDark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: SubUi.title(plan == null ? "Full order history".tr : (plan['name']?.toString() ?? '-'), isDark)), SubUi.chip(statusText, color)]),
          const SizedBox(height: 6),
          if (plan == null) SubUi.body("Free access shows your latest orders only. Subscribe to see your complete order history.".tr, isDark),
          if (plan != null) SubUi.row("Period".tr, CustomerPlanService.periodLabel(plan['expiryDay']?.toString() ?? ''), isDark),
          if (plan != null) SubUi.row(active ? "Renews / expires".tr : "Expired on".tr, expiry == null ? "Never expires".tr : Constant.timestampToDate(expiry), isDark),
          if (active && expiry != null) SubUi.body("Buying again now adds the new period after this date.".tr, isDark),
        ],
      ),
    );
  }

  bool get _lifetime => CustomerPlanService.hasFullHistory(_user) && CustomerPlanService.expiryOf(_user) == null;

  List<Widget> _planCards(bool isDark) {
    if (_plans.isEmpty) return [SubUi.empty("No plan is offered in your region yet.".tr, isDark)];
    return _plans.map((p) {
      return SubUi.card(
        isDark,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SubUi.title(p.name, isDark)),
                Text(
                  "${Constant.amountShow(amount: p.price, currency: CustomerPlanService.currency)} / ${p.periodLabel}",
                  style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: AppThemeData.primary300),
                ),
              ],
            ),
            if (p.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: SubUi.body(p.description, isDark)),
            ...p.points.map((e) => Padding(padding: const EdgeInsets.only(top: 2), child: SubUi.body("• $e", isDark))),
            const SizedBox(height: 10),
            RoundedButtonFill(
              title: _lifetime ? "You already have lifetime access".tr : (CustomerPlanService.hasFullHistory(_user) ? "Renew".tr : "Subscribe".tr),
              height: 5,
              color: _lifetime ? AppThemeData.grey400 : AppThemeData.primary300,
              textColor: AppThemeData.grey50,
              fontSizes: 14,
              onPress: _lifetime ? null : () => _buy(p),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _historyCards(bool isDark) {
    if (_history.isEmpty) return [SubUi.empty("No purchases yet.".tr, isDark)];
    return _history.map((h) {
      final plan = Map<String, dynamic>.from(h['subscription_plan'] as Map);
      final createdAt = h['createdAt'];
      final expiry = h['expiry_date'];
      final currency = RegionService.currencyForRecord(h['regionId']?.toString());
      return SubUi.card(
        isDark,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: SubUi.title(plan['name']?.toString() ?? '-', isDark)), Text(Constant.amountShow(amount: plan['price']?.toString() ?? '0', currency: currency), style: TextStyle(fontFamily: AppThemeData.semiBold, color: SubUi.text(isDark)))]),
            const SizedBox(height: 4),
            SubUi.row("Invoice no.".tr, h['id']?.toString() ?? '-', isDark),
            SubUi.row("Date".tr, createdAt is Timestamp ? Constant.timestampToDateTime(createdAt) : '-', isDark),
            SubUi.row("Period".tr, CustomerPlanService.periodLabel(plan['expiryDay']?.toString() ?? ''), isDark),
            SubUi.row("Valid until".tr, expiry is Timestamp ? Constant.timestampToDate(expiry) : "Never expires".tr, isDark),
            SubUi.row("Paid with".tr, (h['payment_type']?.toString() ?? '-').capitalizeFirst ?? '-', isDark),
          ],
        ),
      );
    }).toList();
  }
}
