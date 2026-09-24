import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/wallet_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/currency_model.dart';
import 'package:spideliprovider/model/topupTranHistory.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/model/withdrawHistoryModel.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/booking_list/booking_details_screen.dart';
import 'package:spideliprovider/ui/wallet/withdraw_history.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Wallet (archetype H – finance): deep-gradient balance hero with an animated
/// counter, credit/debit summary tiles built from the rows already loaded, and
/// a day-grouped transaction ledger. Drawer body, so it keeps exactly one
/// Scaffold and adds no app bar of its own.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<WalletController>(
      init: WalletController(),
      builder: (controller) {
        // Read the observables synchronously so this GetX tracks them: the
        // sliver/item builders below run later and would not be observed.
        final List<TopupTranHistoryModel> rows = controller.topupHistoryQuery.toList();
        final Map<String, CurrencyModel?> currencies = {for (final row in rows) row.id: controller.currencyForRow(row)};

        return DsScaffold(
          body: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, 0),
                  child: DsFadeSlideIn(child: _BalanceHero(controller: controller)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                  child: DsFadeSlideIn(
                    index: 1,
                    child: _LedgerSummary(rows: rows, currencies: currencies),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                  child: DsSectionHeader(title: "Transactions".tr, icon: Icons.receipt_long_outlined),
                ),
              ),
              ..._historySlivers(context, controller, rows, currencies),
              const SliverToBoxAdapter(child: SizedBox(height: DsSpace.xxxl)),
            ],
          ),
          bottomBar: DsStickyBar(
            child: Row(
              children: [
                Expanded(
                  child: DsButton.primary(
                    label: 'WITHDRAW'.tr,
                    icon: Icons.arrow_outward_rounded,
                    expand: true,
                    onPressed: () {
                      if (MyAppState.currentUser!.id.isNotEmpty) {
                        if (MyAppState.currentUser!.userBankDetails.accountNumber.isNotEmpty ||
                            (controller.withdrawMethodModel.value.id != null &&
                                (controller.withdrawMethodModel.value.flutterWave != null ||
                                    controller.withdrawMethodModel.value.paypal != null ||
                                    controller.withdrawMethodModel.value.razorpay != null ||
                                    controller.withdrawMethodModel.value.stripe != null))) {
                          withdrawAmount(context, controller);
                        } else {
                          ShowToastDialog.showToast("Please add payment method");
                        }
                      }
                    },
                  ),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: DsButton.secondary(
                    label: 'HISTORY',
                    icon: Icons.history_rounded,
                    expand: true,
                    onPressed: () {
                      Get.to(WithdrawHistoryScreen());
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Ledger rows grouped by day, each group introduced by a light date header.
  List<Widget> _historySlivers(BuildContext context, WalletController controller, List<TopupTranHistoryModel> rows, Map<String, CurrencyModel?> currencies) {
    if (rows.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xxl),
            child: DsEmptyState(icon: Icons.account_balance_wallet_outlined, title: "No transaction found".tr, message: "Earnings and deductions from your bookings will appear here.".tr),
          ),
        ),
      ];
    }

    final List<Widget> slivers = [];
    final DateFormat dayFormat = DateFormat('dd MMM yyyy');
    String? currentDay;
    List<TopupTranHistoryModel> bucket = [];
    int animationIndex = 0;

    void flush() {
      if (bucket.isEmpty) return;
      final String day = currentDay!;
      final List<TopupTranHistoryModel> group = List.of(bucket);
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg + DsSpace.xs, DsSpace.lg, DsSpace.lg, DsSpace.sm),
            child: Text(day, style: context.dsText.overline),
          ),
        ),
      );
      final int firstIndex = animationIndex;
      animationIndex += group.length;
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
          sliver: SliverList.separated(
            itemCount: group.length,
            separatorBuilder: (_, _) => const DsGap(DsSpace.sm),
            itemBuilder: (context, index) {
              final TopupTranHistoryModel topUpTranHistory = group[index];
              return DsFadeSlideIn(
                index: firstIndex + index,
                child: _TransactionRow(
                  topUpTranHistory: topUpTranHistory,
                  currency: currencies[topUpTranHistory.id],
                  onTap: () => showTransactionDetails(topupTranHistory: topUpTranHistory, context: context, currency: currencies[topUpTranHistory.id]),
                ),
              );
            },
          ),
        ),
      );
      bucket = [];
    }

    for (final TopupTranHistoryModel row in rows) {
      final String day = dayFormat.format(row.date.toDate());
      if (currentDay != null && day != currentDay) flush();
      currentDay = day;
      bucket.add(row);
    }
    flush();
    return slivers;
  }

  showTransactionDetails({required TopupTranHistoryModel topupTranHistory, required BuildContext context, CurrencyModel? currency}) {
    return showModalBottomSheet(
      elevation: 0,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final c = context.dsColors;
            final t = context.dsText;
            final bool credit = topupTranHistory.isTopup;
            final DsTone tone = credit ? DsTone.success : DsTone.danger;
            final String amount = credit
                ? "${"+"} ${amountShow(currency: currency, amount: topupTranHistory.amount.toString())}"
                : "(${"-"} ${amountShow(currency: currency, amount: topupTranHistory.amount.toString())})";
            return DsSheet(
              title: "Transaction Details".tr,
              showClose: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsCard.tinted(
                    tone: tone,
                    child: Column(
                      children: [
                        DsIconWell(icon: Icons.account_balance_wallet_rounded, tone: tone, size: 52, circle: true),
                        const DsGap(DsSpace.md),
                        Text(amount, textAlign: TextAlign.center, style: t.metric.tabular.withColor(c.tone(tone).strong)),
                        const DsGap(DsSpace.xs),
                        Text(topupTranHistory.isTopup ? "Order Amount".tr : "Admin commission Deducted".tr, textAlign: TextAlign.center, style: t.bodySecondary),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.lg),
                  DsTileGroup(
                    dividerIndent: DsSpace.lg,
                    children: [
                      DsListTile(
                        title: "Transaction ID".tr,
                        subtitle: topupTranHistory.id,
                        subtitleMaxLines: 2,
                        trailing: DsIconButton(
                          icon: Icons.copy_rounded,
                          semanticLabel: "Transaction ID".tr,
                          onPressed: () => Clipboard.setData(ClipboardData(text: topupTranHistory.id)),
                        ),
                      ),
                      DsListTile(title: "Date in UTC Format".tr, subtitle: DateFormat('KK:mm:ss a, dd MMM yyyy').format(topupTranHistory.date.toDate()).toUpperCase()),
                    ],
                  ),
                  const DsGap(DsSpace.lg),
                  DsButton.tonal(
                    label: "View Booking".tr.toUpperCase(),
                    icon: Icons.event_note_outlined,
                    expand: true,
                    onPressed: () async {
                      // await FireStoreUtils.firestore.collection(PROVIDER_ORDER).doc(topupTranHistory.orderId).get().then((value) {
                      //   OnProviderOrderModel onProviderOrder = OnProviderOrderModel.fromJson(value.data()!);
                      //
                      // });
                      Get.to(const BookingDetailsScreen(), arguments: {"orderId": topupTranHistory.orderId});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  withdrawAmount(BuildContext context, WalletController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final themeChange = Provider.of<DarkThemeProvider>(context);
            final c = context.dsColors;
            final t = context.dsText;
            return DsSheet(
              title: "Withdraw".tr,
              showClose: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MyAppState.currentUser!.userBankDetails.accountNumber.isEmpty
                            ? SizedBox()
                            : _PayoutOption(
                                label: "Bank Transfer",
                                asset: "assets/images/ic_bank_line.png",
                                tintAsset: themeChange.getTheme(),
                                value: 0,
                                groupValue: controller.selectedValue.value,
                                onTap: () {
                                  controller.selectedValue.value = 0;
                                },
                                onChanged: (value) {
                                  setState(() {
                                    controller.selectedValue.value = 0;
                                  });
                                },
                              ),
                        controller.withdrawMethodModel.value.id == null ||
                                controller.withdrawMethodModel.value.flutterWave == null ||
                                (controller.flutterWaveSettingData.value.isWithdrawEnabled != null && controller.flutterWaveSettingData.value.isWithdrawEnabled == false)
                            ? SizedBox()
                            : _PayoutOption(
                                asset: "assets/images/flutterwave.png",
                                tintAsset: themeChange.getTheme(),
                                value: 1,
                                groupValue: controller.selectedValue.value,
                                onTap: () {
                                  controller.selectedValue.value = 1;
                                },
                                onChanged: (value) {
                                  controller.selectedValue.value = 1;
                                },
                              ),
                        controller.withdrawMethodModel.value.id == null ||
                                controller.withdrawMethodModel.value.paypal == null ||
                                (controller.paypalDataModel.value.isWithdrawEnabled != null && controller.paypalDataModel.value.isWithdrawEnabled == false)
                            ? SizedBox()
                            : _PayoutOption(
                                asset: "assets/images/paypal.png",
                                tintAsset: themeChange.getTheme(),
                                value: 2,
                                groupValue: controller.selectedValue.value,
                                onTap: () {
                                  controller.selectedValue.value = 2;
                                },
                                onChanged: (value) {
                                  controller.selectedValue.value = 2;
                                },
                              ),
                        controller.withdrawMethodModel.value.id == null ||
                                controller.withdrawMethodModel.value.razorpay == null ||
                                (controller.razorPayModel.value.isWithdrawEnabled != null && controller.razorPayModel.value.isWithdrawEnabled == false)
                            ? SizedBox()
                            : _PayoutOption(
                                asset: "assets/images/razorpay.png",
                                tintAsset: themeChange.getTheme(),
                                value: 3,
                                groupValue: controller.selectedValue.value,
                                onTap: () {
                                  controller.selectedValue.value = 3;
                                },
                                onChanged: (value) {
                                  controller.selectedValue.value = 3;
                                },
                              ),
                        controller.withdrawMethodModel.value.id == null ||
                                controller.withdrawMethodModel.value.stripe == null ||
                                (controller.stripeSettingData.value.isWithdrawEnabled != null && controller.stripeSettingData.value.isWithdrawEnabled == false)
                            ? SizedBox()
                            : _PayoutOption(
                                asset: "assets/images/stripe.png",
                                tintAsset: themeChange.getTheme(),
                                value: 4,
                                groupValue: controller.selectedValue.value,
                                onTap: () {
                                  controller.selectedValue.value = 4;
                                },
                                onChanged: (value) {
                                  controller.selectedValue.value = 4;
                                },
                              ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.lg),
                  DsFieldLabel("Amount to Withdraw".tr),
                  const DsGap(DsSpace.sm),
                  TextFormField(
                    controller: controller.amountController.value,
                    style: t.metric.tabular.withColor(c.brandStrong),
                    //initialValue:"50",
                    maxLines: 1,
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "*required Field".tr;
                      } else {
                        if (double.parse(value) <= 0) {
                          return "*Invalid Amount".tr;
                        } else if (double.parse(value) > double.parse(controller.walletAmount.toString())) {
                          return "*withdraw is more then wallet balance".tr;
                        } else {
                          return null;
                        }
                      }
                    },
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: DsInputDecoration.of(
                      context,
                      prefix: Padding(
                        padding: const EdgeInsets.only(right: DsSpace.sm),
                        child: Text(currencyData!.symbol.toString(), style: t.title.w700),
                      ),
                    ),
                  ),
                  const DsGap(DsSpace.lg),
                  DsTextField(
                    label: 'Add note'.tr,
                    hint: 'Add note'.tr,
                    controller: controller.noteController.value,
                    maxLines: 1,
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "*required Field".tr;
                      }
                      return null;
                    },
                    keyboardType: TextInputType.text,
                    bottomSpacing: 0,
                  ),
                  const DsGap(DsSpace.xl),
                  DsButton.primary(
                    label: "WITHDRAW".tr,
                    icon: Icons.arrow_outward_rounded,
                    expand: true,
                    onPressed: () {
                      if (controller.amountController.value.text.isEmpty) {
                        ShowToastDialog.showToast("Please enter amount");
                      } else {
                        withdrawRequest(controller);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  withdrawRequest(WalletController controller) {
    Get.back();
    ShowToastDialog.showLoader("Please wait");

    FireStoreUtils.createPaymentId(collectionName: PAYOUTS).then((value) async {
      final paymentID = value;

      WithdrawHistoryModel withdrawHistory = WithdrawHistoryModel(
        amount: double.parse(controller.amountController.value.text.toString()),
        vendorID: controller.userId.value.toString(),
        paymentStatus: "Pending".tr,
        paidDate: Timestamp.now(),
        id: paymentID.toString(),
        note: controller.noteController.value.text,
        role: "provider",
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

      print(withdrawHistory.vendorID);

      await FireStoreUtils.withdrawWalletAmount(withdrawHistory: withdrawHistory).then((value) async {
        await FireStoreUtils.updateWalletAmount(userId: controller.userId.value.toString(), amount: -double.parse(controller.amountController.value.text)).whenComplete(() async {
          Get.back();
          controller.getData();
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("WithDraw request place successfully");
          await FireStoreUtils.sendPayoutMail(amount: controller.amountController.value.text, payoutrequestid: paymentID.toString());
        });
      });
    });
  }
}

/// Deep-gradient balance hero. The live balance keeps its original
/// [StreamBuilder] on `controller.userQuery`, wrapped in the DsAsync recipe.
class _BalanceHero extends StatelessWidget {
  final WalletController controller;

  const _BalanceHero({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return DsCard.gradient(
      gradient: DsGradients.deep(context),
      padding: const EdgeInsets.all(DsSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DsIconWell(icon: Icons.account_balance_wallet_rounded, size: 40, circle: true, onBrand: true),
              const DsGap(DsSpace.md),
              Expanded(child: Text("Total Balance".tr, style: t.label.withColor(Colors.white70))),
            ],
          ),
          const DsGap(DsSpace.lg),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: controller.userQuery,
            builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> asyncSnapshot) {
              return DsAsync(
                isLoading: asyncSnapshot.connectionState == ConnectionState.waiting,
                skeleton: const SizedBox(height: 44, width: 180, child: DsShimmer(child: _HeroSkeletonBar())),
                hasError: asyncSnapshot.hasError,
                error: Text("Error".tr, style: t.metricLg.withColor(Colors.white)),
                builder: (_) {
                  User userData = User.fromJson(asyncSnapshot.data!.data()!);
                  controller.walletAmount.value = userData.walletAmount.toString();
                  return DsAnimatedCounter(
                    value: userData.walletAmount,
                    format: (v) => amountShow(amount: v.toString()),
                    style: t.metricLg.tabular.withColor(Colors.white),
                  );
                },
              );
            },
          ),
          const DsGap(DsSpace.sm),
          Text("Available to withdraw".tr, style: t.caption.withColor(Colors.white70)),
        ],
      ),
    );
  }
}

class _HeroSkeletonBar extends StatelessWidget {
  const _HeroSkeletonBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.24), borderRadius: DsRadius.brSm),
    );
  }
}

