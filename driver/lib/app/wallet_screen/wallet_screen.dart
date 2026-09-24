import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/wallet_screen/payment_list_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/wallet_controller.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/parcel_order_model.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/models/wallet_transaction_model.dart';
import 'package:driver/models/withdrawal_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../constant/collection_name.dart';
import '../cab_screen/cab_order_details.dart';
import '../order_list_screen/order_details_screen.dart';
import '../parcel_screen/parcel_order_details.dart';
import '../rental_service/rental_order_details_screen.dart';

/// Archetype E – earnings / wallet: a deep gradient hero with the animated
/// balance, the Withdraw / Top up pair overlapping it, then the history as
/// segmented tabs of tone-coded transaction rows.
class WalletScreen extends StatelessWidget {
  final bool? isAppBarShow;

  const WalletScreen({super.key, required this.isAppBarShow});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      // The theme observable read must stay inside this Obx: it is what
      // rebuilds the wallet when the driver switches light / dark mode.
      themeController.isDark.value;
      return GetX(
          init: WalletController(),
          builder: (controller) {
            final c = context.dsColors;
            final t = context.dsText;

            // Read every observable here, inside the tracked builder.
            final bool isLoading = controller.isLoading.value;
            final num balance = controller.userModel.value.walletAmount ?? 0;
            final int tab = controller.selectedTabIndex.value;
            final List<WalletTransactionModel> transactions = controller.walletTopTransactionList.toList();
            final List<WithdrawalModel> withdrawals = controller.withdrawalList.toList();
            final bool hasBankOrMethod = (Constant.userModel!.userBankDetails != null && Constant.userModel!.userBankDetails!.accountNumber.isNotEmpty) ||
                controller.withdrawMethodModel.value.id != null;

            final Widget history;
            if (isLoading) {
              history = const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DsSpace.lg),
                  child: DsSkeletonList(itemCount: 6, trailing: true, carded: true),
                ),
              );
            } else if (tab == 0) {
              history = transactions.isEmpty
                  ? SliverToBoxAdapter(
                      child: DsEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: "Transaction history not found".tr,
                      ),
                    )
                  : SliverList.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.sm),
                        child: DsFadeSlideIn(
                          index: index,
                          child: _TransactionRow(
                            title: transactions[index].note.toString(),
                            subtitle: Constant.timestampToDateTime(transactions[index].date!),
                            amount: transactions[index].isTopup == false
                                ? "-${Constant.amountShow(amount: transactions[index].amount.toString())}"
                                : Constant.amountShow(amount: transactions[index].amount.toString()),
                            credit: transactions[index].isTopup == true,
                            onTap: () => _openOrder(transactions[index]),
                          ),
                        ),
                      ),
                    );
            } else {
              history = withdrawals.isEmpty
                  ? SliverToBoxAdapter(
                      child: DsEmptyState(
                        icon: Icons.account_balance_outlined,
                        title: "Withdrawal history not found".tr,
                      ),
                    )
                  : SliverList.builder(
                      itemCount: withdrawals.length,
                      itemBuilder: (context, index) {
                        final w = withdrawals[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: DsSpace.sm),
                          child: DsFadeSlideIn(
                            index: index,
                            child: _TransactionRow(
                              title: w.note.toString(),
                              subtitle: Constant.timestampToDateTime(w.paidDate!),
                              caption: "(${w.withdrawMethod!.capitalizeString()})",
                              amount: "-${Constant.amountShow(amount: w.amount.toString())}",
                              credit: false,
                              statusLabel: w.paymentStatus.toString(),
                              statusTone: w.paymentStatus == "Success"
                                  ? DsTone.success
                                  : w.paymentStatus == "Pending"
                                      ? DsTone.brand
                                      : DsTone.danger,
                              onTap: () async {},
                            ),
                          ),
                        );
                      },
                    );
            }

            return DsScaffold.hero(
              title: "Wallet".tr,
              showBack: isAppBarShow == true,
              heroGradient: DsGradients.deep(context),
              hero: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "My Wallet".tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.bodySm.copyWith(color: Colors.white.withValues(alpha: 0.78)),
                  ),
                  const DsGap(DsSpace.xs),
                  DsAnimatedCounter(
                    value: balance,
                    format: (v) => Constant.amountShow(amount: v.toString()),
                    style: DsTypography.metricLg.copyWith(color: Colors.white),
                  ),
                ],
              ),
              heroOverlap: DsCard(
                child: Row(
                  children: [
                    Expanded(
                      child: DsButton.secondary(
                        label: "Withdraw".tr,
                        icon: Icons.arrow_upward_rounded,
                        expand: true,
                        onPressed: () {
                          if (hasBankOrMethod) {
                            withdrawalCardBottomSheet(context, controller);
                          } else {
                            ShowToastDialog.showToast("Please enter payment method".tr);
                          }
                        },
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: DsButton.primary(
                        label: "Top up".tr,
                        icon: Icons.add_rounded,
                        expand: true,
                        onPressed: () {
                          Get.to(const PaymentListScreen());
                        },
                      ),
                    ),
                  ],
                ),
              ),
              slivers: [
                DsSliverResponsive(
                  top: DsSpace.xl,
                  sliver: SliverToBoxAdapter(
                    child: DsSegmentedTabs(
                      segments: [
                        DsSegment("Wallet History".tr),
                        DsSegment("Withdrawal History".tr),
                      ],
                      index: tab,
                      onChanged: (value) {
                        controller.selectedTabIndex.value = value;
                      },
                    ),
                  ),
                ),
                DsSliverResponsive(
                  top: DsSpace.lg,
                  bottom: DsSpace.xxxl,
                  sliver: history,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                    child: Text(
                      "${'Withdraw amount must be greater or equal to'.tr} ${Constant.amountShow(amount: Constant.minimumAmountToWithdrawal)}",
                      style: t.caption.withColor(c.textMuted),
                    ),
                  ),
                ),
              ],
            );
          });
    });
  }

  /// Opens the order behind a wallet transaction (unchanged routing).
  Future<void> _openOrder(WalletTransactionModel transactionModel) async {
    final orderId = transactionModel.orderId.toString();
    final orderData = await FireStoreUtils.getOrderByIdFromAllCollections(orderId);

    if (orderData != null) {
      final collection = orderData['collection_name'];

      switch (collection) {
        case CollectionName.parcelOrders:
          Get.to(const ParcelOrderDetails(), arguments: ParcelOrderModel.fromJson(orderData));
          break;
        case CollectionName.rentalOrders:
          Get.to(() => RentalOrderDetailsScreen(), arguments: {"rentalOrder": orderId});
          break;
        case CollectionName.ridesBooking:
          Get.to(const CabOrderDetails(), arguments: {"cabOrderModel": CabOrderModel.fromJson(orderData)});
          break;
        case CollectionName.vendorOrders:
          Get.to(const OrderDetailsScreen(), arguments: {"orderModel": OrderModel.fromJson(orderData)});
          break;
        default:
          ShowToastDialog.showToast("Order details not available");
      }
    }
  }

  Future withdrawalCardBottomSheet(BuildContext context, WalletController controller) {
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        builder: (context) => FractionallySizedBox(
              heightFactor: 0.8,
              child: StatefulBuilder(builder: (context1, setState) {
                final c = DsColors.of(context);
                final t = context.dsText;
                // Reads inside this Obx keep the method selection reactive.
                return Obx(
                  () {
                    final int selected = controller.selectedValue.value;
                    final bool showBank = !(Constant.userModel!.userBankDetails == null || Constant.userModel!.userBankDetails!.accountNumber.isEmpty);
                    final bool showFlutterWave =
                        !(controller.withdrawMethodModel.value.flutterWave == null || (controller.flutterWaveModel.value.isWithdrawEnabled == false));
                    final bool showPaypal = !(controller.withdrawMethodModel.value.paypal == null || (controller.payPalModel.value.isWithdrawEnabled == false));
                    final bool showRazorpay = !(controller.withdrawMethodModel.value.razorpay == null || (controller.razorPayModel.value.isWithdrawEnabled == false));
                    final bool showStripe = !(controller.withdrawMethodModel.value.stripe == null || (controller.stripeModel.value.isWithdrawEnabled == false));

                    return Scaffold(
                      backgroundColor: c.surfaceRaised,
                      body: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
                                ),
                              ),
                              const DsGap(DsSpace.lg),
                              Row(
                                children: [
                                  Expanded(child: Text("Withdrawal".tr, style: t.title)),
                                  DsIconButton(
                                    icon: Icons.close_rounded,
                                    semanticLabel: 'Cancel'.tr,
                                    onPressed: () {
                                      Get.back();
                                    },
                                  ),
                                ],
                              ),
                              const DsGap(DsSpace.lg),
                              DsTextField(
                                label: 'Withdrawal amount'.tr,
                                controller: controller.amountTextFieldController.value,
                                hint: 'Enter withdrawal amount'.tr,
                                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                                ],
                                prefix: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                                  child: Text("${Constant.currencyModel!.symbol}".tr, style: t.title.tabular),
                                ),
                              ),
                              DsTextField(
                                label: 'Notes'.tr,
                                controller: controller.noteTextFieldController.value,
                                hint: 'Add Notes'.tr,
                                prefixIcon: Icons.notes_rounded,
                              ),
                              DsInlineAlert(
                                tone: DsTone.info,
                                icon: Icons.info_outline_rounded,
                                message:
                                    "${'Withdraw amount must be greater or equal to'.tr} ${Constant.amountShow(amount: Constant.minimumAmountToWithdrawal)}",
                              ),
                              const DsGap(DsSpace.xl),
                              Text("Select Withdraw Method".tr, style: t.titleSm),
                              const DsGap(DsSpace.md),
                              if (showBank)
                                _MethodOption(
                                  label: "Bank Transfer".tr,
                                  logo: SvgPicture.asset("assets/icons/ic_building_four.svg"),
                                  value: 0,
                                  groupValue: selected,
                                  onSelected: (value) => controller.selectedValue.value = value,
                                ),
                              if (showFlutterWave)
                                _MethodOption(
                                  label: "Flutter wave".tr,
                                  logo: Image.asset("assets/images/flutterwave.png"),
                                  value: 1,
                                  groupValue: selected,
                                  onSelected: (value) => controller.selectedValue.value = value,
                                ),
                              if (showPaypal)
                                _MethodOption(
                                  label: "PayPal".tr,
                                  logo: Image.asset("assets/images/paypal.png"),
                                  value: 2,
                                  groupValue: selected,
                                  onSelected: (value) => controller.selectedValue.value = value,
                                ),
                              if (showRazorpay)
                                _MethodOption(
                                  label: "RazorPay".tr,
                                  logo: Image.asset("assets/images/razorpay.png"),
                                  value: 3,
                                  groupValue: selected,
                                  onSelected: (value) => controller.selectedValue.value = value,
                                ),
                              if (showStripe)
                                _MethodOption(
                                  label: "Stripe".tr,
                                  logo: Image.asset("assets/images/stripe.png"),
                                  value: 4,
                                  groupValue: selected,
                                  onSelected: (value) => controller.selectedValue.value = value,
                                ),
                            ],
                          ),
                        ),
                      ),
                      bottomNavigationBar: DsStickyBar(
                        child: DsButton.primary(
                          label: "Withdraw".tr,
                          icon: Icons.arrow_upward_rounded,
                          size: DsButtonSize.lg,
                          expand: true,
                          onPressed: () async {
                            if (controller.amountTextFieldController.value.text.isEmpty) {
                              ShowToastDialog.showToast("Please enter amount".tr);
                            } else if (double.parse(Constant.minimumAmountToWithdrawal) >
                                double.parse(controller.amountTextFieldController.value.text)) {
                              ShowToastDialog.showToast(
                                  "${'Withdraw amount must be greater or equal to'.tr} ${Constant.amountShow(amount: Constant.minimumAmountToWithdrawal)}");
                            } else {
                              WithdrawalModel withdrawHistory = WithdrawalModel(
                                amount: controller.amountTextFieldController.value.text,
                                driverID: controller.userModel.value.id,
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
                              await FireStoreUtils.withdrawWalletAmount(withdrawHistory);
                              await FireStoreUtils.updateUserWallet(
                                      amount: "-${controller.amountTextFieldController.value.text}", userId: FireStoreUtils.getCurrentUid())
                                  .then((value) {
                                Get.back();
                                FireStoreUtils.sendPayoutMail(
                                    amount: controller.amountTextFieldController.value.text,
                                    payoutrequestid: withdrawHistory.id.toString());
                                controller.getWalletTransaction();
                              });
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              }),
            ));
  }

  Widget transactionCardForOrder(bool isDark, List<OrderModel> list) {
    return list.isEmpty
        ? Constant.showEmptyView(message: "Transaction history not found".tr, isDark: isDark)
        : ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (context, index) {
              OrderModel walletTractionModel = list[index];

              double amount = 0;
              if (walletTractionModel.deliveryCharge != null && walletTractionModel.deliveryCharge!.isNotEmpty) {
                amount += double.parse(walletTractionModel.deliveryCharge!);
              }

              if (walletTractionModel.tipAmount != null && walletTractionModel.tipAmount!.isNotEmpty) {
                amount += double.parse(walletTractionModel.tipAmount!);
              }

              return _OrderEarningRow(
                title: "Completed Delivery".tr,
                amount: Constant.amountShow(amount: amount.toString()),
                date: Constant.timestampToDateTime(walletTractionModel.createdAt!),
              );
            },
            separatorBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
              );
            },
          );
  }

  Widget parcelTransactionCardForOrder(bool isDark, List<ParcelOrderModel> list) {
    return list.isEmpty
        ? Constant.showEmptyView(message: "Transaction history not found".tr, isDark: isDark)
        : ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (context, index) {
              ParcelOrderModel orderModel = list[index];

              double totalAmount = 0.0;
              double totalTax = 0.0;
              double subTotal = double.parse(orderModel.subTotal ?? '0.0') - double.parse(orderModel.discount ?? '0.0');

              if (orderModel.taxSetting != null) {
                for (var element in orderModel.taxSetting!) {
                  totalTax = totalTax + Constant.calculateTax(amount: subTotal.toString(), taxModel: element);
                }
              }
              totalAmount = subTotal + totalTax;

              return _OrderEarningRow(
                title: "Parcel Amount credited".tr,
                amount: Constant.amountShow(amount: totalAmount.toString()),
                date: Constant.timestampToDateTime(orderModel.createdAt!),
              );
            },
            separatorBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
              );
            },
          );
  }

  Widget rentalTransactionCardForOrder(bool isDark, List<RentalOrderModel> list) {
    return list.isEmpty
        ? Constant.showEmptyView(message: "Transaction history not found".tr, isDark: isDark)
        : ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (context, index) {
              RentalOrderModel orderModel = list[index];
              RxDouble subTotal = 0.0.obs;
              RxDouble discount = 0.0.obs;
              RxDouble taxAmount = 0.0.obs;
              RxDouble totalAmount = 0.0.obs;
              RxDouble extraKilometerCharge = 0.0.obs;
              RxDouble extraMinutesCharge = 0.0.obs;

              subTotal.value = double.tryParse(orderModel.subTotal?.toString() ?? "0") ?? 0.0;
              discount.value = double.tryParse(orderModel.discount?.toString() ?? "0") ?? 0.0;

              if (orderModel.endTime != null) {
                DateTime start = orderModel.startTime!.toDate();
                DateTime end = orderModel.endTime!.toDate();
                int hours = end.difference(start).inHours;
                if (hours >= int.parse(orderModel.rentalPackageModel!.includedHours.toString())) {
                  hours = hours - int.parse(orderModel.rentalPackageModel!.includedHours.toString());
                  double hourlyRate = double.tryParse(orderModel.rentalPackageModel?.extraMinuteFare?.toString() ?? "0") ?? 0.0;
                  extraMinutesCharge.value = (hours * 60) * hourlyRate;
                }
              }

              if (orderModel.startKitoMetersReading != null && orderModel.endKitoMetersReading != null) {
                double startKm = double.tryParse(orderModel.startKitoMetersReading?.toString() ?? "0") ?? 0.0;
                double endKm = double.tryParse(orderModel.endKitoMetersReading?.toString() ?? "0") ?? 0.0;
                if (endKm > startKm) {
                  double totalKm = endKm - startKm;
                  if (totalKm > double.parse(orderModel.rentalPackageModel!.includedDistance!)) {
                    totalKm = totalKm - double.parse(orderModel.rentalPackageModel!.includedDistance!);
                    double extraKmRate = double.tryParse(orderModel.rentalPackageModel?.extraKmFare?.toString() ?? "0") ?? 0.0;
                    extraKilometerCharge.value = totalKm * extraKmRate;
                  }
                }
              }
              subTotal.value = subTotal.value + extraKilometerCharge.value + extraMinutesCharge.value;

              if (orderModel.taxSetting != null) {
                for (var element in orderModel.taxSetting!) {
                  taxAmount.value += Constant.calculateTax(amount: (subTotal.value - discount.value).toString(), taxModel: element);
                }
              }

              totalAmount.value = (subTotal.value - discount.value) + taxAmount.value;

              return _OrderEarningRow(
                title: "Completed Delivery".tr,
                amount: Constant.amountShow(amount: totalAmount.toString()),
                date: Constant.timestampToDateTime(orderModel.createdAt!),
              );
            },
            separatorBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
              );
            },
          );
  }

  Widget cabTransactionCardForOrder(bool isDark, List<CabOrderModel> list) {
    return list.isEmpty
        ? Constant.showEmptyView(message: "Transaction history not found".tr, isDark: isDark)
        : ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (context, index) {
              CabOrderModel orderModel = list[index];

              double totalAmount = 0.0;
              double totalTax = 0.0;
              double subTotal = double.parse(orderModel.subTotal ?? '0.0') - double.parse(orderModel.discount ?? '0.0');

              if (orderModel.taxSetting != null) {
                for (var element in orderModel.taxSetting!) {
                  totalTax = totalTax + Constant.calculateTax(amount: subTotal.toString(), taxModel: element);
                }
              }
              totalAmount = subTotal + totalTax;

              return _OrderEarningRow(
                title: "Completed Delivery".tr,
                amount: Constant.amountShow(amount: totalAmount.toString()),
                date: Constant.timestampToDateTime(orderModel.createdAt!),
              );
            },
            separatorBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
              );
            },
          );
  }
}

