import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/subscription_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/sectionModel.dart';
import 'package:spideliprovider/model/subscription_plan_model.dart';
import 'package:spideliprovider/themes/app_them_data.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/themes/round_button_fill.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/select_payment_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class SubscriptionPlanScreen extends StatelessWidget {
  final bool? isDrawer;

  const SubscriptionPlanScreen({this.isDrawer, super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX(
        init: SubscriptionController(),
        builder: (controller) {
          return controller.isLoading.value
              ? loader()
              : Scaffold(
                  appBar: controller.isShowAppBar.value
                      ? AppBar(
                          backgroundColor: AppThemeData.secondary300,
                          centerTitle: false,
                          titleSpacing: 0,
                          iconTheme: const IconThemeData(
                              color: AppThemeData.grey50, size: 20),
                        )
                      : null,
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(
                              height: 10,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Choose Your Business Plan".tr,
                                    style: TextStyle(
                                      color: themeChange.getTheme()
                                          ? AppThemeData.grey50
                                          : AppThemeData.grey900,
                                      fontSize: 24,
                                      fontFamily: AppThemeData.semiBold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Select the most suitable business plan for your business to maximize your potential and access exclusive features."
                                        .tr,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: themeChange.getTheme()
                                          ? AppThemeData.grey400
                                          : AppThemeData.grey500,
                                      fontSize: 16,
                                      fontFamily: AppThemeData.regular,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            isDrawer == true ||
                                    controller.isDropdownDisable.value == true
                                ? Container(
                                    padding: const EdgeInsetsDirectional.only(
                                        bottom: 5),
                                    child: InkWell(
                                      onTap: () {
                                        ShowToastDialog.showToast(
                                            "You are not able to change section. because of your plan is purchased on ${selectedSectionModel!.name} section");
                                      },
                                      child: TextFormField(
                                          initialValue: controller
                                                  .selectedSectionModeldata
                                                  .value
                                                  .name
                                                  .toString() +
                                              " (${controller.selectedSectionModeldata.value.serviceType})",
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          textInputAction: TextInputAction.next,
                                          keyboardType:
                                              TextInputType.streetAddress,
                                          enabled: false,
                                          cursorColor: AppThemeData.primary600,
                                          // initialValue: MyAppState.currentUser!.shippingAddress.line1,
                                          decoration: InputDecoration(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 16),
                                              hintText: 'Section'.tr,
                                              hintStyle: TextStyle(
                                                color: themeChange.getTheme()
                                                    ? Colors.white
                                                    : Color(0Xff333333),
                                                fontSize: 14,
                                                fontFamily: AppThemeData.medium,
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          7.0),
                                                  borderSide: BorderSide(
                                                      color: AppThemeData
                                                          .primary600,
                                                      width: 2.0)),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error),
                                                borderRadius:
                                                    BorderRadius.circular(7.0),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error),
                                                borderRadius:
                                                    BorderRadius.circular(7.0),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color:
                                                        Colors.grey.shade400),
                                                borderRadius:
                                                    BorderRadius.circular(7.0),
                                              ),
                                              disabledBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color:
                                                        Colors.grey.shade400),
                                                borderRadius:
                                                    BorderRadius.circular(7.0),
                                              ))),
                                    ),
                                  )
                                : Container(
                                    height: 60,
                                    child: DropdownButtonFormField<
                                            SectionModel>(
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          contentPadding:
                                              EdgeInsets.fromLTRB(10, 2, 10, 2),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.grey, width: 1),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          border: OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.grey, width: 1),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                        ),
                                        validator: (value) => value == null
                                            ? 'field required'
                                            : null,
                                        value: controller
                                                        .selectedSectionModeldata
                                                        .value
                                                        .id ==
                                                    null ||
                                                controller
                                                        .selectedSectionModeldata
                                                        .value
                                                        .id ==
                                                    ''
                                            ? null
                                            : controller
                                                .selectedSectionModeldata.value,
                                        onChanged: (value) {
                                          controller.selectedSectionModeldata
                                              .value = value!;
                                          controller.subscriptionPlanList
                                              .clear();
                                          controller.getSubscriptionPlanList();
                                        },
                                        hint: Text('Select Section'.tr),
                                        items: controller.sectionsVal
                                            .map((SectionModel item) {
                                          return DropdownMenuItem<SectionModel>(
                                            child: Text(item.name.toString() +
                                                " (${item.serviceType})"),
                                            value: item,
                                          );
                                        }).toList()),
                                  ),
                            const SizedBox(
                              height: 10,
                            ),
                            controller.isLoading.value
                                ? loader()
                                : controller.subscriptionPlanList.isEmpty
                                    ? SizedBox(
                                        width: Responsive.width(100, context),
                                        height: Responsive.height(50, context),
                                        child: showEmptyView(
                                            message:
                                                "Oops! The selected section doesn't have a subscription plan. Please contact the admin.".tr +
                                                    "\n${adminEmail}"))
                                    : ListView.builder(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
                                        primary: false,
                                        itemCount: controller
                                            .subscriptionPlanList.length,
                                        itemBuilder: (context, index) {
                                          final subscriptionPlanModel =
                                              controller
                                                  .subscriptionPlanList[index];
                                          return SubscriptionPlanWidget(
                                            onContainClick: () {
                                              controller
                                                      .selectedSubscriptionPlan
                                                      .value =
                                                  subscriptionPlanModel;
                                              controller.totalAmount.value =
                                                  double.parse(
                                                      subscriptionPlanModel
                                                              .price ??
                                                          '0.0');
                                              controller.update();
                                            },
                                            onClick: () {
                                              if (controller
                                                      .selectedSubscriptionPlan
                                                      .value
                                                      .id ==
                                                  subscriptionPlanModel.id) {
                                                if (controller
                                                            .selectedSubscriptionPlan
                                                            .value
                                                            .type ==
                                                        'free' ||
                                                    controller
                                                            .selectedSubscriptionPlan
                                                            .value
                                                            .isCommissionPlan ==
                                                        true) {
                                                  controller
                                                      .selectedPaymentMethod
                                                      .value = 'free';
                                                  controller.setOrder();
                                                } else {
                                                  Get.to(
                                                      const SelectPaymentScreen());
                                                }
                                              }
                                            },
                                            type: 'Plan',
                                            subscriptionPlanModel:
                                                subscriptionPlanModel,
                                          );
                                        }),
                            const SizedBox(
                              height: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
        });
  }
}

class FeatureItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool selectedPlan;

  const FeatureItem(
      {super.key,
      required this.title,
      required this.isActive,
      required this.selectedPlan});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isActive == true
              ? SvgPicture.asset(
                  'assets/icons/ic_check.svg',
                )
              : SvgPicture.asset(
                  'assets/icons/ic_close.svg',
                  colorFilter: const ColorFilter.mode(
                    AppThemeData.danger200,
                    BlendMode.srcIn,
                  ),
                ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title == 'chat'
                  ? 'Chat'
                  : title == 'dineIn'
                      ? "DineIn"
                      : title == 'ownerMobileApp'
                          ? 'Service Provider Mobile App'
                          : '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontFamily: AppThemeData.medium,
                color: themeChange.getTheme()
                    ? selectedPlan == true
                        ? AppThemeData.grey900
                        : AppThemeData.grey50
                    : selectedPlan == true
                        ? AppThemeData.grey50
                        : AppThemeData.grey900,
              ),
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

  const SubscriptionPlanWidget(
      {super.key,
      required this.onClick,
      required this.type,
      required this.subscriptionPlanModel,
      required this.onContainClick});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX(
        init: SubscriptionController(),
        builder: (controller) {
          return InkWell(
            splashColor: Colors.transparent,
            onTap: onContainClick,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                    color: themeChange.getTheme()
                        ? AppThemeData.grey800
                        : AppThemeData.grey200),
                color: controller.selectedSubscriptionPlan.value.id ==
                        subscriptionPlanModel.id
                    ? themeChange.getTheme()
                        ? AppThemeData.grey50
                        : AppThemeData.grey800
                    : themeChange.getTheme()
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
                        NetworkImageWidget(
                          imageUrl: subscriptionPlanModel.image ?? '',
                          fit: BoxFit.cover,
                          width: 50,
                          height: 50,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subscriptionPlanModel.name ?? '',
                                style: TextStyle(
                                  color: controller.selectedSubscriptionPlan
                                              .value.id ==
                                          subscriptionPlanModel.id
                                      ? themeChange.getTheme()
                                          ? AppThemeData.grey900
                                          : AppThemeData.grey50
                                      : themeChange.getTheme()
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
                                style: const TextStyle(
                                  fontFamily: AppThemeData.regular,
                                  fontSize: 14,
                                  color: AppThemeData.grey400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        controller.userModel.value.subscriptionPlanId ==
                                subscriptionPlanModel.id
                            ? RoundedButtonFill(
                                title: "Active".tr,
                                width: 18,
                                height: 4,
                                color: AppThemeData.success500,
                                textColor: AppThemeData.grey50,
                                onPress: () async {},
                              )
                            : SizedBox(),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscriptionPlanModel.type == "free"
                              ? "Free"
                              : amountShow(
                                  amount: double.parse(
                                          subscriptionPlanModel.price ?? '0.0')
                                      .toString()),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                controller.selectedSubscriptionPlan.value.id ==
                                        subscriptionPlanModel.id
                                    ? themeChange.getTheme()
                                        ? AppThemeData.grey800
                                        : AppThemeData.grey200
                                    : themeChange.getTheme()
                                        ? AppThemeData.grey200
                                        : AppThemeData.grey800,
                            fontFamily: AppThemeData.semiBold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subscriptionPlanModel.expiryDay == "-1"
                              ? "Lifetime"
                              : "${subscriptionPlanModel.expiryDay} Days",
                          style: TextStyle(
                            fontFamily: AppThemeData.medium,
                            fontSize: 14,
                            color:
                                controller.selectedSubscriptionPlan.value.id ==
                                        subscriptionPlanModel.id
                                    ? themeChange.getTheme()
                                        ? AppThemeData.grey500
                                        : AppThemeData.grey500
                                    : themeChange.getTheme()
                                        ? AppThemeData.grey500
                                        : AppThemeData.grey500,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                    Divider(
                        color: controller.selectedSubscriptionPlan.value.id ==
                                subscriptionPlanModel.id
                            ? themeChange.getTheme()
                                ? AppThemeData.grey200
                                : AppThemeData.grey700
                            : themeChange.getTheme()
                                ? AppThemeData.grey700
                                : AppThemeData.grey200),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 0,
                      runSpacing: 12,
                      children: subscriptionPlanModel.features
                              ?.toJson()
                              .entries
                              .map((entry) {
                            Widget widget = entry.key == 'qrCodeGenerate'
                                ? SizedBox()
                                : FeatureItem(
                                    title: entry.key,
                                    isActive: entry.value,
                                    selectedPlan: controller
                                            .selectedSubscriptionPlan
                                            .value
                                            .id ==
                                        subscriptionPlanModel.id);
                            return widget;
                          }).toList() ??
                          [],
                    ),
                    if (subscriptionPlanModel.isCommissionPlan == true)
                      SizedBox(height: 10),
                    if (subscriptionPlanModel.isCommissionPlan == true)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text('•  ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: AppThemeData.medium,
                                    color: themeChange.getTheme()
                                        ? controller.selectedSubscriptionPlan
                                                    .value.id ==
                                                subscriptionPlanModel.id
                                            ? AppThemeData.grey800
                                            : AppThemeData.grey200
                                        : controller.selectedSubscriptionPlan
                                                    .value.id ==
                                                subscriptionPlanModel.id
                                            ? AppThemeData.grey200
                                            : AppThemeData.grey800,
                                  )),
                              Expanded(
                                child: Text(
                                    MyAppState.currentUser?.adminCommission !=
                                            null
                                        ? "Pay a commission of ${MyAppState.currentUser?.adminCommission?.type == 'percentage' ? "${MyAppState.currentUser?.adminCommission?.commission ?? 0}%" : "${amountShow(amount: "${MyAppState.currentUser?.adminCommission?.commission ?? 0}")} Flat"} on each booking."
                                        : "Pay a commission of ${controller.selectedSectionModeldata.value.adminCommision?.type == 'percentage' ? "${controller.selectedSectionModeldata.value.adminCommision?.commission ?? 0}%" : "${amountShow(amount: "${controller.selectedSectionModeldata.value.adminCommision?.commission ?? 0}")} Flat"} on each booking."
                                            .tr,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: AppThemeData.regular,
                                      color: themeChange.getTheme()
                                          ? controller.selectedSubscriptionPlan
                                                      .value.id ==
                                                  subscriptionPlanModel.id
                                              ? AppThemeData.grey800
                                              : AppThemeData.grey200
                                          : controller.selectedSubscriptionPlan
                                                      .value.id ==
                                                  subscriptionPlanModel.id
                                              ? AppThemeData.grey200
                                              : AppThemeData.grey800,
                                    )),
                              ),
                            ],
                          )),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: subscriptionPlanModel.planPoints?.length,
                      itemBuilder: (BuildContext? context, int index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Text('•  ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: AppThemeData.medium,
                                    color: themeChange.getTheme()
                                        ? controller.selectedSubscriptionPlan
                                                    .value.id ==
                                                subscriptionPlanModel.id
                                            ? AppThemeData.grey800
                                            : AppThemeData.grey200
                                        : controller.selectedSubscriptionPlan
                                                    .value.id ==
                                                subscriptionPlanModel.id
                                            ? AppThemeData.grey200
                                            : AppThemeData.grey800,
                                  )),
                              Expanded(
                                child: Text(
                                    subscriptionPlanModel.planPoints?[index] ??
                                        '',
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: AppThemeData.regular,
                                      color: themeChange.getTheme()
                                          ? controller.selectedSubscriptionPlan
                                                      .value.id ==
                                                  subscriptionPlanModel.id
                                              ? AppThemeData.grey800
                                              : AppThemeData.grey200
                                          : controller.selectedSubscriptionPlan
                                                      .value.id ==
                                                  subscriptionPlanModel.id
                                              ? AppThemeData.grey200
                                              : AppThemeData.grey800,
                                    )),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Divider(
                        color: controller.selectedSubscriptionPlan.value.id ==
                                subscriptionPlanModel.id
                            ? themeChange.getTheme()
                                ? AppThemeData.grey200
                                : AppThemeData.grey700
                            : themeChange.getTheme()
                                ? AppThemeData.grey700
                                : AppThemeData.grey200),
                    const SizedBox(height: 10),
                    Text(
                        'Add service limits : ${subscriptionPlanModel.itemLimit == '-1' ? 'Unlimited' : subscriptionPlanModel.itemLimit ?? '0'}',
                        maxLines: 2,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                            fontSize: 14,
                            fontFamily: AppThemeData.regular,
                            color: themeChange.getTheme()
                                ? controller.selectedSubscriptionPlan.value
                                            .id ==
                                        subscriptionPlanModel.id
                                    ? AppThemeData.grey900
                                    : AppThemeData.grey50
                                : controller.selectedSubscriptionPlan.value
                                            .id ==
                                        subscriptionPlanModel.id
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900)),
                    const SizedBox(height: 10),
                    Text(
                        'Accept booking limits : ${subscriptionPlanModel.orderLimit == '-1' ? 'Unlimited' : subscriptionPlanModel.orderLimit ?? '0'}',
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        style: TextStyle(
                            fontSize: 14,
                            fontFamily: AppThemeData.regular,
                            color: themeChange.getTheme()
                                ? controller.selectedSubscriptionPlan.value
                                            .id ==
                                        subscriptionPlanModel.id
                                    ? AppThemeData.grey900
                                    : AppThemeData.grey50
                                : controller.selectedSubscriptionPlan.value
                                            .id ==
                                        subscriptionPlanModel.id
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900)),
                    const SizedBox(height: 20),
                    RoundedButtonFill(
                      radius: 14,
                      textColor: controller.selectedSubscriptionPlan.value.id ==
                              subscriptionPlanModel.id
                          ? AppThemeData.grey200
                          : themeChange.getTheme()
                              ? AppThemeData.grey500
                              : AppThemeData.grey500,
                      title: controller.userModel.value.subscriptionPlanId ==
                              subscriptionPlanModel.id
                          ? "Renew"
                          : controller.selectedSubscriptionPlan.value.id ==
                                  subscriptionPlanModel.id
                              ? "Active".tr
                              : "Select Plan".tr,
                      color: controller.selectedSubscriptionPlan.value.id ==
                              subscriptionPlanModel.id
                          ? AppThemeData.secondary300
                          : themeChange.getTheme()
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
        });
  }
}
