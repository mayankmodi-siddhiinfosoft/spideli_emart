import 'package:customer/constant/constant.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/models/vendor_subscription_model.dart';
import 'package:customer/screen_ui/location_enable_screens/address_list_screen.dart';
import 'package:customer/screen_ui/subscriptions/gateway_checkout_screen.dart';
import 'package:customer/screen_ui/subscriptions/my_store_subscriptions_screen.dart';
import 'package:customer/screen_ui/subscriptions/subscription_ui.dart';
import 'package:customer/themes/ds/ds.dart';
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
///
/// Archetype **A — rail**: a horizontal card rail under a DS section header.
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
    final c = context.dsColors;
    final t = context.dsText;
    final currency = RegionService.currencyForVendor(widget.vendor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsSectionHeader(title: "Subscriptions".tr, icon: Icons.event_repeat_rounded, subtitle: "Get it delivered again and again.".tr),
        SizedBox(
          height: 186,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: DsSpace.xs),
            itemCount: _plans.length,
            separatorBuilder: (context, index) => const DsGap(DsSpace.md),
            itemBuilder: (context, index) {
              final plan = _plans[index];
              return DsFadeSlideIn(
                index: index,
                offset: const Offset(16, 0),
                child: SizedBox(
                  width: 254,
                  child: DsCard.outlined(
                    padding: const EdgeInsets.all(DsSpace.md),
                    onTap: () => Get.to(() => StoreSubscribeScreen(plan: plan, vendor: widget.vendor)),
                    semanticLabel: plan.title ?? '-',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DsIconWell(icon: Icons.event_repeat_rounded, tone: DsTone.brand, size: 36),
                            const DsGap(DsSpace.sm),
                            Expanded(child: Text(plan.title ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm)),
                          ],
                        ),
                        const DsGap(DsSpace.sm),
                        SubUi.price(context, "${Constant.amountShow(amount: plan.price, currency: currency)} / ${StoreSubscriptionService.periodLabel(plan.expiryDay).tr}"),
                        const DsGap(DsSpace.xs),
                        if (plan.items.isNotEmpty) Text(storePlanItemsText(plan), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySm),
                        if (plan.hasSchedule)
                          Padding(
                            padding: const EdgeInsets.only(top: DsSpace.xxs),
                            child: Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 14, color: c.textMuted),
                                const DsGap(DsSpace.xs),
                                Expanded(child: Text(storePlanScheduleText(plan), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption)),
                              ],
                            ),
                          ),
                        const Spacer(),
                        Row(
                          children: [
                            Text("Subscribe".tr, style: t.label.withColor(c.brandStrong)),
                            const DsGap(DsSpace.xs),
                            Icon(Icons.arrow_forward_rounded, size: 16, color: c.brandStrong),
                          ],
                        ),
                      ],
                    ),
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
///
/// Archetype **E — booking wizard**: plan summary, then the two choices the
/// customer makes (address, start date) as picker rows, with Continue in a
/// sticky bar.
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

  /// Until the running subscription is known, paying could overlap it.
  bool _loadingCurrent = true;

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
        _start = _clampStart(_start);
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingCurrent = false);
  }

  /// Earliest allowed start: today, or the running subscription's expiry day
  /// (a renewal must not overlap it).
  DateTime get _minStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = _current?.expiryDate?.toDate();
    if (end == null) return today;
    final endDay = DateTime(end.year, end.month, end.day);
    return endDay.isAfter(today) ? endDay : today;
  }

  DateTime _clampStart(DateTime value) {
    final min = _minStart;
    return value.isBefore(min) ? min : value;
  }

  Future<void> _pickAddress() async {
    final value = await Get.to(const AddressListScreen());
    if (value is ShippingAddress) setState(() => _address = value);
  }

  Future<void> _pickDate() async {
    final first = _minStart;
    final initial = _clampStart(_start);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: DateTime(initial.year + 1, initial.month, initial.day));
    if (picked != null) setState(() => _start = _clampStart(picked));
  }

  Future<void> _pay() async {
    if (_loadingCurrent) return;
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
    // Never overlap the running subscription, whatever was picked earlier.
    final clamped = _clampStart(_start);
    if (clamped != _start) setState(() => _start = clamped);
    final DateTime startDate = _start;
    ShowToastDialog.showLoader("Please wait...".tr);
    final commission = await StoreSubscriptionService.commissionFor(vendor.id ?? '', plan.priceValue);
    ShowToastDialog.closeLoader();
    final result = await Get.to(
      () => GatewayCheckoutScreen(
        title: "${vendor.title ?? ''} - ${plan.title ?? ''}",
        amount: plan.price ?? '0',
        currency: RegionService.currencyForVendor(vendor),
        regionId: regionId,
        onPaid: (method) => StoreSubscriptionService.recordPurchase(plan: plan, vendor: vendor, address: _address!, startDate: startDate, paymentMethod: method, commission: commission),
      ),
    );
    if (result == true) {
      ShowToastDialog.showToast("Subscribed successfully".tr);
      Get.off(() => const MyStoreSubscriptionsScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final plan = widget.plan;
    final currency = RegionService.currencyForVendor(widget.vendor);
    final DateTime? end = plan.expiryDays > 0 ? _start.add(Duration(days: plan.expiryDays)) : null;
    return DsScaffold(
      title: "Subscribe".tr,
      maxContentWidth: DsLayout.contentMax,
      bottomBar: DsStickyBar(
        child: DsButton.primary(
          label: "Continue to payment".tr,
          size: DsButtonSize.lg,
          expand: true,
          icon: Icons.arrow_forward_rounded,
          onPressed: _loadingCurrent ? null : _pay,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
        children: DsFadeSlideIn.stagger([
          if ((plan.photo ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.md),
              child: ClipRRect(borderRadius: DsRadius.brLg, child: NetworkImageWidget(imageUrl: plan.photo!, height: 170, width: double.infinity, fit: BoxFit.cover)),
            ),
          SubUi.card(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SubUi.title(context, plan.title ?? '-')),
                    const DsGap(DsSpace.sm),
                    SubUi.price(context, "${Constant.amountShow(amount: plan.price, currency: currency)} / ${StoreSubscriptionService.periodLabel(plan.expiryDay).tr}"),
                  ],
                ),
                if ((plan.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: DsSpace.xs), child: SubUi.body(context, plan.description!)),
                const DsGap(DsSpace.md),
                SubUi.row(context, "Store".tr, widget.vendor.title ?? '-'),
                if (plan.items.isNotEmpty) SubUi.row(context, "Each delivery".tr, storePlanItemsText(plan)),
                if (plan.frequency != null) SubUi.row(context, "Frequency".tr, plan.frequency == VendorSubscriptionPlanModel.frequencyDaily ? "Daily".tr : "Weekly".tr),
                if (plan.effectiveDeliveryDays.isNotEmpty) SubUi.row(context, "Delivery days".tr, plan.effectiveDeliveryDays.map((d) => d.tr).join(', ')),
                if (plan.timeSlot?.isSet == true) SubUi.row(context, "Time slot".tr, plan.timeSlot!.label),
              ],
            ),
          ),
          if (_current != null)
            DsInlineAlert(
              tone: DsTone.info,
              icon: Icons.event_available_outlined,
              message: "${"You already have this plan until".tr} ${_current!.expiryDate == null ? '-' : Constant.timestampToDate(_current!.expiryDate!)}. ${"This purchase renews it from that date.".tr}",
            ),
          SubUi.heading(context, "Delivery address".tr, icon: Icons.location_on_outlined),
          _PickerRow(
            icon: Icons.location_on_outlined,
            text: _address == null ? "Select a delivery address".tr : _address!.getFullAddress(),
            placeholder: _address == null,
            onTap: _pickAddress,
          ),
          SubUi.heading(context, "Start date".tr, icon: Icons.calendar_month_outlined),
          _PickerRow(
            icon: Icons.calendar_month_outlined,
            text: "${VendorSubscriptionModel.dayFormat.format(_start)}${end == null ? '' : "  →  ${VendorSubscriptionModel.dayFormat.format(end)}"}",
            onTap: _pickDate,
          ),
          const DsGap(DsSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: c.textMuted),
              const DsGap(DsSpace.sm),
              Expanded(
                child: Text(
                  "Payment is for one period. Renewal is manual: buy again before it ends. You can pause, skip a day or cancel from Profile > My subscriptions.".tr,
                  style: t.caption,
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Tappable address / date row.
class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool placeholder;
  final VoidCallback onTap;

  const _PickerRow({required this.icon, required this.text, required this.onTap, this.placeholder = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      padding: const EdgeInsets.all(DsSpace.md),
      onTap: onTap,
      semanticLabel: text,
      child: Row(
        children: [
          DsIconWell(icon: icon, tone: DsTone.brand, size: 40),
          const DsGap(DsSpace.md),
          Expanded(child: Text(text, style: placeholder ? t.bodySecondary : t.bodyStrong)),
          const DsGap(DsSpace.sm),
          Icon(Icons.keyboard_arrow_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}