/// Credit / debit totals derived from the rows the controller already loaded –
/// no extra queries.
class _LedgerSummary extends StatelessWidget {
  final List<TopupTranHistoryModel> rows;
  final Map<String, CurrencyModel?> currencies;

  const _LedgerSummary({required this.rows, required this.currencies});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    num credited = 0;
    num deducted = 0;
    for (final TopupTranHistoryModel row in rows) {
      if (row.isTopup) {
        credited += row.amount;
      } else {
        deducted += row.amount;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.lg),
      child: DsAdaptiveGrid(
        minItemWidth: 150,
        children: [
          DsStatTile(
            label: "Credited".tr,
            countTo: credited,
            format: (v) => amountShow(amount: v.toString()),
            icon: Icons.south_west_rounded,
            tone: DsTone.success,
            variant: DsStatTileVariant.tinted,
          ),
          DsStatTile(
            label: "Deducted".tr,
            countTo: deducted,
            format: (v) => amountShow(amount: v.toString()),
            icon: Icons.north_east_rounded,
            tone: DsTone.danger,
            variant: DsStatTileVariant.tinted,
          ),
        ],
      ),
    );
  }
}

/// One ledger row: tone icon well, note, timestamp and a signed, tabular
/// amount coloured by direction.
class _TransactionRow extends StatelessWidget {
  final TopupTranHistoryModel topUpTranHistory;
  final CurrencyModel? currency;
  final VoidCallback onTap;

