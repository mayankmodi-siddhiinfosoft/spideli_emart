import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/add_advertisement_screen/add_advertisement_screen.dart';
import 'package:vendor/app/chat_screens/chat_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/view_advertisement_controller.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/video_widget.dart';

class ViewAdvertisementScreen extends StatelessWidget {
  const ViewAdvertisementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ViewAdvertisementController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            titleSpacing: 0,
            iconTheme: IconThemeData(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, size: 20),
            title: Text(
              "View Advertisement".tr,
              style: TextStyle(color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
            actions: [
              Visibility(
                visible: controller.vendorModel.value?.subscriptionPlan?.features?.chat != false,
                child: InkWell(
                  splashColor: Colors.transparent,
                  onTap: () async {
                    ShowToastDialog.showLoader("Please wait".tr);
                    VendorModel? vendorModel = await FireStoreUtils.getVendorById(controller.advertisementModel.value.vendorId.toString());
                    ShowToastDialog.closeLoader();

                    Get.to(
                      const ChatScreen(),
                      arguments: {
                        "senderName": vendorModel?.title,
                        "senderId": Constant.userModel?.id,
                        "senderProfileUrl": vendorModel?.photo,
                        "receivedName": 'Admin',
                        "receivedId": 'admin',
                        "receivedProfileUrl": '',
                        "orderId": controller.advertisementModel.value.id,
                        "token": '',
                        "chatType": 'admin',
                      },
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4, left: 10, right: 16),
                    child: SvgPicture.asset("assets/icons/ic_message.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey800 : AppThemeData.grey100, BlendMode.srcIn)),
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          "Ad Status".tr,
                          style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: [BoxShadow(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, blurRadius: 1, spreadRadius: 0.5)],
                        ),
                        child: Column(
                          children: [
                            buildRow(
                              label: 'Request Verify Status:'.tr,
                              valueBadge: Constant.getAdsStatus(controller.advertisementModel.value).capitalizeString(),
                              isDarkMode: isDark,
                              textColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              colorData: Color(0xff38D0FF),
                            ),
                            buildRow(
                              label: 'Payment Status:'.tr,
                              value: controller.advertisementModel.value.paymentStatus == true ? 'Paid'.tr : 'Unpaid'.tr,
                              textColor: controller.advertisementModel.value.paymentStatus == true ? AppThemeData.success300 : AppThemeData.danger200,
                              isDarkMode: isDark,
                            ),
                            buildRow(label: 'Ad Type:'.tr, value: controller.advertisementModel.value.type == 'restaurant_promotion' ? 'Store Promotion'.tr : 'Video Promotion'.tr, isDarkMode: isDark),
                            buildRow(label: 'Ad Created Date:'.tr, value: DateFormat('MMM d, yyyy').format(controller.advertisementModel.value.createdAt!.toDate()), isDarkMode: isDark),
                            buildRow(
                              label: 'Duration:'.tr,
                              value:
                                  '${DateFormat('MMM d, yyyy').format(controller.advertisementModel.value.startDate!.toDate())} - ${DateFormat('MMM d, yyyy').format(controller.advertisementModel.value.endDate!.toDate())}',
                              isDarkMode: isDark,
                            ),
                            Visibility(
                              visible:
                                  (controller.advertisementModel.value.isPaused == true &&
                                  controller.advertisementModel.value.status != Constant.adsCancel &&
                                  Constant.getAdsStatus(controller.advertisementModel.value) != Constant.adsExpire),
                              child: buildRow(label: 'Ad Paused Note:'.tr, value: controller.advertisementModel.value.pauseNote ?? '', isDarkMode: isDark),
                            ),
                            Visibility(
                              visible: controller.advertisementModel.value.status == Constant.adsCancel,
                              child: buildRow(label: 'Ad Cancel Note:'.tr, value: controller.advertisementModel.value.canceledNote ?? '', isDarkMode: isDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        TextFieldWidget(
                          readOnly: true,
                          title: 'Advertisement Title (Default)'.tr,
                          controller: TextEditingController(text: controller.advertisementModel.value.title ?? ''),
                          hintText: 'Enter Title here'.tr,
                        ),
                        TextFieldWidget(
                          readOnly: true,
                          title: 'Description:'.tr,
                          controller: TextEditingController(text: controller.advertisementModel.value.description ?? ''),
                          maxLine: 5,
                          hintText: 'Enter the description'.tr,
                        ),
                        Visibility(
                          visible: controller.advertisementModel.value.type != 'video_promotion',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Profile Image".tr,
                                style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  SizedBox(
                                    height: Responsive.width(30, context),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: NetworkImageWidget(
                                            imageUrl: controller.advertisementModel.value.profileImage ?? '',
                                            fit: BoxFit.cover,
                                            width: Responsive.width(30, context),
                                            height: Responsive.width(30, context),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.center, children: []),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Visibility(
                          visible: controller.advertisementModel.value.type != 'video_promotion',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                "Cover Image".tr,
                                style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                              ),
                              const SizedBox(height: 5),
                              SizedBox(
                                height: Responsive.height(20, context),
                                width: Responsive.width(90, context),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                                        child: NetworkImageWidget(
                                          imageUrl: controller.advertisementModel.value.coverImage ?? '',
                                          fit: BoxFit.cover,
                                          height: Responsive.height(20, context),
                                          width: Responsive.width(90, context),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Visibility(
                          visible: controller.advertisementModel.value.type == 'video_promotion',
                          child: SizedBox(
                            height: Responsive.height(20, context),
                            width: Responsive.width(90, context),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                      child: VideoAdvWidget(width: MediaQuery.of(context).size.width, url: controller.advertisementModel.value.video),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: RoundedButtonFill(
                radius: 14,
                title: "Edit Details".tr,
                height: 5.5,
                color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                textColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                fontSizes: 16,
                onPress: () async {
                  Get.to(AddAdvertisementScreen(), arguments: {'advsModel': controller.advertisementModel.value});
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget buildRow({required String label, String? value, String? valueBadge, Color? colorData, Color? textColor, required bool isDarkMode}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 15.0, fontFamily: AppThemeData.medium, color: (isDarkMode ? AppThemeData.grey100 : AppThemeData.grey800)),
        ),
        SizedBox(width: 8.0),
        Visibility(
          visible: value != null,
          child: Expanded(
            child: Text(
              (value ?? ''),
              textAlign: TextAlign.end,
              maxLines: 2,
              style: TextStyle(
                fontSize: 15.0,
                fontFamily: textColor == null ? AppThemeData.medium : AppThemeData.semiBold,
                color: textColor ?? (isDarkMode ? AppThemeData.grey400 : AppThemeData.grey500),
              ),
            ),
          ),
        ),
        if (valueBadge != null)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: colorData, borderRadius: BorderRadius.circular(20.0)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                    child: Text(
                      valueBadge,
                      maxLines: 1,
                      style: TextStyle(
                        color: (textColor ?? (isDarkMode ? AppThemeData.grey400 : AppThemeData.grey500)),
                        fontFamily: valueBadge.isNotEmpty == true ? AppThemeData.medium : AppThemeData.semiBold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
