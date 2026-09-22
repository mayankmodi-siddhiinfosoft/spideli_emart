import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/models/vendor_subscription_model.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/subscriptions/gateway_checkout_screen.dart';
import 'package:customer/screen_ui/subscriptions/my_store_subscriptions_screen.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/network_image_widget.dart';
import 'package:customer/utils/region_service.dart';
import 'package:customer/utils/store_subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Human text for a plan's schedule ("Daily · Mon - Sat · 07:00 - 09:00").
String storePlanScheduleText(VendorSubscriptionPlanModel plan) {
  final parts = <String>[];
  if (plan.frequency == VendorSubscriptionPlanModel.frequencyDaily) parts.add("Daily".tr);
  if (plan.frequency == VendorSubscriptionPlanModel.frequencyWeekly) parts.add("Weekly".tr);
  final days = plan.effectiveDeliveryDays;
  if (days.length == 7) {
    parts.add("Every day".tr);
  } else if (days.isNotEmpty) {
    parts.add(days.map((d) => d.substring(0, 3).tr).join(', '));
  }
  if (plan.timeSlot?.isSet == true) parts.add(plan.timeSlot!.label);
  return parts.join('  ·  ');
}

String storePlanItemsText(VendorSubscriptionPlanModel plan) => plan.items.map((i) => "${i.name} × ${i.quantity ?? '1'}").join(', ');

/// Store page section (spec 4.7 / 7.9): the store's enabled subscription
/// plans. Renders nothing when the store sells none.
class StorePlansSection extends StatefulWidget {
  final VendorModel vendor;

  const StorePlansSection({super.key, required this.vendor});

  @override
  State<StorePlansSection> createState() => _StorePlansSectionState();
}

