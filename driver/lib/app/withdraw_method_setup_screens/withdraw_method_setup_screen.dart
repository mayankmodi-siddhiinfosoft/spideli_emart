import 'package:driver/app/withdraw_method_setup_screens/bank_details_screen.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/withdraw_method_setup_controller.dart';
import 'package:driver/models/withdraw_method_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

/// Archetype F/E – payout methods: one card per method with a clear
/// "configured / pending" state, an edit and a remove action, and the setup
/// forms in DS dialogs.
class WithdrawMethodSetupScreen extends StatelessWidget {
  const WithdrawMethodSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: WithdrawMethodSetupController(),
        builder: (controller) {
          final c = context.dsColors;

          // Read the observables inside the tracked builder.
          final bool bankAdded = controller.isBankDetailsAdded.value;
          final bool flutterWaveAdded = controller.withdrawMethodModel.value.flutterWave != null;
          final bool paypalAdded = controller.withdrawMethodModel.value.paypal != null;
          final bool razorpayAdded = controller.withdrawMethodModel.value.razorpay != null;
          final bool stripeAdded = controller.withdrawMethodModel.value.stripe != null;

          Future<void> removeMethod(void Function() clear) async {
            clear();
            await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
              (value) async {
                ShowToastDialog.showLoader("Please wait.".tr);

                await controller.getPaymentMethod();
                ShowToastDialog.closeLoader();
                ShowToastDialog.showToast("Payment Method remove successfully".tr);
              },
            );
          }

          void openBankSetup() {
            Get.to(const BankDetailsScreen())!.then((value) {
              if (value != null && value == true) {
                controller.getPaymentSettings();
                controller.isBankDetailsAdded.value = true;
              }
            });
          }

          return Scaffold(
            backgroundColor: c.background,
            body: DsAsync(
              isLoading: controller.isLoading.value,
              skeleton: const Padding(
                padding: EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
                child: DsSkeletonList(itemCount: 4, trailing: false),
              ),
              builder: (_) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
                child: DsResponsive(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: DsFadeSlideIn.stagger([
                      DsInlineAlert(
                        tone: DsTone.info,
                        icon: Icons.payments_outlined,
                        message: "Set up at least one method to receive your withdrawals.".tr,
                      ),
                      const DsGap(DsSpace.lg),
                      _MethodCard(
                        name: "Bank Transfer".tr,
                        logo: SvgPicture.asset("assets/icons/ic_building_four.svg"),
                        configured: bankAdded,
                        onEdit: openBankSetup,
                        onSetup: openBankSetup,
                      ),
                      const DsGap(DsSpace.md),
                      _MethodCard(
                        name: "Flutter wave".tr,
                        logo: Image.asset("assets/images/flutterwave.png"),
                        configured: flutterWaveAdded,
                        onEdit: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return flutterWaveDialog(controller);
                            },
                          );
                        },
                        onSetup: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return flutterWaveDialog(controller);
                            },
                          );
                        },
                        onDelete: flutterWaveAdded
                            ? () async {
                                await removeMethod(() => controller.withdrawMethodModel.value.flutterWave = null);
                              }
                            : null,
                      ),
                      const DsGap(DsSpace.md),
                      _MethodCard(
                        name: "PayPal".tr,
                        logo: Image.asset("assets/images/paypal.png"),
                        configured: paypalAdded,
                        onEdit: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return payPalDialog(controller);
                            },
                          );
                        },
                        onSetup: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return payPalDialog(controller);
                            },
                          );
                        },
                        onDelete: paypalAdded
                            ? () async {
                                await removeMethod(() => controller.withdrawMethodModel.value.paypal = null);
                              }
                            : null,
                      ),
                      const DsGap(DsSpace.md),
                      _MethodCard(
                        name: "RazorPay".tr,
                        logo: Image.asset("assets/images/razorpay.png"),
                        configured: razorpayAdded,
                        onEdit: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return razorPayDialog(controller);
                            },
                          );
                        },
                        onSetup: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return razorPayDialog(controller);
                            },
                          );
                        },
                        onDelete: razorpayAdded
                            ? () async {
                                await removeMethod(() => controller.withdrawMethodModel.value.razorpay = null);
                              }
                            : null,
                      ),
                      const DsGap(DsSpace.md),
                      _MethodCard(
                        name: "Stripe".tr,
                        logo: Image.asset("assets/images/stripe.png"),
                        configured: stripeAdded,
                        onEdit: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return stripeDialog(controller);
                            },
                          );
                        },
                        onSetup: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return stripeDialog(controller);
                            },
                          );
                        },
                        onDelete: stripeAdded
                            ? () async {
                                await removeMethod(() => controller.withdrawMethodModel.value.stripe = null);
                              }
                            : null,
                      ),
                    ], offset: const Offset(0, 18)),
                  ),
                ),
              ),
            ),
          );
        });
  }

  Widget flutterWaveDialog(WithdrawMethodSetupController controller) {
    return _SetupDialog(
      title: "Flutter wave".tr,
      icon: Icons.account_balance_wallet_outlined,
      fields: [
        DsTextField(
          label: 'Account Number'.tr,
          controller: controller.accountNumberFlutterWave.value,
          hint: 'Account Number'.tr,
        ),
        DsTextField(
          label: 'Bank Code'.tr,
          controller: controller.bankCodeFlutterWave.value,
          hint: 'Bank Code'.tr,
          bottomSpacing: 0,
        ),
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
                name: "FlutterWave");
          }
          controller.withdrawMethodModel.value.flutterWave = flutterWave;
          await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
            (value) async {
              ShowToastDialog.showLoader("Please wait.".tr);

              await controller.getPaymentMethod();
              ShowToastDialog.closeLoader();
              ShowToastDialog.showToast("Payment Method save successfully".tr);
              Get.back();
            },
          );
        }
      },
    );
  }

  Widget payPalDialog(WithdrawMethodSetupController controller) {
    return _SetupDialog(
      title: "PayPal".tr,
      icon: Icons.alternate_email_rounded,
      fields: [
        DsTextField(
          label: 'Paypal Email'.tr,
          controller: controller.emailPaypal.value,
          hint: 'Paypal Email'.tr,
          keyboardType: TextInputType.emailAddress,
          bottomSpacing: 0,
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
          await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
            (value) async {
              ShowToastDialog.showLoader("Please wait.".tr);

              await controller.getPaymentMethod();
              ShowToastDialog.closeLoader();
              ShowToastDialog.showToast("Payment Method save successfully".tr);
              Get.back();
            },
          );
        }
      },
    );
  }

  Widget razorPayDialog(WithdrawMethodSetupController controller) {
    return _SetupDialog(
      title: "RazorPay".tr,
      icon: Icons.badge_outlined,
      helper: "Add your Account ID. For example, acc_GLGeLkU2JUeyDZ".tr,
      fields: [
        DsTextField(
          label: 'Razorpay account Id'.tr,
          controller: controller.accountIdRazorPay.value,
          hint: 'Razorpay account Id'.tr,
          bottomSpacing: 0,
        ),
      ],
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
          await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
            (value) async {
              ShowToastDialog.showLoader("Please wait.".tr);

              await controller.getPaymentMethod();
              ShowToastDialog.closeLoader();
              ShowToastDialog.showToast("Payment Method save successfully".tr);
              Get.back();
            },
          );
        }
      },
    );
  }

  Widget stripeDialog(WithdrawMethodSetupController controller) {
    return _SetupDialog(
      title: "Stripe".tr,
      icon: Icons.badge_outlined,
      helper:
          "Go to your Stripe account settings > Account details > Copy your account ID on the right-hand side. For example, acc_GLGeLkU2JUeyDZ"
              .tr,
      fields: [
        DsTextField(
          label: 'Stripe Account Id'.tr,
          controller: controller.accountIdStripe.value,
          hint: 'Stripe Account Id'.tr,
          bottomSpacing: 0,
        ),
      ],
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
          await FireStoreUtils.setWithdrawMethod(controller.withdrawMethodModel.value).then(
            (value) async {
              ShowToastDialog.showLoader("Please wait.".tr);

              await controller.getPaymentMethod();
              ShowToastDialog.closeLoader();
              ShowToastDialog.showToast("Payment Method save successfully".tr);
              Get.back();
            },
          );
        }
      },
    );
  }
}

