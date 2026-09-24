import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/bank_details_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Archetype H – payout details form: one grouped section, a reassurance line
/// and Save pinned to the bottom.
class BankDetailsScreen extends StatelessWidget {
  const BankDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: BankDetailsController(),
        builder: (controller) {
          return DsScaffold(
            title: "Bank Setup".tr,
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
              child: DsResponsive(
                maxWidth: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: DsFadeSlideIn.stagger([
                    DsInlineAlert(
                      tone: DsTone.info,
                      icon: Icons.account_balance_outlined,
                      message: "Your earnings are transferred to this account.".tr,
                    ),
                    const DsGap(DsSpace.lg),
                    DsFormSection(
                      title: "Bank Transfer".tr,
                      icon: Icons.account_balance_rounded,
                      children: [
                        DsTextField(
                          label: 'Bank Name'.tr,
                          controller: controller.bankNameController.value,
                          hint: 'Enter Bank Name'.tr,
                          requiredMark: true,
                          prefixIcon: Icons.account_balance_outlined,
                          textCapitalization: TextCapitalization.words,
                        ),
                        DsTextField(
                          label: 'Branch Name'.tr,
                          controller: controller.branchNameController.value,
                          hint: 'Enter Branch Name'.tr,
                          requiredMark: true,
                          prefixIcon: Icons.location_city_outlined,
                          textCapitalization: TextCapitalization.words,
                        ),
                        DsTextField(
                          label: 'Holder Name'.tr,
                          controller: controller.holderNameController.value,
                          hint: 'Enter Holder Name'.tr,
                          requiredMark: true,
                          prefixIcon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                        ),
                        DsTextField(
                          label: 'Account Number'.tr,
                          controller: controller.accountNoController.value,
                          hint: 'Enter Account Number'.tr,
                          requiredMark: true,
                          prefixIcon: Icons.numbers_rounded,
                        ),
                        DsTextField(
                          label: 'Other Information'.tr,
                          controller: controller.otherInfoController.value,
                          hint: 'Enter Other Information'.tr,
                          prefixIcon: Icons.notes_rounded,
                          maxLines: 3,
                          minLines: 2,
                          bottomSpacing: 0,
                        ),
                      ],
                    ),
                  ], offset: const Offset(0, 18)),
                ),
              ),
            ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: "Save Details".tr,
                icon: Icons.check_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () {
                  if (controller.bankNameController.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter bank name".tr);
                  } else if (controller.branchNameController.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter branch name".tr);
                  } else if (controller.holderNameController.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter holder name".tr);
                  } else if (controller.accountNoController.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter account number".tr);
                  } else {
                    controller.saveBank();
                  }
                },
              ),
            ),
          );
        });
  }
}
