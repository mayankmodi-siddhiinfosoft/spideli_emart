import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/customer_subscription_screens/add_edit_customer_subscription_plan_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/utils/region_service.dart';
import 'package:vendor/controller/customer_subscription_controller.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_subscription_model.dart';
import 'package:vendor/models/vendor_subscription_payment_model.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/custom_dialog_box.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/customer_subscription_service.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/my_separator.dart';

/// "Customer Subscriptions": plans this store sells to its OWN customers,
/// their subscribers and payments. Separate from the platform subscription the
/// store itself buys (SubscriptionPlanScreen).
class CustomerSubscriptionScreen extends StatefulWidget {
  const CustomerSubscriptionScreen({super.key});

  @override
  State<CustomerSubscriptionScreen> createState() => _CustomerSubscriptionScreenState();
}

class _CustomerSubscriptionScreenState extends State<CustomerSubscriptionScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: CustomerSubscriptionController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            iconTheme: IconThemeData(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, size: 20),
            title: Text(
              "Customer Subscriptions".tr,
              style: TextStyle(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: TextStyle(fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
              labelColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              unselectedLabelStyle: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
              unselectedLabelColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              indicatorColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: "Plans".tr),
                Tab(text: "Subscribers".tr),
                Tab(text: "Payments".tr),
              ],
            ),
          ),
          body: TabBarView(controller: _tabController, children: [_plansTab(context, controller, isDark), _subscribersTab(controller, isDark), _paymentsTab(controller, isDark)]),
          floatingActionButton: _tabController.index == 0
              ? FloatingActionButton(
                  shape: const CircleBorder(),
                  backgroundColor: AppThemeData.primary300,
                  onPressed: () {
                    Get.to(const AddEditCustomerSubscriptionPlanScreen())!.then((value) {
                      if (value == true) controller.getPlans();
                    });
                  },
                  child: const Icon(Icons.add, color: AppThemeData.grey50),
                )
              : null,
        );
      },
    );
  }

  // ------------------------------------------------------------------ Plans

  Widget _plansTab(BuildContext context, CustomerSubscriptionController controller, bool isDark) {
    if (controller.isPlansLoading.value) return Constant.loader();
    if (controller.planList.isEmpty) {
      return RefreshIndicator(onRefresh: controller.getPlans, child: _scrollableEmpty("No customer subscription plans yet. Tap + to create one.".tr, isDark));
    }
    return RefreshIndicator(
      onRefresh: controller.getPlans,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 10, bottom: 80),
        itemCount: controller.planList.length,
        itemBuilder: (context, index) {
          final VendorSubscriptionPlanModel plan = controller.planList[index];
          return _card(
            isDark,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: NetworkImageWidget(imageUrl: plan.photo ?? '', height: 72, width: 72),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.title ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.semiBold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${_money(plan.price)} / ${CustomerSubscriptionController.periodLabel(plan.expiryDay)}",
                            style: TextStyle(color: AppThemeData.primary300, fontSize: 14, fontFamily: AppThemeData.medium),
                          ),
                        ],
                      ),
                    ),
                    _iconButton(isDark, SvgPicture.asset("assets/icons/ic_edit_coupon.svg"), () {
                      Get.to(const AddEditCustomerSubscriptionPlanScreen(), arguments: {"planModel": plan})!.then((value) {
                        if (value == true) controller.getPlans();
                      });
                    }),
                    const SizedBox(width: 10),
                    _iconButton(isDark, SvgPicture.asset("assets/icons/ic_delete-one.svg"), () {
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return CustomDialogBox(
                            title: "Delete Plan".tr,
                            descriptions: "Are you sure you want to delete this plan? Existing subscribers keep their current subscription.".tr,
                            positiveString: "Delete".tr,
                            negativeString: "Cancel".tr,
                            positiveClick: () async {
                              Get.back();
                              await controller.deletePlan(plan);
                            },
                            negativeClick: () {
                              Get.back();
                            },
                          );
                        },
                      );
                    }),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (plan.isEnable ?? true) ? "Enabled".tr : "Disabled".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 14, fontFamily: AppThemeData.medium),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: CupertinoSwitch(value: plan.isEnable ?? true, activeTrackColor: AppThemeData.primary300, onChanged: (value) => controller.togglePlan(plan, value)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ Subscribers (read-only)

  Widget _subscribersTab(CustomerSubscriptionController controller, bool isDark) {
    if (controller.isSubscribersLoading.value) return Constant.loader();
    if (controller.subscriberList.isEmpty) {
      return RefreshIndicator(onRefresh: controller.getSubscribers, child: _scrollableEmpty("No subscribers yet".tr, isDark));
    }
    return RefreshIndicator(
      onRefresh: controller.getSubscribers,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: controller.subscriberList.length,
        itemBuilder: (context, index) {
          final VendorSubscriptionModel sub = controller.subscriberList[index];
          final status = sub.effectiveStatus;
          return _card(
            isDark,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _customerInfo(sub.customerId, isDark)),
                    _statusChip(status, isDark),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                ),
                // Plan title/price come from the stored snapshot, never the live plan.
                _labelValue("Plan".tr, sub.plan?.title ?? '-', isDark),
                _labelValue("Price".tr, sub.plan?.price == null ? '-' : "${_money(sub.plan!.price, regionId: sub.regionId)} / ${CustomerSubscriptionController.periodLabel(sub.plan!.expiryDay)}", isDark),
                _labelValue("Start date".tr, sub.startDate == null ? '-' : Constant.timestampToDate(sub.startDate!), isDark),
                _labelValue("Expiry date".tr, sub.expiryDate == null ? '-' : Constant.timestampToDate(sub.expiryDate!), isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ Payments (read-only)

  Widget _paymentsTab(CustomerSubscriptionController controller, bool isDark) {
    if (controller.isPaymentsLoading.value) return Constant.loader();
    if (controller.paymentList.isEmpty) {
      return RefreshIndicator(onRefresh: controller.getPayments, child: _scrollableEmpty("No payments yet".tr, isDark));
    }
    return RefreshIndicator(
      onRefresh: controller.getPayments,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: controller.paymentList.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Container(
                width: double.infinity,
                decoration: ShapeDecoration(
                  color: AppThemeData.primary300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total earned".tr,
                      style: const TextStyle(color: AppThemeData.grey50, fontSize: 14, fontFamily: AppThemeData.medium),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _money(controller.totalEarned.toString()),
                      style: const TextStyle(color: AppThemeData.grey50, fontSize: 24, fontFamily: AppThemeData.semiBold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${controller.paymentList.length} ${"payments".tr}",
                      style: const TextStyle(color: AppThemeData.grey50, fontSize: 12, fontFamily: AppThemeData.regular),
                    ),
                  ],
                ),
              ),
            );
          }
          final VendorSubscriptionPaymentModel payment = controller.paymentList[index - 1];
          return _card(
            isDark,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _customerInfo(payment.customerId, isDark)),
                    Text(
                      _money(payment.amount, regionId: payment.regionId),
                      style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.semiBold),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
                ),
                _labelValue("Amount".tr, _money(payment.amount, regionId: payment.regionId), isDark),
                _labelValue("Admin commission".tr, _money(payment.adminCommission, regionId: payment.regionId), isDark),
                if ((payment.adminCommissionType ?? '').isNotEmpty) _labelValue("Commission type".tr, payment.adminCommissionType!.capitalizeFirst ?? payment.adminCommissionType!, isDark),
                _labelValue("Store earning".tr, _money(payment.vendorEarning, regionId: payment.regionId), isDark, valueColor: AppThemeData.success400),
                _labelValue("Payment method".tr, (payment.paymentMethod ?? '').isEmpty ? '-' : payment.paymentMethod!, isDark),
                if ((payment.status ?? '').isNotEmpty) _labelValue("Status".tr, payment.status!.capitalizeFirst ?? payment.status!, isDark),
                _labelValue("Date".tr, payment.createdAt == null ? '-' : Constant.timestampToDateTime(payment.createdAt!), isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ Helpers

  /// Formats a stored amount string; tolerates empty / malformed values from other clients.
  ///
  /// [regionId] is the record's own region: a payment or subscription keeps the
  /// currency it was charged in, like an order.
  String _money(String? amount, {String? regionId}) {
    return Constant.amountShow(
      currency: regionId == null ? null : RegionService.currencyForOrder(regionId),
      amount: (double.tryParse(amount?.trim() ?? '') ?? 0).toString(),
    );
  }

  Widget _scrollableEmpty(String message, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Constant.showEmptyView(message: message, isDark: isDark),
            ),
          ),
        ),
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

  Widget _iconButton(bool isDark, Widget icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100),
            borderRadius: BorderRadius.circular(120),
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(8.0), child: icon),
      ),
    );
  }

  Widget _labelValue(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 14, fontFamily: AppThemeData.regular),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: valueColor ?? (isDark ? AppThemeData.grey50 : AppThemeData.grey900), fontSize: 14, fontFamily: AppThemeData.medium),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, bool isDark) {
    Color color;
    switch (status) {
      case 'active':
        color = AppThemeData.success400;
        break;
      case 'cancelled':
        color = AppThemeData.danger300;
        break;
      default:
        color = isDark ? AppThemeData.grey400 : AppThemeData.grey500;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        (status.capitalizeFirst ?? status).tr,
        style: TextStyle(color: color, fontSize: 12, fontFamily: AppThemeData.semiBold),
      ),
    );
  }

  /// Customer name/phone, looked up lazily from users/{customerId}; tolerates a
  /// missing or deleted user.
  Widget _customerInfo(String? customerId, bool isDark) {
    return FutureBuilder<UserModel?>(
      future: CustomerSubscriptionService.getCustomer(customerId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user == null ? '' : user.fullName().trim();
        final phone = user == null || (user.phoneNumber ?? '').isEmpty ? '' : "${user.countryCode ?? ''} ${user.phoneNumber}".trim();
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              waiting ? "Loading...".tr : (name.isEmpty ? "Unknown customer".tr : name),
              style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 16, fontFamily: AppThemeData.semiBold),
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                phone,
                style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600, fontSize: 13, fontFamily: AppThemeData.regular),
              ),
            ],
          ],
        );
      },
    );
  }
}
