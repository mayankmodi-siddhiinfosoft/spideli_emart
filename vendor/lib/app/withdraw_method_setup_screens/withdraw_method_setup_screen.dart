import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/withdraw_method_setup_screens/bank_details_screen.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/withdraw_method_setup_controller.dart';
import 'package:vendor/models/withdraw_method_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class WithdrawMethodSetupScreen extends StatelessWidget {
  const WithdrawMethodSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: WithdrawMethodSetupController(),
      builder: (controller) {
        final model = controller.withdrawMethodModel.value;
        void openBankSetup() {
          Get.to(const BankDetailsScreen())!.then((value) async {
            ShowToastDialog.showLoader("Please wait..".tr);
            controller.isBankDetailsAdded.value = true;
            await controller.getPaymentMethod();
            ShowToastDialog.closeLoader();
          });
        }

        final cards = <Widget>[
          _MethodCard(
            logo: SvgPicture.asset("assets/icons/ic_building_four.svg", colorFilter: ColorFilter.mode(context.dsColors.textPrimary, BlendMode.srcIn)),
            title: "Bank Transfer".tr,
            configured: controller.isBankDetailsAdded.value != false,
            onSetup: openBankSetup,
            // The bank card always offers edit, as before.
            onEdit: openBankSetup,
          ),
          _MethodCard(
            logo: Image.asset("assets/images/flutterwave.png"),
            title: "Flutter wave".tr,
            configured: model.flutterWave != null,
            onSetup: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return flutterWaveDialog(controller, isDark);
                },
              );
            },
            onEdit: model.flutterWave != null
                ? () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return flutterWaveDialog(controller, isDark);
                      },
                    );
                  }
                : null,
            onDelete: model.flutterWave != null
                ? () async {
                    controller.withdrawMethodModel.value.flutterWave = null;
                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then((value) async {
                      ShowToastDialog.showLoader("Please wait..".tr);

                      await controller.getPaymentMethod();
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast("Payment Method remove successfully".tr);
                    });
                  }
                : null,
          ),
          _MethodCard(
            logo: Image.asset("assets/images/paypal.png"),
            title: "PayPal".tr,
            configured: model.paypal != null,
            onSetup: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return payPalDialog(controller, isDark);
                },
              );
            },
            onEdit: model.paypal != null
                ? () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return payPalDialog(controller, isDark);
                      },
                    );
                  }
                : null,
            onDelete: model.paypal != null
                ? () async {
                    controller.withdrawMethodModel.value.paypal = null;
                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then((value) async {
                      ShowToastDialog.showLoader("Please wait..".tr);

                      await controller.getPaymentMethod();
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast("Payment Method remove successfully".tr);
                    });
                  }
                : null,
          ),
          _MethodCard(
            logo: Image.asset("assets/images/razorpay.png"),
            title: "RazorPay".tr,
            configured: model.razorpay != null,
            onSetup: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return razorPayDialog(controller, isDark);
                },
              );
            },
            onEdit: model.razorpay != null
                ? () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return razorPayDialog(controller, isDark);
                      },
                    );
                  }
                : null,
            onDelete: model.razorpay != null
                ? () async {
                    controller.withdrawMethodModel.value.razorpay = null;
                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then((value) async {
                      ShowToastDialog.showLoader("Please wait..".tr);

                      await controller.getPaymentMethod();
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast("Payment Method remove successfully".tr);
                    });
                  }
                : null,
          ),
          _MethodCard(
            logo: Image.asset("assets/images/stripe.png"),
            title: "Stripe".tr,
            configured: model.stripe != null,
            onSetup: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return stripeDialog(controller, isDark);
                },
              );
            },
            onEdit: model.stripe != null
                ? () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return stripeDialog(controller, isDark);
                      },
                    );
                  }
                : null,
            onDelete: model.stripe != null
                ? () async {
                    controller.withdrawMethodModel.value.stripe = null;
                    await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then((value) async {
                      ShowToastDialog.showLoader("Please wait..".tr);

                      await controller.getPaymentMethod();
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast("Payment Method remove successfully".tr);
                    });
                  }
                : null,
          ),
        ];

        final connected = [
          controller.isBankDetailsAdded.value != false,
          model.flutterWave != null,
          model.paypal != null,
          model.razorpay != null,
          model.stripe != null,
        ].where((e) => e).length;

        return DsScaffold(
          title: "Set up Methods".tr,
          body: DsAsync(
            isLoading: controller.isLoading.value,
            skeleton: const DsSkeletonList(itemCount: 5),
            builder: (context) {
              final l = context.dsLayout;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.xxxl),
                child: DsResponsive(
                  maxWidth: DsLayout.wideMax,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsFadeSlideIn(
                        child: _SetupSummary(connected: connected, total: cards.length),
                      ),
                      const DsGap(DsSpace.xl),
                      DsAdaptiveGrid(
                        minItemWidth: 320,
                        maxColumns: 2,
                        spacing: DsSpace.md,
                        runSpacing: DsSpace.md,
                        children: [for (var i = 0; i < cards.length; i++) DsFadeSlideIn(index: i + 1, child: cards[i])],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Dialog flutterWaveDialog(WithdrawMethodSetupController controller, isDark) {
    return _setupDialog(
      logo: Image.asset("assets/images/flutterwave.png"),
      title: "Flutter wave".tr,
      fields: [
        DsTextField(
          label: 'Account Number'.tr,
          controller: controller.accountNumberFlutterWave.value,
          hint: 'Account Number'.tr,
          prefixIcon: Icons.numbers_rounded,
        ),
        DsTextField(label: 'Bank Code'.tr, controller: controller.bankCodeFlutterWave.value, hint: 'Bank Code'.tr, prefixIcon: Icons.account_balance_outlined),
      ],
      onSave: () async {
        if (controller.accountNumberFlutterWave.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter account Number".tr);
        } else if (controller.bankCodeFlutterWave.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter bank code".tr);
        } else {
          FlutterWave? flutterWave = controller.withdrawMethodModel.value.flutterWave;
          if (flutterWave != null) {
            flutterWave.accountNumber = controller.accountNumberFlutterWave.value.text;
            flutterWave.bankCode = controller.bankCodeFlutterWave.value.text;
          } else {
            flutterWave = FlutterWave(
              accountNumber: controller.accountNumberFlutterWave.value.text,
              bankCode: controller.bankCodeFlutterWave.value.text,
              name: "FlutterWave",
            );
          }
          controller.withdrawMethodModel.value.flutterWave = flutterWave;
          await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then((value) async {
            ShowToastDialog.showLoader("Please wait..".tr);

            await controller.getPaymentMethod();
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Payment Method save successfully".tr);
            Get.back();
          });
        }
      },
    );
  }

  Dialog payPalDialog(WithdrawMethodSetupController controller, isDark) {
    return _setupDialog(
      logo: Image.asset("assets/images/paypal.png"),
      title: "PayPal".tr,
      fields: [
        DsTextField(
          label: 'Paypal Email'.tr,
          controller: controller.emailPaypal.value,
          hint: 'Paypal Email'.tr,
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
      onSave: () async {
        if (controller.emailPaypal.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter Paypal email".tr);
        } else {
          Paypal? payPal = controller.withdrawMethodModel.value.paypal;
          if (payPal != null) {
            payPal.email = controller.emailPaypal.value.text;
          } else {
            payPal = Paypal(email: controller.emailPaypal.value.text, name: "PayPal");
          }
          controller.withdrawMethodModel.value.paypal = payPal;
          await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then((value) async {
            ShowToastDialog.showLoader("Please wait..".tr);

            await controller.getPaymentMethod();
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Payment Method save successfully".tr);
            Get.back();
          });
        }
      },
    );
  }

  Dialog razorPayDialog(WithdrawMethodSetupController controller, isDark) {
    return _setupDialog(
      logo: Image.asset("assets/images/razorpay.png"),
      title: "RazorPay".tr,
      fields: [
        DsTextField(
          label: 'Razorpay account Id'.tr,
          controller: controller.accountIdRazorPay.value,
          hint: 'Razorpay account Id'.tr,
          prefixIcon: Icons.badge_outlined,
        ),
      ],
      note: "Add your Account ID. For example, acc_GLGeLkU2JUeyDZ".tr,
      onSave: () async {
        if (controller.accountIdRazorPay.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter RazorPay account Id".tr);
        } else {
          RazorpayModel? razorPay = controller.withdrawMethodModel.value.razorpay;
          if (razorPay != null) {
            razorPay.accountId = controller.accountIdRazorPay.value.text;
          } else {
            razorPay = RazorpayModel(accountId: controller.accountIdRazorPay.value.text, name: "RazorPay");
          }
          controller.withdrawMethodModel.value.razorpay = razorPay;
          await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then((value) async {
            ShowToastDialog.showLoader("Please wait..".tr);

            await controller.getPaymentMethod();
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Payment Method save successfully".tr);
            Get.back();
          });
        }
      },
    );
  }

  Dialog stripeDialog(WithdrawMethodSetupController controller, isDark) {
    return _setupDialog(
      logo: Image.asset("assets/images/stripe.png"),
      title: "Stripe".tr,
      fields: [
        DsTextField(
          label: 'Stripe Account Id'.tr,
          controller: controller.accountIdStripe.value,
          hint: 'Stripe Account Id'.tr,
          prefixIcon: Icons.badge_outlined,
        ),
      ],
      note: "Go to your Stripe account settings > Account details > Copy your account ID on the right-hand side. For example, acc_GLGeLkU2JUeyDZ".tr,
      onSave: () async {
        if (controller.accountIdStripe.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter stripe account Id".tr);
        } else {
          Stripe? stripe = controller.withdrawMethodModel.value.stripe;
          if (stripe != null) {
            stripe.accountId = controller.accountIdStripe.value.text;
          } else {
            stripe = Stripe(accountId: controller.accountIdStripe.value.text, name: "Stripe");
          }
          controller.withdrawMethodModel.value.stripe = stripe;
          await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then((value) async {
            ShowToastDialog.showLoader("Please wait..".tr);

            await controller.getPaymentMethod();
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Payment Method save successfully".tr);
            Get.back();
          });
        }
      },
    );
  }

  /// Shared DS layout for the payout-method dialogs: logo header, fields,
  /// optional hint and a full-width Save button.
  Dialog _setupDialog({required Widget logo, required String title, required List<Widget> fields, String? note, required Future<void> Function() onSave}) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: DsRadius.brXl),
      insetPadding: const EdgeInsets.all(DsSpace.lg),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Builder(
        builder: (context) {
          final c = context.dsColors;
          final t = context.dsText;
          return ColoredBox(
            color: c.surfaceRaised,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DsSpace.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _LogoTile(child: logo),
                        const DsGap(DsSpace.md),
                        Expanded(child: Text(title, style: t.title)),
                        DsIconButton(
                          icon: Icons.close_rounded,
                          semanticLabel: 'Close'.tr,
                          variant: DsIconButtonVariant.tonal,
                          size: 36,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    const DsGap(DsSpace.xl),
                    ...fields,
                    if (note != null) ...[DsInlineAlert(tone: DsTone.info, message: note), const DsGap(DsSpace.xl)],
                    DsButton.primary(label: "Save".tr, icon: Icons.check_rounded, expand: true, onPressed: onSave),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Header: connected-methods ring on a deep finance gradient.
class _SetupSummary extends StatelessWidget {
  const _SetupSummary({required this.connected, required this.total});
  final int connected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.gradient(
      gradient: DsGradients.deep(context),
      child: Row(
        children: [
          DsProgressRing(
            value: total == 0 ? 0 : connected / total,
            size: 76,
            onBrand: true,
            center: Text("$connected/$total", style: t.titleSm.tabular.withColor(Colors.white)),
          ),
          const DsGap(DsSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Payout methods".tr, style: t.title.withColor(Colors.white)),
                const DsGap(DsSpace.xs),
                Text("Connect where your withdrawals are paid out.".tr, style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      width: 52,
      height: 52,
      padding: const EdgeInsets.all(DsSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: DsRadius.brMd,
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

/// One payout method: logo, name, status chip and its actions.
class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.logo, required this.title, required this.configured, required this.onSetup, this.onEdit, this.onDelete});

  final Widget logo;
  final String title;
  final bool configured;
  final VoidCallback onSetup;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      borderColor: configured ? c.success.withValues(alpha: 0.55) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _LogoTile(child: logo),
              const DsGap(DsSpace.md),
              Expanded(child: Text(title, style: t.titleSm)),
              if (onEdit != null)
                DsIconButton(
                  semanticLabel: 'Edit'.tr,
                  variant: DsIconButtonVariant.outlined,
                  onPressed: onEdit,
                  child: SvgPicture.asset("assets/icons/ic_edit_coupon.svg", width: 18, height: 18, colorFilter: ColorFilter.mode(c.textPrimary, BlendMode.srcIn)),
                ),
              if (onDelete != null)
                DsIconButton(
                  semanticLabel: 'Delete'.tr,
                  variant: DsIconButtonVariant.outlined,
                  onPressed: onDelete,
                  child: SvgPicture.asset("assets/icons/ic_delete-one.svg", width: 18, height: 18, colorFilter: ColorFilter.mode(c.dangerStrong, BlendMode.srcIn)),
                ),
            ],
          ),
          const DsGap(DsSpace.md),
          Divider(height: 1, thickness: 1, color: c.divider),
          const DsGap(DsSpace.md),
          AnimatedSwitcher(
            duration: DsMotion.of(context, DsMotion.base),
            child: configured
                ? Row(
                    key: const ValueKey('done'),
                    children: [
                      Flexible(
                        child: DsStatusChip(label: "Setup was done.".tr, tone: DsTone.success),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('pending'),
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: DsStatusChip(label: "Your Setup is pending".tr, tone: DsTone.warning),
                        ),
                      ),
                      const DsGap(DsSpace.sm),
                      DsButton.tonal(label: "Setup now".tr, icon: Icons.add_link_rounded, size: DsButtonSize.sm, onPressed: onSetup),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
