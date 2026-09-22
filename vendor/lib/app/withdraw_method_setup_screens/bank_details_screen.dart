import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/controller/bank_details_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class BankDetailsScreen extends StatelessWidget {
  const BankDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: BankDetailsController(),
      builder: (controller) {
        final l = context.dsLayout;
        final t = context.dsText;
        return DsScaffold(
          title: "Bank Setup".tr,
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.xxl),
            child: DsResponsive(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: DsFadeSlideIn.stagger([
                  DsCard.tinted(
                    tone: DsTone.info,
                    child: Row(
                      children: [
                        const DsIconWell(icon: Icons.account_balance_rounded, tone: DsTone.info, size: 48),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Bank Transfer".tr, style: t.titleSm),
                              const DsGap(DsSpace.xxs),
                              Text("Withdrawals are paid out to this account.".tr, style: t.bodySm.withColor(context.dsColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DsGap(DsSpace.lg),
                  DsFormSection(
                    title: "Account details".tr,
                    icon: Icons.badge_outlined,
                    children: [
                      DsAdaptiveGrid(
                        minItemWidth: 260,
                        maxColumns: 2,
                        spacing: DsSpace.md,
                        runSpacing: 0,
                        equalHeight: false,
                        children: [
                          DsTextField(
                            label: 'Bank Name'.tr,
                            controller: controller.bankNameController.value,
                            hint: 'Enter Bank Name'.tr,
                            prefixIcon: Icons.account_balance_outlined,
                          ),
                          DsTextField(
                            label: 'Branch Name'.tr,
                            controller: controller.branchNameController.value,
                            hint: 'Enter Branch Name'.tr,
                            prefixIcon: Icons.location_city_outlined,
                          ),
                          DsTextField(
                            label: 'Holder Name'.tr,
                            controller: controller.holderNameController.value,
                            hint: 'Enter Holder Name'.tr,
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                          DsTextField(
                            label: 'Account Number'.tr,
                            controller: controller.accountNoController.value,
                            hint: 'Enter Account Number'.tr,
                            prefixIcon: Icons.numbers_rounded,
                          ),
                        ],
                      ),
                      DsTextField(
                        label: 'Other Information'.tr,
                        controller: controller.otherInfoController.value,
                        hint: 'Enter Other Information'.tr,
                        prefixIcon: Icons.notes_rounded,
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Add Bank".tr,
              icon: Icons.check_rounded,
              expand: true,
              size: DsButtonSize.lg,
              onPressed: () async {
                controller.saveBank();
              },
            ),
          ),
        );
      },
    );
  }
}
