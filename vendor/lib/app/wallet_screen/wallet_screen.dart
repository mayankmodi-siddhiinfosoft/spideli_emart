import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:vendor/app/wallet_screen/wallet_tabs.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/wallet_controller.dart';
import 'package:vendor/models/withdrawal_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: WalletController(),
      builder: (controller) {
        return DsScaffold(
          title: "Wallet".tr,
          body: DsAsync(
            isLoading: controller.isLoading.value,
            skeleton: const _WalletSkeleton(),
            builder: (context) {
              final hero = _BalanceHero(
                controller: controller,
                onWithdraw: () {
                  if ((Constant.userModel!.userBankDetails != null && Constant.userModel!.userBankDetails!.accountNumber.isNotEmpty) ||
                      controller.withdrawMethodModel.value.id != null) {
                    withdrawalCardBottomSheet(context, controller);
                  } else {
                    ShowToastDialog.showToast("Please setup payment method".tr);
                  }
                },
                onDownload: () {
                  controller.createAndSavePdf();
                },
                onFilter: () {
                  datePicker(context, controller);
                },
              );
              final tabs = DefaultTabController(
                length: 3,
                initialIndex: controller.selectedTabIndex.value,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DsTabBar(
                      onTap: (value) {
                        controller.selectedTabIndex.value = value;
                      },
                      tabs: ["Earnings".tr, "Commissions".tr, "Payouts".tr],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          WalletEarningsTab(controller: controller, isDark: isDark),
                          WalletCommissionsTab(controller: controller, isDark: isDark),
                          WalletPayoutsTab(controller: controller, isDark: isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              return DsResponsiveBuilder(
                builder: (context, l) {
                  if (l.isWide) {
                    // Tablet / iPad: balance column on the left, activity on the right.
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 400,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, 0, DsSpace.xxl),
                            child: DsFadeSlideIn(child: hero),
                          ),
                        ),
                        const DsGap(DsSpace.sm),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: DsSpace.sm),
                            child: tabs,
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.xs),
                        child: DsFadeSlideIn(child: hero),
                      ),
                      Expanded(child: tabs),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future datePicker(BuildContext context, WalletController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final c = context.dsColors;
        return DsSheet(
          title: "Filter".tr,
          showClose: true,
          actions: Row(
            children: [
              Expanded(
                child: DsButton.secondary(
                  label: "Clear".tr,
                  expand: true,
                  onPressed: () async {
                    Get.back();
                    await controller.getWalletTransaction(false);
                  },
                ),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: DsButton.primary(
                  label: "Filter".tr,
                  icon: Icons.filter_alt_rounded,
                  expand: true,
                  onPressed: () async {
                    Get.back();
                    await controller.getWalletTransaction(true);
                  },
                ),
              ),
            ],
          ),
          child: SizedBox(
            height: 320,
            child: SfDateRangePicker(
              backgroundColor: c.surfaceRaised,
              selectionColor: c.brand,
              startRangeSelectionColor: c.brand,
              endRangeSelectionColor: c.brand,
              rangeSelectionColor: c.brandSoft,
              todayHighlightColor: c.brand,
              onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                // Store the selected date range
                if (args.value is PickerDateRange) {
                  controller.startDate.value = args.value.startDate;
                  controller.endDate.value = args.value.endDate;
                }
              },
              selectionMode: DateRangePickerSelectionMode.range,
              maxDate: DateTime.now(),
              initialSelectedRange: PickerDateRange(controller.startDate.value, controller.endDate.value),
            ),
          ),
        );
      },
    );
  }

  Future withdrawalCardBottomSheet(BuildContext context, WalletController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        child: StatefulBuilder(
          builder: (context1, setState) {
            final c = context1.dsColors;
            final t = context1.dsText;
            return Obx(
              () => Scaffold(
                backgroundColor: c.surfaceRaised,
                body: SingleChildScrollView(
                  child: DsResponsive(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(top: DsSpace.xs, bottom: DsSpace.md),
                              decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
                            ),
                          ),
                          Row(
                            children: [
                              const DsIconWell(icon: Icons.north_east_rounded, tone: DsTone.brand, size: 44),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Withdrawal".tr, style: t.title),
                                    const DsGap(DsSpace.xxs),
                                    Text(
                                      "${"Total Wallet amount".tr}: ${Constant.amountShow(amount: controller.storeBalance.toString())}",
                                      style: t.bodySm.withColor(c.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              DsIconButton(
                                icon: Icons.close_rounded,
                                semanticLabel: 'Close'.tr,
                                variant: DsIconButtonVariant.tonal,
                                onPressed: () {
                                  Get.back();
                                },
                              ),
                            ],
                          ),
                          const DsGap(DsSpace.xl),
                          DsTextField(
                            label: 'Withdrawal amount'.tr,
                            controller: controller.amountTextFieldController.value,
                            hint: 'Enter withdrawal amount'.tr,
                            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                            textInputAction: TextInputAction.done,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                            prefix: Padding(
                              padding: const EdgeInsetsDirectional.only(start: DsSpace.lg, end: DsSpace.sm),
                              child: Text("${Constant.currencyModel!.symbol}".tr, style: t.title.withColor(c.textPrimary)),
                            ),
                          ),
                          DsTextField(
                            label: 'Notes'.tr,
                            controller: controller.noteTextFieldController.value,
                            hint: 'Add Notes'.tr,
                            prefixIcon: Icons.notes_rounded,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: DsSpace.xs, bottom: DsSpace.md),
                            child: Text("Select Withdraw Method".tr, style: t.titleSm),
                          ),
                          Constant.userModel!.userBankDetails == null || Constant.userModel!.userBankDetails!.accountNumber.isEmpty
                              ? const SizedBox()
                              : _WithdrawMethodOption(
                                  value: 0,
                                  groupValue: controller.selectedValue.value,
                                  title: "Bank Transfer".tr,
                                  icon: SvgPicture.asset("assets/icons/ic_building_four.svg", colorFilter: ColorFilter.mode(c.textPrimary, BlendMode.srcIn)),
                                  onSelect: (value) {
                                    controller.selectedValue.value = value;
                                  },
                                ),
                          controller.withdrawMethodModel.value.flutterWave == null || (controller.flutterWaveSettingData.value.isWithdrawEnabled == false)
                              ? const SizedBox()
                              : _WithdrawMethodOption(
                                  value: 1,
                                  groupValue: controller.selectedValue.value,
                                  title: "Flutter wave".tr,
                                  icon: Image.asset("assets/images/flutterwave.png"),
                                  onSelect: (value) {
                                    controller.selectedValue.value = value;
                                  },
                                ),
                          controller.withdrawMethodModel.value.paypal == null || (controller.paypalDataModel.value.isWithdrawEnabled == false)
                              ? const SizedBox()
                              : _WithdrawMethodOption(
                                  value: 2,
                                  groupValue: controller.selectedValue.value,
                                  title: "PayPal".tr,
                                  icon: Image.asset("assets/images/paypal.png"),
                                  onSelect: (value) {
                                    controller.selectedValue.value = value;
                                  },
                                ),
                          controller.withdrawMethodModel.value.razorpay == null || (controller.razorPayModel.value.isWithdrawEnabled == false)
                              ? const SizedBox()
                              : _WithdrawMethodOption(
                                  value: 3,
                                  groupValue: controller.selectedValue.value,
                                  title: "RazorPay".tr,
                                  icon: Image.asset("assets/images/razorpay.png"),
                                  onSelect: (value) {
                                    controller.selectedValue.value = value;
                                  },
                                ),
                          controller.withdrawMethodModel.value.stripe == null || (controller.stripeSettingData.value.isWithdrawEnabled == false)
                              ? const SizedBox()
                              : _WithdrawMethodOption(
                                  value: 4,
                                  groupValue: controller.selectedValue.value,
                                  title: "Stripe".tr,
                                  icon: Image.asset("assets/images/stripe.png"),
                                  onSelect: (value) {
                                    controller.selectedValue.value = value;
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
                bottomNavigationBar: DsStickyBar(
                  child: DsButton.primary(
                    label: "Withdraw".tr,
                    icon: Icons.north_east_rounded,
                    size: DsButtonSize.lg,
                    expand: true,
                    onPressed: () async {
                      if (controller.amountTextFieldController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter amount".tr);
                      } else if (controller.noteTextFieldController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter note".tr);
                      } else if ((double.tryParse(controller.amountTextFieldController.value.text) ?? 0) <= 0) {
                        ShowToastDialog.showToast("Please enter a valid amount".tr);
                      } else if (controller.storeBalance <= 0 || double.parse(controller.amountTextFieldController.value.text) > controller.storeBalance) {
                        // Withdrawals come out of this store's own balance,
                        // as in the store panel's Payouts screen.
                        ShowToastDialog.showToast("You are not able to place Withdraw request due to insufficient wallet amount".tr);
                      } else {
                        WithdrawalModel withdrawHistory = WithdrawalModel(
                          amount: controller.amountTextFieldController.value.text,
                          vendorID: controller.vendorModel.value.id ?? controller.userModel.value.vendorID,
                          paymentStatus: "Pending",
                          paidDate: Timestamp.now(),
                          id: Constant.getUuid(),
                          note: controller.noteTextFieldController.value.text,
                          withdrawMethod: controller.selectedValue.value == 0
                              ? "bank"
                              : controller.selectedValue.value == 1
                              ? "flutterwave"
                              : controller.selectedValue.value == 2
                              ? "paypal"
                              : controller.selectedValue.value == 3
                              ? "razorpay"
                              : "stripe",
                        );
                        final double withdrawAmount = double.parse(controller.amountTextFieldController.value.text);
                        final String vendorId = controller.vendorModel.value.id ?? controller.userModel.value.vendorID ?? '';
                        final String ownerId = controller.vendorModel.value.author ?? FireStoreUtils.getCurrentUid();
                        ShowToastDialog.showLoader("Please wait".tr);
                        // Debit first, with the balance re-checked inside the
                        // transaction, so a double tap or a second device
                        // can't withdraw the same money twice.
                        try {
                          final num? debited = await FireStoreUtils.adjustVendorWallet(
                            amount: -withdrawAmount,
                            vendorId: vendorId,
                            ownerId: ownerId,
                            requireStoreFunds: true,
                          );
                          if (debited == null) {
                            ShowToastDialog.closeLoader();
                            ShowToastDialog.showToast("Could not place withdraw request. Please try again.".tr);
                            return;
                          }
                        } on InsufficientStoreFunds {
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("You are not able to place Withdraw request due to insufficient wallet amount".tr);
                          return;
                        }
                        final bool created = await FireStoreUtils.withdrawWalletAmount(withdrawHistory);
                        if (!created) {
                          // Put the money back rather than leave a debit with no payout request.
                          await FireStoreUtils.adjustVendorWallet(amount: withdrawAmount, vendorId: vendorId, ownerId: ownerId);
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("Could not place withdraw request. Please try again.".tr);
                          return;
                        }
                        ShowToastDialog.closeLoader();
                        Get.back();
                        FireStoreUtils.sendPayoutMail(amount: controller.amountTextFieldController.value.text, payoutrequestid: withdrawHistory.id.toString());
                        controller.getWalletTransaction(false);
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Deep-gradient balance card: total balance counter, order/tax summary and
/// the wallet actions (withdraw, statement, date filter).
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.controller, required this.onWithdraw, required this.onDownload, required this.onFilter});

  final WalletController controller;
  final VoidCallback onWithdraw;
  final VoidCallback onDownload;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final canWithdraw =
        !((controller.userModel.value.isDocumentVerify == false && controller.userModel.value.isAutoVerify == false) ||
            (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty));
    return DsCard.gradient(
      gradient: DsGradients.deep(context),
      padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.lg, DsSpace.md, DsSpace.lg),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative brand glow in the top corner.
          PositionedDirectional(
            top: -80,
            end: -60,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [context.dsColors.brand.withValues(alpha: 0.45), context.dsColors.brand.withValues(alpha: 0)]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const DsIconWell(icon: Icons.account_balance_wallet_rounded, onBrand: true, size: 40),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Text(
                        "Total Wallet amount".tr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.label.withColor(Colors.white.withValues(alpha: 0.82)),
                      ),
                    ),
                    DsIconButton(icon: Icons.filter_alt_rounded, semanticLabel: 'Filter'.tr, color: Colors.white, onPressed: onFilter),
                  ],
                ),
                const DsGap(DsSpace.md),
                Semantics(
                  label: "Total Wallet amount".tr,
                  value: Constant.amountShow(amount: controller.storeBalance.toString()),
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: DsAnimatedCounter(
                      value: controller.storeBalance,
                      format: (v) => Constant.amountShow(amount: v.toString()),
                      style: t.metricLg.withColor(Colors.white),
                    ),
                  ),
                ),
                const DsGap(DsSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: DsStatTile(
                        variant: DsStatTileVariant.onBrand,
                        icon: Icons.receipt_long_rounded,
                        label: "Order Amount".tr,
                        countTo: controller.orderAmount.value,
                        format: (v) => Constant.amountShow(amount: v.toString()),
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: DsStatTile(
                        variant: DsStatTileVariant.onBrand,
                        icon: Icons.percent_rounded,
                        label: "Total Tax.".tr,
                        countTo: controller.taxAmount.value,
                        format: (v) => Constant.amountShow(amount: v.toString()),
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                Wrap(
                  spacing: DsSpace.md,
                  runSpacing: DsSpace.sm,
                  children: [
                    if (canWithdraw) DsButton.primary(label: "Withdraw".tr, icon: Icons.north_east_rounded, onPressed: onWithdraw),
                    DsButton.secondary(label: "Download Statement".tr, icon: Icons.download_rounded, onPressed: onDownload),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable payout-method card with a radio.
class _WithdrawMethodOption extends StatelessWidget {
  const _WithdrawMethodOption({required this.value, required this.groupValue, required this.title, required this.icon, required this.onSelect});

  final int value;
  final int groupValue;
  final String title;
  final Widget icon;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final selected = value == groupValue;
    return AnimatedContainer(
      duration: DsMotion.of(context, DsMotion.base),
      curve: DsMotion.standard,
      margin: const EdgeInsets.only(bottom: DsSpace.md),
      decoration: BoxDecoration(
        color: selected ? c.brandSoft : c.surface,
        borderRadius: DsRadius.brLg,
        border: Border.all(color: selected ? c.brand : c.border, width: selected ? 1.4 : 1),
      ),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        label: title,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: DsRadius.brLg,
            onTap: () {
              onSelect(value);
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.md, DsSpace.sm, DsSpace.xs, DsSpace.sm),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(DsSpace.md),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: DsRadius.brMd,
                      border: Border.all(color: c.border),
                    ),
                    child: icon,
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(child: Text(title, style: t.bodyStrong)),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: AnimatedContainer(
                        duration: DsMotion.of(context, DsMotion.fast),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? c.brand : c.borderStrong, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedScale(
                          duration: DsMotion.of(context, DsMotion.base),
                          curve: DsMotion.spring,
                          scale: selected ? 1 : 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DsSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsSkeleton.box(height: 250, radius: DsRadius.xl),
            const DsGap(DsSpace.xl),
            DsSkeleton.box(height: 48, radius: DsRadius.pill),
            const DsGap(DsSpace.lg),
            DsSkeleton.box(height: 110, radius: DsRadius.lg),
            const DsGap(DsSpace.lg),
            for (var i = 0; i < 4; i++) ...[
              Row(
                children: [
                  DsSkeleton.box(width: 44, height: 44, radius: DsRadius.md),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [DsSkeleton.line(width: 160, height: 14), const DsGap(DsSpace.sm), DsSkeleton.line(width: 100)],
                    ),
                  ),
                  DsSkeleton.line(width: 64, height: 14),
                ],
              ),
              const DsGap(DsSpace.lg),
            ],
          ],
        ),
      ),
    );
  }
}
