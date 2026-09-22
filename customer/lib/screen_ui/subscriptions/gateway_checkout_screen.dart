import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/gateway_checkout_controller.dart';
import 'package:customer/controllers/theme_controller.dart';
import 'package:customer/models/currency_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/wallet_screen/wallet_screen.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/round_button_fill.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Payment option picker + "Pay Now" for a subscription purchase. Pops with
/// `true` once the payment succeeded AND the purchase was recorded.
class GatewayCheckoutScreen extends StatelessWidget {
  final String title;
  final String amount;
  final CurrencyModel? currency;
  final String? regionId;
  final Future<void> Function(String paymentMethod) onPaid;

  const GatewayCheckoutScreen({super.key, required this.title, required this.amount, required this.currency, required this.regionId, required this.onPaid});

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;
    return GetX<GatewayCheckoutController>(
      init: GatewayCheckoutController(amount: amount, regionId: regionId, description: title, onPaid: onPaid),
      global: false,
      builder: (controller) {
        final methods = controller.availableMethods;
        return Scaffold(
          backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
          appBar: AppBar(
            backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            centerTitle: false,
            titleSpacing: 0,
            title: Text("Payment Option".tr, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
          ),
          body:
              controller.isLoading.value
                  ? Constant.loader()
                  : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Text(title, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                      const SizedBox(height: 4),
                      Text(
                        Constant.amountShow(amount: amount, currency: currency),
                        style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 20, color: AppThemeData.primary300),
                      ),
                      const SizedBox(height: 16),
                      if (methods.isEmpty)
                        Text("No payment method is available in your region.".tr, style: TextStyle(color: isDark ? AppThemeData.grey300 : AppThemeData.grey600))
                      else
                        Container(
                          decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          padding: const EdgeInsets.all(8),
                          child: Column(children: methods.map((g) => _option(controller, g, isDark)).toList()),
                        ),
                    ],
                  ),
          bottomNavigationBar:
              controller.isLoading.value || methods.isEmpty
                  ? null
                  : Container(
                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                    // Disabled while a payment runs (no double charge). Once
                    // paid, it only retries saving the purchase.
                    child: RoundedButtonFill(
                      title: controller.isPaid.value ? "Retry saving".tr : "Pay Now".tr,
                      height: 5.5,
                      color: controller.isPaying.value ? AppThemeData.grey400 : AppThemeData.primary300,
                      textColor: AppThemeData.grey50,
                      fontSizes: 16,
                      onPress: controller.isPaying.value ? null : () => controller.pay(context),
                    ),
                  ),
        );
      },
    );
  }

  Widget _option(GatewayCheckoutController controller, PaymentGateway g, bool isDark) {
    final bool isWallet = g == PaymentGateway.wallet;
    return InkWell(
      onTap: () => controller.selectedPaymentMethod.value = g.name,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: ShapeDecoration(shape: RoundedRectangleBorder(side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8))),
              child: Padding(padding: EdgeInsets.all(g == PaymentGateway.payFast ? 0 : 8.0), child: Image.asset(GatewayCheckoutController.imageOf(g))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name.capitalizeString(), style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900)),
                  if (isWallet)
                    Text(
                      Constant.amountShow(amount: (controller.userModel.value.walletAmount ?? 0).toString(), currency: controller.walletCurrency),
                      style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 14, color: AppThemeData.primary300),
                    ),
                ],
              ),
            ),
            Radio<String>(
              value: g.name,
              groupValue: controller.selectedPaymentMethod.value,
              activeColor: AppThemeData.primary300,
              onChanged: (v) => controller.selectedPaymentMethod.value = v ?? '',
            ),
          ],
        ),
      ),
    );
  }
}
