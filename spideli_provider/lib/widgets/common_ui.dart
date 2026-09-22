import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/booking_details_controller.dart';
import 'package:spideliprovider/model/onprovider_order_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:spideliprovider/services/send_notification.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class CommonUI {
  /// Shared app bar. Visuals follow the design system (DS surface, title
  /// style, 48dp back button with a screen-reader label); the parameters and
  /// back behaviour (`onBackTap ?? Get.back()`) are unchanged.
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
    // Listen to the theme provider so the bar rebuilds on theme changes.
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    // The legacy default icon color is a mid grey; map it to the DS icon color
    // so it is readable in both light and dark mode.
    final resolvedIconColor = c.isDark ? c.textPrimary : (iconColor == AppColors.assetColorLightGrey1000 ? c.textPrimary : iconColor);
    return AppBar(
      title: title != null
          ? DefaultTextStyle.merge(style: DsTypography.title.copyWith(color: c.textPrimary), child: title)
          : Text(
              "",
              style: DsTypography.title.copyWith(color: textColor),
            ),
      backgroundColor: backgroundColor ?? c.background,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: isBack,
      elevation: 0,
      scrolledUnderElevation: 0.6,
      centerTitle: false,
      titleSpacing: isBack == true ? 0 : 16,
      iconTheme: IconThemeData(color: resolvedIconColor),
      actionsIconTheme: IconThemeData(color: c.textPrimary),
      leading: isBack
          ? IconButton(
              tooltip: 'Back'.tr,
              onPressed: onBackTap ??
                  () {
                    Get.back();
                  },
              icon: Icon(Icons.arrow_back_rounded, color: resolvedIconColor),
            )
          : null,
      actions: actions,
    );
  }

  static showAddExtraChargesDialog(BuildContext context, BookingDetailsController controller, OnProviderOrderModel onProviderOrder) {
    final c = context.dsColors;
    Get.defaultDialog(
        title: 'Add Charges Detail',
        titleStyle: DsTypography.title.copyWith(color: c.textPrimary),
        titlePadding: const EdgeInsets.only(top: DsSpace.xxl, left: DsSpace.xxl, right: DsSpace.xxl),
        contentPadding: const EdgeInsets.only(bottom: DsSpace.xxl),
        backgroundColor: c.surfaceRaised,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
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
                      cursorColor: c.brand,
                      style: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                      decoration: DsInputDecoration.of(context, hint: 'Description'.tr, prefixIcon: Icons.notes_rounded)),
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
                      cursorColor: c.brand,
                      style: DsTypography.bodyStrong.tabular.copyWith(color: c.textPrimary),
                      decoration: DsInputDecoration.of(
                        context,
                        hint: 'Extra Charges Amount'.tr,
                        prefix: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Text(
                            RegionService.currencyForBooking(onProviderOrder.regionId)?.symbol ?? currencyData?.symbol ?? "",
                            style: DsTypography.bodyStrong.copyWith(color: c.textSecondary),
                          ),
                        ),
                      )),
                ),
              ),
              const SizedBox(
                height: DsSpace.xxl,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: DsButton.primary(
                  label: 'Add'.tr,
                  icon: Icons.add_rounded,
                  expand: true,
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
                ),
              ),
            ],
          ),
        ),
        radius: DsRadius.xl);
  }
}
