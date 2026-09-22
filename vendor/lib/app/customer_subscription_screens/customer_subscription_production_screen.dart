import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/customer_subscription_controller.dart';
import 'package:vendor/controller/customer_subscription_production_controller.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_subscription_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/customer_subscription_service.dart';
import 'package:vendor/widget/my_separator.dart';

/// Daily production list for Customer Subscriptions: what to prepare and
/// deliver on a chosen day for every active subscriber, grouped by plan.
class CustomerSubscriptionProductionScreen extends StatelessWidget {
  const CustomerSubscriptionProductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    final onBar = isDark ? AppThemeData.grey800 : AppThemeData.grey100;
    return GetX(
      init: CustomerSubscriptionProductionController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: IconThemeData(color: onBar, size: 20),
            title: Text(
              "Daily production list".tr,
              style: TextStyle(color: onBar, fontSize: 18, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
            ),
          ),
          body: Column(
            children: [
              _dateBar(context, controller, isDark),
              Expanded(
                child: controller.isLoading.value
                    ? Constant.loader()
                    : RefreshIndicator(
                        onRefresh: controller.load,
                        child: _content(controller, isDark),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dateBar(BuildContext context, CustomerSubscriptionProductionController controller, bool isDark) {
    final date = controller.selectedDate.value;
    final textColor = isDark ? AppThemeData.grey50 : AppThemeData.grey900;
    return Container(
      color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(tooltip: "Previous day".tr, onPressed: controller.previousDay, icon: Icon(Icons.chevron_left, color: textColor)),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(date.year - 2),
                  lastDate: DateTime(date.year + 2, 12, 31),
                );
                if (picked != null) controller.setDate(picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      controller.isToday ? "Today".tr : DateFormat('EEEE').format(date).tr,
                      style: TextStyle(color: AppThemeData.primary300, fontSize: 12, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEE, MMM dd, yyyy').format(date),
                      style: TextStyle(color: textColor, fontSize: 16, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(tooltip: "Next day".tr, onPressed: controller.nextDay, icon: Icon(Icons.chevron_right, color: textColor)),
          if (!controller.isToday)
            TextButton(
              onPressed: () => controller.setDate(DateTime.now()),
              child: Text(
                "Today".tr,
                style: TextStyle(color: AppThemeData.primary300, fontSize: 13, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(CustomerSubscriptionProductionController controller, bool isDark) {
    if (controller.groups.isEmpty && controller.unscheduled.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(child: Constant.showEmptyView(message: "No subscription deliveries on this day".tr, isDark: isDark)),
            ),
          ),
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 10, bottom: 24),
      children: [
        if (controller.groups.isNotEmpty) _summaryCard(controller),
        ...controller.groups.map((g) => _planCard(g, isDark)),
        if (controller.unscheduled.isNotEmpty) _unscheduledCard(controller.unscheduled, isDark),
      ],
    );
  }

  Widget _summaryCard(CustomerSubscriptionProductionController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        width: double.infinity,
        decoration: ShapeDecoration(color: AppThemeData.primary300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "To prepare".tr,
              style: const TextStyle(color: AppThemeData.grey50, fontSize: 14, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              "${controller.deliveryCount} ${"deliveries".tr}",
              style: const TextStyle(color: AppThemeData.grey50, fontSize: 22, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
            ),
            if (controller.overallTotals.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.overallTotals.map((t) => _qtyChip(t, AppThemeData.grey50, AppThemeData.grey50.withValues(alpha: 0.18))).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planCard(ProductionPlanGroup group, bool isDark) {
    final count = group.deliveries.length;
    return _card(
      isDark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                count == 1 ? "1 subscriber".tr : "@count subscribers".trParams({'count': count.toString()}),
                style: TextStyle(color: AppThemeData.primary300, fontSize: 13, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (group.totals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.totals.map((t) => _qtyChip(t, AppThemeData.primary300, AppThemeData.primary300.withValues(alpha: 0.12))).toList(),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
          ),
          Text(
            "Deliveries".tr,
            style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 13, fontFamily: AppThemeData.medium, fontWeight: FontWeight.w500),
          ),
          ...group.deliveries.map((s) => _deliveryRow(s, isDark)),
        ],
      ),
    );
  }

  Widget _unscheduledCard(List<VendorSubscriptionModel> subs, bool isDark) {
    return _card(
      isDark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppThemeData.warning400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "No delivery schedule".tr,
                  style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                "${subs.length}",
                style: const TextStyle(color: AppThemeData.warning400, fontSize: 13, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Active subscribers whose plan was bought before it had items, days and a time slot. Check with them what to deliver.".tr,
            style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 12, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
          ),
          ...subs.map((s) => _deliveryRow(s, isDark, showPlan: true)),
        ],
      ),
    );
  }

  Widget _deliveryRow(VendorSubscriptionModel sub, bool isDark, {bool showPlan = false}) {
    final secondary = isDark ? AppThemeData.grey300 : AppThemeData.grey600;
    final slot = sub.plan?.timeSlot?.isSet == true ? sub.plan!.timeSlot!.label : '';
    return FutureBuilder<UserModel?>(
      future: CustomerSubscriptionService.getCustomer(sub.customerId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final name = user == null ? '' : user.fullName().trim();
        final phone = user == null || (user.phoneNumber ?? '').isEmpty ? '' : "${user.countryCode ?? ''} ${user.phoneNumber}".trim();
        final address = sub.deliveryAddress ?? CustomerSubscriptionService.customerAddress(user) ?? '';
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiting ? "Loading...".tr : (name.isEmpty ? "Unknown customer".tr : name),
                      style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 14, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                    ),
                    if (showPlan && (sub.plan?.title ?? '').isNotEmpty) _line(Icons.card_membership, sub.plan!.title!, secondary),
                    if (phone.isNotEmpty) _line(Icons.phone_outlined, phone, secondary),
                    if (address.isNotEmpty) _line(Icons.location_on_outlined, address, secondary),
                    if (sub.plan != null && sub.plan!.items.isNotEmpty && showPlan) _line(Icons.inventory_2_outlined, CustomerSubscriptionController.itemsLabel(sub.plan!.items), secondary),
                  ],
                ),
              ),
              if (slot.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppThemeData.primary300.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    slot,
                    style: TextStyle(color: AppThemeData.primary300, fontSize: 12, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _line(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyChip(ProductionItemTotal total, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(
        "${total.name} × ${CustomerSubscriptionController.formatQuantity(total.quantity)}",
        style: TextStyle(color: foreground, fontSize: 13, fontFamily: AppThemeData.semiBold, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _card(bool isDark, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        decoration: ShapeDecoration(
          color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }
}