/// One payout method: logo, name, setup state and its actions.
class _MethodCard extends StatelessWidget {
  final String name;
  final Widget logo;
  final bool configured;
  final VoidCallback onEdit;
  final VoidCallback onSetup;
  final VoidCallback? onDelete;

  const _MethodCard({
    required this.name,
    required this.logo,
    required this.configured,
    required this.onEdit,
    required this.onSetup,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                padding: const EdgeInsets.all(DsSpace.sm),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: DsRadius.brMd,
                  border: Border.all(color: c.border),
                ),
                child: logo,
              ),
              const DsGap(DsSpace.md),
              Expanded(child: Text(name, style: t.titleSm)),
              if (configured || onDelete == null)
                DsIconButton(
                  icon: Icons.edit_outlined,
                  semanticLabel: "Edit".tr,
                  variant: DsIconButtonVariant.tonal,
                  onPressed: onEdit,
                ),
              if (onDelete != null) ...[
                const DsGap(DsSpace.sm),
                DsIconButton(
                  icon: Icons.delete_outline_rounded,
                  semanticLabel: "Delete".tr,
                  variant: DsIconButtonVariant.tonal,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          const DsGap(DsSpace.md),
          DsDivider(spacing: DsSpace.xs),
          const DsGap(DsSpace.md),
          if (configured)
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: c.successStrong),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: Text("Setup was done.".tr, style: t.bodyStrong.withColor(c.successStrong)),
                ),
              ],
            )
          else
            Row(
              children: [
                DsStatusChip(label: "Your Setup is pending".tr, tone: DsTone.warning),
                const Spacer(),
                DsButton.tonal(
                  label: "Setup now".tr,
                  icon: Icons.add_rounded,
                  size: DsButtonSize.sm,
                  onPressed: onSetup,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Setup form shown in a dialog (the call sites keep using `showDialog`).
class _SetupDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? helper;
  final List<Widget> fields;
  final VoidCallback onSave;

  const _SetupDialog({
    required this.title,
    required this.icon,
    this.helper,
    required this.fields,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Dialog(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.brXl),
      insetPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.xxl),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DsSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  DsIconWell(icon: icon, tone: DsTone.brand, size: 44),
                  const DsGap(DsSpace.md),
                  Expanded(child: Text(title, style: t.title)),
                  DsIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: 'Cancel'.tr,
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const DsGap(DsSpace.xl),
              ...fields,
              if (helper != null) ...[
                const DsGap(DsSpace.md),
                Text(helper!, style: t.bodySm),
              ],
              const DsGap(DsSpace.xl),
              DsButton.primary(
                label: "Save".tr,
                icon: Icons.check_rounded,
                expand: true,
                onPressed: onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
