import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/section_model.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/subscription_plan_screen/select_payment_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/subscription_controller.dart';
import 'package:vendor/models/subscription_plan_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/utils/network_image_widget.dart';

class SubscriptionPlanScreen extends StatelessWidget {
  const SubscriptionPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: SubscriptionController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            titleSpacing: 0,
            iconTheme: const IconThemeData(color: AppThemeData.grey50, size: 20),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Choose Your Business Plan".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 24, fontFamily: AppThemeData.semiBold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Select the most suitable business plan for your store to maximize your potential and access exclusive features.".tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? AppThemeData.grey400 : AppThemeData.grey500, fontSize: 14, fontFamily: AppThemeData.regular),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        controller.userModel.value.sectionId != null && controller.userModel.value.sectionId!.isNotEmpty
                            ? InkWell(
                                onTap: () {
                                  ShowToastDialog.showToast("cannot_change_section".trArgs([controller.selectedSectionModel.value.name ?? '']));
                                },
                                child: TextFieldWidget(
                                  readOnly: true,
                                  title: 'Section'.tr,
                                  controller: null,
                                  hintText: 'Section Name'.tr,
                                  initialValue: controller.selectedSectionModel.value.name,
                                  enable: false,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Section".tr,
                                    style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                                  ),
                                  SizedBox(height: 10),
                                  DropdownButtonFormField<SectionModel>(
                                    isExpanded: true,
                                    dropdownColor: isDark ? AppThemeData.grey600 : AppThemeData.grey50,
                                    decoration: InputDecoration(
                                      errorStyle: const TextStyle(color: Colors.red),
                                      isDense: true,
                                      filled: true,
                                      fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                      disabledBorder: UnderlineInputBorder(
                                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                                        borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                                        borderSide: BorderSide(color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, width: 1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                                        borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                                        borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                                        borderSide: BorderSide(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, width: 1),
                                      ),
                                    ),
                                    validator: (value) => value == null ? 'field required' : null,
                                    initialValue: controller.selectedSectionModel.value,
                                    onChanged: (value) {
                                      controller.selectedSectionModel.value = value!;
                                      controller.subscriptionPlanList.clear();
                                      controller.getSubscriptionPlanList();
                                    },
                                    style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                                    hint: Text('Select Section'.tr),
                                    items: controller.sectionsList.map((SectionModel item) {
                                      return DropdownMenuItem<SectionModel>(value: item, child: Text("${item.name} (${item.serviceType})"));
                                    }).toList(),
                                  ),
                                ],
                              ),
                        SizedBox(height: 10),
                        controller.subscriptionPlanList.isEmpty
                            ? SizedBox(
                                width: Responsive.width(100, context),
                                height: Responsive.height(50, context),
                                child: Constant.showEmptyView(message: "Subscription plan not found.".tr, isDark: isDark),
                              )
                            : ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                primary: false,
                                itemCount: controller.subscriptionPlanList.length,
                                itemBuilder: (context, index) {
                                  final subscriptionPlanModel = controller.subscriptionPlanList[index];
                                  return SubscriptionPlanWidget(
                                    onContainClick: () {
                                      controller.selectedSubscriptionPlan.value = subscriptionPlanModel;
                                      controller.totalAmount.value = double.parse(subscriptionPlanModel.price ?? '0.0');
                                      controller.update();
                                    },
                                    onClick: () {
                                      if (controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id) {
                                        if (controller.selectedSubscriptionPlan.value.type == 'free' || controller.selectedSubscriptionPlan.value.id == Constant.commissionSubscriptionID) {
                                          controller.selectedPaymentMethod.value = 'free';
                                          controller.placeOrder();
                                        } else {
                                          Get.to(const SelectPaymentScreen());
                                        }
                                      }
                                    },
                                    type: 'Plan',
                                    subscriptionPlanModel: subscriptionPlanModel,
                                  );
                                },
                              ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class FeatureItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool selectedPlan;

  const FeatureItem({super.key, required this.title, required this.isActive, required this.selectedPlan});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isActive == true
              ? SvgPicture.asset('assets/icons/ic_check.svg')
              : SvgPicture.asset('assets/icons/ic_close.svg', colorFilter: const ColorFilter.mode(AppThemeData.danger200, BlendMode.srcIn)),
          const SizedBox(width: 4),
          Text(
            title == 'chat'
                ? 'Chat'.tr
                : title == 'dineIn'
                ? "DineIn".tr
                : title == 'qrCodeGenerate'
                ? 'QR Code Generate'.tr
                : title == 'ownerMobileApp'
                ? 'Store Mobile App'.tr
                : '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontFamily: AppThemeData.medium,
              color: isDark
                  ? selectedPlan == true
                        ? AppThemeData.grey900
                        : AppThemeData.grey50
                  : selectedPlan == true
                  ? AppThemeData.grey50
                  : AppThemeData.grey900,
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionPlanWidget extends StatelessWidget {
  final VoidCallback onClick;
  final VoidCallback onContainClick;
  final String type;
  final SubscriptionPlanModel subscriptionPlanModel;

  const SubscriptionPlanWidget({super.key, required this.onClick, required this.type, required this.subscriptionPlanModel, required this.onContainClick});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return GetX(
      init: SubscriptionController(),
      builder: (controller) {
        return InkWell(
          splashColor: Colors.transparent,
          onTap: onContainClick,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? AppThemeData.grey800 : AppThemeData.grey200),
              color: controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                  ? isDark
                        ? AppThemeData.grey50
                        : AppThemeData.grey800
                  : isDark
                  ? AppThemeData.grey900
                  : AppThemeData.grey50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NetworkImageWidget(imageUrl: subscriptionPlanModel.image ?? '', fit: BoxFit.cover, width: 50, height: 50),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscriptionPlanModel.name ?? '',
                              style: TextStyle(
                                color: controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                    ? isDark
                                          ? AppThemeData.grey900
                                          : AppThemeData.grey50
                                    : isDark
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: AppThemeData.semiBold,
                              ),
                            ),
                            Text(
                              "${subscriptionPlanModel.description}",
                              maxLines: 2,
                              softWrap: true,
                              style: const TextStyle(fontFamily: AppThemeData.regular, fontSize: 14, color: AppThemeData.grey400),
                            ),
                          ],
                        ),
                      ),
                      controller.userModel.value.subscriptionPlanId == subscriptionPlanModel.id
                          ? RoundedButtonFill(title: "Active".tr, width: 18, height: 4, color: AppThemeData.success500, textColor: AppThemeData.grey50, onPress: () async {})
                          : SizedBox(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscriptionPlanModel.type == "free" ? "Free".tr : Constant.amountShow(amount: double.parse(subscriptionPlanModel.price ?? '0.0').toString()),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                              ? isDark
                                    ? AppThemeData.grey800
                                    : AppThemeData.grey200
                              : isDark
                              ? AppThemeData.grey200
                              : AppThemeData.grey800,
                          fontFamily: AppThemeData.semiBold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subscriptionPlanModel.expiryDay == "-1" ? "Lifetime".tr : "${subscriptionPlanModel.expiryDay} ${"Days".tr}",
                        style: TextStyle(
                          fontFamily: AppThemeData.medium,
                          fontSize: 14,
                          color: controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                              ? isDark
                                    ? AppThemeData.grey500
                                    : AppThemeData.grey500
                              : isDark
                              ? AppThemeData.grey500
                              : AppThemeData.grey500,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  Divider(
                    color: controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                        ? isDark
                              ? AppThemeData.grey200
                              : AppThemeData.grey700
                        : isDark
                        ? AppThemeData.grey700
                        : AppThemeData.grey200,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 0,
                    runSpacing: 12,
                    children:
                        subscriptionPlanModel.features?.toJson().entries.map((entry) {
                          return FeatureItem(title: entry.key, isActive: entry.value, selectedPlan: controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id);
                        }).toList() ??
                        [],
                  ),
                  SizedBox(height: 10),
                  if (subscriptionPlanModel.id == Constant.commissionSubscriptionID)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            '•  ',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: AppThemeData.medium,
                              color: isDark
                                  ? controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                        ? AppThemeData.grey800
                                        : AppThemeData.grey200
                                  : controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                  ? AppThemeData.grey200
                                  : AppThemeData.grey800,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              // Constant.userModel!.vendorID != null && Constant.userModel!.vendorID!.isNotEmpty
                              //     ? "Pay a commission of ${Constant.vendorAdminCommission?.commissionType == 'Percent' ? "${Constant.vendorAdminCommission?.amount} %" : "${Constant.amountShow(amount: Constant.vendorAdminCommission?.amount)} Flat"} on each order"
                              //         .tr
                              //     :
                              "${"Pay a commission of".tr} ${controller.selectedSectionModel.value.adminCommision!.commissionType == 'Percent' || controller.selectedSectionModel.value.adminCommision!.commissionType == 'percentage' ? "${controller.selectedSectionModel.value.adminCommision!.amount} %" : "${Constant.amountShow(amount: controller.selectedSectionModel.value.adminCommision!.amount)} ${'Flat'.tr}"} ${"on each order".tr}"
                                  .tr,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: AppThemeData.regular,
                                color: isDark
                                    ? controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                          ? AppThemeData.grey800
                                          : AppThemeData.grey200
                                    : controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                    ? AppThemeData.grey200
                                    : AppThemeData.grey800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: subscriptionPlanModel.planPoints?.length,
                    itemBuilder: (BuildContext? context, int index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              '•  ',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: AppThemeData.medium,
                                color: isDark
                                    ? controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                          ? AppThemeData.grey800
                                          : AppThemeData.grey200
                                    : controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                    ? AppThemeData.grey200
                                    : AppThemeData.grey800,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                subscriptionPlanModel.planPoints?[index] ?? '',
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: AppThemeData.regular,
                                  color: isDark
                                      ? controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                            ? AppThemeData.grey800
                                            : AppThemeData.grey200
                                      : controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                      ? AppThemeData.grey200
                                      : AppThemeData.grey800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                        ? isDark
                              ? AppThemeData.grey200
                              : AppThemeData.grey700
                        : isDark
                        ? AppThemeData.grey700
                        : AppThemeData.grey200,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${"Add item limits :".tr} ${subscriptionPlanModel.itemLimit == '-1' ? 'Unlimited'.tr : subscriptionPlanModel.itemLimit ?? '0'}',
                    maxLines: 2,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: AppThemeData.regular,
                      color: isDark
                          ? controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                ? AppThemeData.grey900
                                : AppThemeData.grey50
                          : controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                          ? AppThemeData.grey50
                          : AppThemeData.grey900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${'Accept order limits :'.tr} ${subscriptionPlanModel.orderLimit == '-1' ? 'Unlimited'.tr : subscriptionPlanModel.orderLimit ?? '0'}',
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: AppThemeData.regular,
                      color: isDark
                          ? controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                                ? AppThemeData.grey900
                                : AppThemeData.grey50
                          : controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                          ? AppThemeData.grey50
                          : AppThemeData.grey900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  RoundedButtonFill(
                    radius: 14,
                    textColor: controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                        ? AppThemeData.grey200
                        : isDark
                        ? AppThemeData.grey500
                        : AppThemeData.grey500,
                    title: controller.userModel.value.subscriptionPlanId == subscriptionPlanModel.id
                        ? "Renew".tr
                        : controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                        ? "Active".tr
                        : "Select Plan".tr,
                    color: controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id
                        ? AppThemeData.primary300
                        : isDark
                        ? AppThemeData.grey800
                        : AppThemeData.grey200,
                    width: 80,
                    height: 5,
                    onPress: onClick,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