class _StorePlansSectionState extends State<StorePlansSection> {
  List<VendorSubscriptionPlanModel> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plans = await StoreSubscriptionService.plansForStore(widget.vendor.id ?? '');
      if (mounted) setState(() => _plans = plans);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_plans.isEmpty) return const SizedBox();
    final isDark = Get.find<ThemeController>().isDark.value;
    final currency = RegionService.currencyForVendor(widget.vendor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text("Subscriptions".tr, style: TextStyle(fontSize: 16, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600, color: SubUi.text(isDark))),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _plans.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final plan = _plans[index];
              return InkWell(
                onTap: () => Get.to(() => StoreSubscribeScreen(plan: plan, vendor: widget.vendor)),
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.title ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontFamily: AppThemeData.semiBold, color: SubUi.text(isDark))),
                      const SizedBox(height: 4),
                      Text(
                        "${Constant.amountShow(amount: plan.price, currency: currency)} / ${StoreSubscriptionService.periodLabel(plan.expiryDay).tr}",
                        style: TextStyle(fontSize: 14, fontFamily: AppThemeData.semiBold, color: AppThemeData.primary300),
                      ),
                      const SizedBox(height: 6),
                      if (plan.items.isNotEmpty) Text(storePlanItemsText(plan), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: SubUi.muted(isDark))),
                      if (plan.hasSchedule) Text(storePlanScheduleText(plan), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: SubUi.muted(isDark))),
                      const Spacer(),
                      Text("Subscribe".tr, style: TextStyle(fontSize: 14, fontFamily: AppThemeData.semiBold, color: AppThemeData.primary300)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Plan details, delivery address and start date, then payment.
class StoreSubscribeScreen extends StatefulWidget {
  final VendorSubscriptionPlanModel plan;
  final VendorModel vendor;

  const StoreSubscribeScreen({super.key, required this.plan, required this.vendor});

  @override
  State<StoreSubscribeScreen> createState() => _StoreSubscribeScreenState();
}

class _StoreSubscribeScreenState extends State<StoreSubscribeScreen> {
  ShippingAddress? _address;
  late DateTime _start;
  VendorSubscriptionModel? _current;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day + 1);
    final selected = Constant.selectedLocation;
    if ((selected.address ?? '').isNotEmpty || selected.location != null) _address = selected;
    _loadCurrent();
  }

  /// A renewal starts when the running subscription ends (new document for
  /// the same customer + plan).
  Future<void> _loadCurrent() async {
    try {
      final current = await StoreSubscriptionService.currentFor(widget.plan.id ?? '');
      if (!mounted) return;
      setState(() {
        _current = current;
        final end = current?.expiryDate?.toDate();
        if (end != null && end.isAfter(_start)) _start = DateTime(end.year, end.month, end.day);
      });
    } catch (_) {}
  }

  Future<void> _pickAddress() async {
    final value = await Get.to(const AddressListScreen());
    if (value is ShippingAddress) setState(() => _address = value);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(_start.year + 1, _start.month, _start.day));
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pay() async {
    if (Constant.userModel == null) {
      ShowToastDialog.showToast("Please log in to subscribe".tr);
      return;
    }
    if (_address == null) {
      ShowToastDialog.showToast("Please select a delivery address".tr);
      return;
    }
    final plan = widget.plan;
    final vendor = widget.vendor;
    final regionId = RegionService.regionOfVendor(vendor) ?? plan.regionId;
    ShowToastDialog.showLoader("Please wait...".tr);
    final commission = await StoreSubscriptionService.commissionFor(vendor.id ?? '', plan.priceValue);
    ShowToastDialog.closeLoader();
    final result = await Get.to(
      () => GatewayCheckoutScreen(
        title: "${vendor.title ?? ''} - ${plan.title ?? ''}",
        amount: plan.price ?? '0',
        currency: RegionService.currencyForVendor(vendor),
        regionId: regionId,
        onPaid: (method) => StoreSubscriptionService.recordPurchase(plan: plan, vendor: vendor, address: _address!, startDate: _start, paymentMethod: method, commission: commission),
      ),
    );
    if (result == true) {
      ShowToastDialog.showToast("Subscribed successfully".tr);
      Get.off(() => const MyStoreSubscriptionsScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    final plan = widget.plan;
    final currency = RegionService.currencyForVendor(widget.vendor);
    final DateTime? end = plan.expiryDays > 0 ? _start.add(Duration(days: plan.expiryDays)) : null;
    return Scaffold(
      backgroundColor: SubUi.surface(isDark),
      appBar: SubUi.appBar("Subscribe".tr, isDark),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if ((plan.photo ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: NetworkImageWidget(imageUrl: plan.photo!, height: 160, width: double.infinity, fit: BoxFit.cover)),
            ),
          SubUi.card(
            isDark,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SubUi.title(plan.title ?? '-', isDark),
                const SizedBox(height: 4),
                Text(
                  "${Constant.amountShow(amount: plan.price, currency: currency)} / ${StoreSubscriptionService.periodLabel(plan.expiryDay).tr}",
                  style: TextStyle(fontSize: 16, fontFamily: AppThemeData.semiBold, color: AppThemeData.primary300),
                ),
                if ((plan.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: SubUi.body(plan.description!, isDark)),
                const SizedBox(height: 8),
                SubUi.row("Store".tr, widget.vendor.title ?? '-', isDark),
                if (plan.items.isNotEmpty) SubUi.row("Each delivery".tr, storePlanItemsText(plan), isDark),
                if (plan.frequency != null) SubUi.row("Frequency".tr, plan.frequency == VendorSubscriptionPlanModel.frequencyDaily ? "Daily".tr : "Weekly".tr, isDark),
                if (plan.effectiveDeliveryDays.isNotEmpty) SubUi.row("Delivery days".tr, plan.effectiveDeliveryDays.map((d) => d.tr).join(', '), isDark),
                if (plan.timeSlot?.isSet == true) SubUi.row("Time slot".tr, plan.timeSlot!.label, isDark),
              ],
            ),
          ),
          if (_current != null)
            SubUi.card(isDark, SubUi.body("${"You already have this plan until".tr} ${_current!.expiryDate == null ? '-' : Constant.timestampToDate(_current!.expiryDate!)}. ${"This purchase renews it from that date.".tr}", isDark)),
          SubUi.heading("Delivery address".tr, isDark),
          SubUi.card(
            isDark,
            InkWell(
              onTap: _pickAddress,
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, color: AppThemeData.primary300),
                  const SizedBox(width: 8),
                  Expanded(child: SubUi.body(_address == null ? "Select a delivery address".tr : _address!.getFullAddress(), isDark)),
                  Icon(Icons.keyboard_arrow_right, color: SubUi.muted(isDark)),
                ],
              ),
            ),
          ),
          SubUi.heading("Start date".tr, isDark),
          SubUi.card(
            isDark,
            InkWell(
              onTap: _pickDate,
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: AppThemeData.primary300),
                  const SizedBox(width: 8),
                  Expanded(child: SubUi.body("${VendorSubscriptionModel.dayFormat.format(_start)}${end == null ? '' : "  →  ${VendorSubscriptionModel.dayFormat.format(end)}"}", isDark)),
                  Icon(Icons.keyboard_arrow_right, color: SubUi.muted(isDark)),
                ],
              ),
            ),
          ),
          SubUi.body("Payment is for one period. Renewal is manual: buy again before it ends. You can pause, skip a day or cancel from Profile > My subscriptions.".tr, isDark),
        ],
      ),
      bottomNavigationBar: Container(
        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        child: RoundedButtonFill(title: "Continue to payment".tr, height: 5.5, color: AppThemeData.primary300, textColor: AppThemeData.grey50, fontSizes: 16, onPress: _pay),
      ),
    );
  }
}
