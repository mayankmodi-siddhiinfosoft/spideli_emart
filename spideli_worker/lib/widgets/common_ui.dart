import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/controller/booking_details_controller.dart';
import 'package:spideliworker/model/onprovider_order_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/send_notification.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class CommonUI {
  /// Shared app bar. Constructor API and behaviour are unchanged (back tap
  /// runs [onBackTap] or `Get.back()`); visuals follow the design system:
  /// DS background, 48dp labelled back button, soft separator on scroll.
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
    final isDark = themeChange.getTheme();
    final c = DsColors.resolve(isDark);
    // Default icon color follows the DS text color; an explicit iconColor is
    // still honoured in light mode (as before, dark mode always uses light).
    final Color backColor = isDark || iconColor == AppColors.assetColorLightGrey1000 ? c.textPrimary : iconColor;
    return AppBar(
      title: title ?? Text("", style: DsTypography.title.copyWith(color: textColor)),
      titleTextStyle: DsTypography.title.copyWith(color: c.textPrimary),
      backgroundColor: backgroundColor ?? c.background,
      foregroundColor: c.textPrimary,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: isBack,
      elevation: 0,
      scrolledUnderElevation: 0.6,
      shadowColor: c.shadow.withValues(alpha: 0.25),
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      centerTitle: false,
      titleSpacing: isBack == true ? 0 : 16,
      leadingWidth: isBack ? 56 : null,
      leading: isBack
          ? DsBackButton(
              color: backColor,
              onPressed:
                  onBackTap ??
                  () {
                    Get.back();
                  },
            )
          : null,
      actions: actions,
    );
  }

  static void showAddExtraChargesDialog(BuildContext context, BookingDetailsController controller, OnProviderOrderModel onProviderOrder) {
    Get.defaultDialog(
      title: 'Add Charges Detail',
      titleStyle: DsTypography.title.copyWith(color: DsColors.of(context).textPrimary),
      backgroundColor: DsColors.of(context).surfaceRaised,
      titlePadding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.xl, DsSpace.xl, 0),
      contentPadding: const EdgeInsets.fromLTRB(DsSpace.xs, 0, DsSpace.xs, DsSpace.lg),
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
                style: DsTypography.bodyStrong.copyWith(color: DsColors.of(context).textPrimary),
                decoration: DsInputDecoration.of(context, hint: 'Description'.tr, prefixIcon: Icons.notes_rounded),
              ),
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
                style: DsTypography.bodyStrong.copyWith(color: DsColors.of(context).textPrimary).tabular,
                decoration: DsInputDecoration.of(
                  context,
                  hint: 'Extra Charges Amount'.tr,
                  prefix: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: 14),
                    child: Text(
                      (RegionService.currencyForRegion(onProviderOrder.regionId) ?? currencyData!).symbol.toString(),
                      style: DsTypography.label.copyWith(color: DsColors.of(context).textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DsSpace.xxl),
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

                  // Only the extra-charge fields (known-fields write).
                  await FireStoreUtils.updateOrderFields(onProviderOrder.id, {
                    'extraCharges': onProviderOrder.extraCharges,
                    'extraChargesDescription': onProviderOrder.extraChargesDescription,
                    'extraPaymentStatus': false,
                  });
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
      radius: DsRadius.xl,
    );
  }
}
