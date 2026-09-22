import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/booking_details_controller.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:spideliprovider/services/send_notification.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class CommonUI {
  static AppBar customAppBar(
    BuildContext context, {
    Widget? title,
    bool isBack = true,
    Color? backgroundColor,
    Color iconColor = AppColors.assetColorLightGrey1000,
    Color textColor = AppColors.assetColorLightGrey600,
    List<Widget>? actions,
    Function()? onBackTap,
  }) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return AppBar(
      title: title ??
          Text(
            "",
            style: TextStyle(color: textColor, fontFamily: AppColors.semiBold, fontSize: 18),
          ),
      backgroundColor: themeChange.getTheme() ? backgroundColor ?? AppColors.assetColorGrey1000 : backgroundColor ?? AppColors.colorWhite,
      automaticallyImplyLeading: isBack,
      elevation: 0,
      centerTitle: false,
      titleSpacing: isBack == true ? 0 : 16,
      leading: isBack
          ? InkWell(
              onTap: onBackTap ??
                  () {
                    Get.back();
                  },
              child: Icon(Icons.arrow_back, color: themeChange.getTheme() ? AppColors.colorWhite : iconColor),
            )
          : null,
      actions: actions,
    );
  }

  static showAddExtraChargesDialog(BuildContext context, BookingDetailsController controller, OnProviderOrderModel onProviderOrder) {
    Get.defaultDialog(
        title: 'Add Charges Detail',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, right: 16.0, left: 16.0),
                child: TextField(
                    controller: controller.descriptionController.value,
                    keyboardType: TextInputType.text,
                    maxLines: 1,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 16, right: 16),
                      hintText: 'Description'.tr,
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade500),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    )),
              ),
            ),

            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, right: 16.0, left: 16.0),
                child: TextField(
                    controller: controller.chargesController.value,
                    keyboardType: TextInputType.number,
                    maxLines: 1,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 16, right: 16),
                      hintText: 'Extra Charges Amount'.tr,
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade500),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Text(RegionService.currencyForBooking(onProviderOrder.regionId)?.symbol ?? currencyData?.symbol ?? ""),
                      ),
                    )),
              ),
            ),
            const SizedBox(
              height: 30.0,
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.colorPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20),
                  textStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (controller.chargesController.value.text.toString().isNotEmpty) {
                  ShowToastDialog.showLoader('Please wait...'.tr);
                  onProviderOrder.extraCharges = controller.chargesController.value.text.toString();
                  onProviderOrder.extraChargesDescription = controller.descriptionController.value.text.toString();
                  onProviderOrder.extraPaymentStatus = false;

                  await FireStoreUtils.updateOrder(onProviderOrder);
                  Map<String, dynamic> payLoad = <String, dynamic>{"type": "provider_order", "orderId": onProviderOrder.id};
                  await SendNotification.sendFcmMessage(providerServiceExtraCharges, onProviderOrder.author.fcmToken, payLoad);

                  ShowToastDialog.closeLoader();
                  Get.back();
                }
              },
              child: Text(
                'Add'.tr,
                style: const TextStyle(color: Colors.white, fontSize: 16.0),
              ),
            )
          ],
        ),
        radius: 5.0);
  }
}