  const _TransactionRow({required this.topUpTranHistory, required this.currency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool credit = topUpTranHistory.isTopup;
    final DsTone tone = credit ? DsTone.success : DsTone.danger;
    return DsCard.outlined(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: DsListTile(
        leading: DsIconWell(icon: credit ? Icons.south_west_rounded : Icons.north_east_rounded, tone: tone, size: 44, circle: true),
        title: topUpTranHistory.note.toString(),
        subtitle: DateFormat('KK:mm:ss a, dd MMM yyyy').format(topUpTranHistory.date.toDate()).toUpperCase(),
        trailing: Text(
          credit ? "${"+"} ${amountShow(currency: currency, amount: topUpTranHistory.amount.toString())}" : "(${"-"} ${amountShow(currency: currency, amount: topUpTranHistory.amount.toString())})",
          textAlign: TextAlign.end,
          style: t.titleSm.tabular.withColor(c.tone(tone).strong),
        ),
        showChevron: true,
      ),
    );
  }
}

/// Selectable payout-method row used inside the withdraw sheet. The Radio and
/// its `onChanged` are kept so the original selection logic is unchanged.
class _PayoutOption extends StatelessWidget {
  final String? label;
  final String asset;
  final bool tintAsset;
  final int value;
  final int groupValue;
  final VoidCallback onTap;
  final ValueChanged<int?> onChanged;

  const _PayoutOption({this.label, required this.asset, required this.tintAsset, required this.value, required this.groupValue, required this.onTap, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool selected = groupValue == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsCard.outlined(
        onTap: onTap,
        borderColor: selected ? c.brand : null,
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
        child: Row(
          children: [
            Image.asset(asset, height: 22, color: tintAsset ? c.textPrimary : null),
            if (label != null) ...[const DsGap(DsSpace.md), Expanded(child: Text(label!, style: t.bodyStrong))] else const Expanded(child: SizedBox()),
            Radio<int>(
              value: value,
              visualDensity: const VisualDensity(horizontal: VisualDensity.minimumDensity, vertical: VisualDensity.minimumDensity),
              groupValue: groupValue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