/// Wallet / withdrawal row: tone-coded icon well, note, meta and amount.
class _TransactionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? caption;
  final String amount;
  final bool credit;
  final String? statusLabel;
  final DsTone? statusTone;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.title,
    required this.subtitle,
    this.caption,
    required this.amount,
    required this.credit,
    this.statusLabel,
    this.statusTone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpace.md),
      semanticLabel: title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsIconWell(
            icon: credit ? Icons.south_west_rounded : Icons.north_east_rounded,
            tone: credit ? DsTone.success : DsTone.danger,
            size: 44,
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong),
                if (caption != null) Text(caption!, style: t.caption),
                const DsGap(DsSpace.xxs),
                Row(
                  children: [
                    if (statusLabel != null) ...[
                      DsStatusChip(label: statusLabel!, tone: statusTone),
                      const DsGap(DsSpace.sm),
                    ],
                    Flexible(
                      child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Text(
            amount,
            style: t.titleSm.tabular.withColor(credit ? c.successStrong : c.dangerStrong),
          ),
        ],
      ),
    );
  }
}

/// Earning row used by the per-service earning lists.
class _OrderEarningRow extends StatelessWidget {
  final String title;
  final String amount;
  final String date;

  const _OrderEarningRow({required this.title, required this.amount, required this.date});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
      child: Row(
        children: [
          const DsIconWell(icon: Icons.south_west_rounded, tone: DsTone.success, size: 44),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyStrong),
                Text(date, style: t.caption),
              ],
            ),
          ),
          Text(amount, style: t.titleSm.tabular.withColor(c.successStrong)),
        ],
      ),
    );
  }
}

/// Withdraw method choice inside the withdrawal sheet.
class _MethodOption extends StatelessWidget {
  final String label;
  final Widget logo;
  final int value;
  final int groupValue;
  final ValueChanged<int> onSelected;

  const _MethodOption({
    required this.label,
    required this.logo,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final selected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsCard.outlined(
        onTap: () => onSelected(value),
        borderColor: selected ? c.brand : null,
        color: selected ? c.brandSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        semanticLabel: label,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(DsSpace.sm),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: DsRadius.brSm,
                border: Border.all(color: c.border),
              ),
              child: logo,
            ),
            const DsGap(DsSpace.md),
            Expanded(
              child: Text(label, style: selected ? t.bodyStrong.withColor(c.brandStrong) : t.bodyStrong),
            ),
            Semantics(
              selected: selected,
              child: IconButton(
                icon: Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? c.brand : c.textMuted,
                ),
                tooltip: label,
                onPressed: () => onSelected(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
