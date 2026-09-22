import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/wallet_controller.dart';
import 'package:spideliprovider/model/withdrawHistoryModel.dart';
import 'package:spideliprovider/services/region_service.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/common_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class WithdrawHistoryScreen extends StatelessWidget {
  const WithdrawHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<WalletController>(
        init: WalletController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
            appBar: CommonUI.customAppBar(context,
                title: Text(
                  "Withdraw History".tr,
                  style: TextStyle(color: themeChange.getTheme() ? AppColors.assetColorGrey100 : AppColors.assetColorGrey600, fontFamily: AppColors.semiBold, fontSize: 18),
                ),
                isBack: true),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: controller.withdrawHistoryQuery.isEmpty
                  ? emptyView(text: 'No Withdraw history found',themeChange: themeChange)
                  : ListView.builder(
                  shrinkWrap: true,
                  itemCount: controller.withdrawHistoryQuery.length,
                  itemBuilder: (context, index) {
                    return buildTransactionCard(
                      context,
                      withdrawHistory: controller.withdrawHistoryQuery[index],
                      date: controller.withdrawHistoryQuery[index].paidDate.toDate(),
                    );
                  }),
            ),
          );
        });
  }

  Widget buildTransactionCard(
    context, {
    required WithdrawHistoryModel withdrawHistory,
    required DateTime date,
  }) {
    return GestureDetector(
      onTap: () => showWithdrawalModelSheet(context, withdrawHistory),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipOval(
                child: Container(
                  color: Colors.green.withOpacity(0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Icon(Icons.account_balance_wallet_rounded, size: 28, color: Color(0xFF00B761)),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 5.0),
                    child: SizedBox(
                      //width: Responsive.width(60, context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${DateFormat('MMM dd, yyyy, KK:mma').format(withdrawHistory.paidDate.toDate()).toUpperCase()}",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          Opacity(
                            opacity: 0.75,
                            child: Text(
                              withdrawHistory.paymentStatus,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 17,
                                color: withdrawHistory.paymentStatus == "Success" ? Colors.green : Colors.deepOrangeAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 3.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "- ${amountShow(currency: RegionService.currencyForBooking(withdrawHistory.regionId), amount: (withdrawHistory.amount.toString()))}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: withdrawHistory.paymentStatus == "Success" ? Colors.green : Colors.deepOrangeAccent,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 15,
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  showWithdrawalModelSheet(BuildContext context, WithdrawHistoryModel withdrawHistoryModel) {
    return showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
        ),
        builder: (context) {
          final themeChange = Provider.of<DarkThemeProvider>(context);
          return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 5, left: 10, right: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        'Withdrawal Details'.tr,
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 5.0),
                            child: SizedBox(
                              width: Responsive.width(70, context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Transaction ID".tr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 17,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Opacity(
                                    opacity: 0.55,
                                    child: Text(
                                      withdrawHistoryModel.id,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 17,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipOval(
                            child: Container(
                              color: Colors.green.withOpacity(0.06),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Icon(Icons.account_balance_wallet_rounded, size: 28, color: Color(0xFF00B761)),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 5.0),
                                    child: SizedBox(
                                      width: Responsive.width(50, context),
                                      child: Text(
                                        "${DateFormat('MMM dd, yyyy').format(withdrawHistoryModel.paidDate.toDate()).toUpperCase()}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Opacity(
                                    opacity: 0.75,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 5.0),
                                      child: Text(
                                        withdrawHistoryModel.paymentStatus,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 17,
                                          color: withdrawHistoryModel.paymentStatus == "Success" ? Colors.green : Colors.deepOrangeAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 3.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      " ${amountShow(currency: RegionService.currencyForBooking(withdrawHistoryModel.regionId), amount: withdrawHistoryModel.amount.toString())}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: withdrawHistoryModel.paymentStatus == "Success" ? Colors.green : Colors.deepOrangeAccent,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Date".tr,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 17,
                            ),
                          ),
                          Opacity(
                            opacity: 0.75,
                            child: Text(
                              "${DateFormat('MMM dd, yyyy, KK:mma').format(withdrawHistoryModel.paidDate.toDate()).toUpperCase()}",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Visibility(
                          visible: withdrawHistoryModel.note.isNotEmpty,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Note".tr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 17,
                                  ),
                                ),
                                Opacity(
                                  opacity: 0.75,
                                  child: Text(
                                    withdrawHistoryModel.note,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Visibility(
                          visible: withdrawHistoryModel.note.isNotEmpty && withdrawHistoryModel.adminNote.isNotEmpty,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Divider(
                              thickness: 2,
                              height: 1,
                              color: themeChange.getTheme() ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        Visibility(
                            visible: withdrawHistoryModel.adminNote.isNotEmpty,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Admin Note".tr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 17,
                                    ),
                                  ),
                                  Opacity(
                                    opacity: 0.75,
                                    child: Text(
                                      withdrawHistoryModel.adminNote,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                      ],
                    ),
                  ),
                ],
              ));
        });
  }
}
