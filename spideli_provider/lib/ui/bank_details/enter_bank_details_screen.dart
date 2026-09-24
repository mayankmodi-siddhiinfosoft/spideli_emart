import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/bank_details_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Bank details form (archetype F). One grouped form section capped at the
/// content width, with the save action pinned in a sticky bar so it stays
/// reachable above the keyboard.
class EnterBankDetailScreen extends StatelessWidget {
  const EnterBankDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<BankDetailsController>(
      init: BankDetailsController(),
      builder: (controller) {
        return DsScaffold(
          title: "${controller.title.value.toString()}",
          onBack: () => Navigator.pop(context),
          maxContentWidth: DsLayout.contentMax,
          body: Form(
            key: controller.bankDetailFormKey.value,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: DsFadeSlideIn.stagger([
                  DsFormSection(
                    title: "Bank details".tr,
                    icon: Icons.account_balance_outlined,
                    children: [
                      buildTextFiled(validator: validateName, title: "Bank Name".tr, controller: controller.bankNameController.value, context: context),
                      buildTextFiled(validator: validateOthers, title: "Branch Name".tr, controller: controller.branchNameController.value, context: context),
                    ],
                  ),
                  DsFormSection(
                    title: "Account holder".tr,
                    icon: Icons.badge_outlined,
                    children: [
                      buildTextFiled(validator: validateOthers, title: "Holder Name".tr, controller: controller.holderNameController.value, context: context),
                      buildTextFiled(validator: validateOthers, title: "Account Number".tr, controller: controller.accountNoController.value, context: context),
                      buildTextFiled(
                        validator: (String? value) {
                          return null;
                        },
                        title: "Other Information".tr,
                        controller: controller.otherInfoController.value,
                        context: context,
                        last: true,
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: controller.title.toString(),
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () async {
                if (controller.bankDetailFormKey.value.currentState!.validate()) {
                  controller.user.value.userBankDetails.accountNumber = controller.accountNoController.value.text.toString();
                  controller.user.value.userBankDetails.bankName = controller.bankNameController.value.text.toString();
                  controller.user.value.userBankDetails.branchName = controller.branchNameController.value.text.toString();
                  controller.user.value.userBankDetails.holderName = controller.holderNameController.value.text.toString();
                  controller.user.value.userBankDetails.otherDetails = controller.otherInfoController.value.text.toString();

                  var updatedUser = await FireStoreUtils.updateCurrentUser(controller.user.value);
                  if (updatedUser != null) {
                    MyAppState.currentUser = updatedUser;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bank Details saved successfully'.tr, style: TextStyle(fontSize: 17))));
                    Get.back(result: true);
                    // Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not save details, Please try again.".tr, style: TextStyle(fontSize: 17))));
                    Get.back();
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget buildTextFiled({required String title, required String? Function(String?)? validator, required TextEditingController controller, required BuildContext context, bool last = false}) {
    return DsTextField(label: title, hint: "Enter $title", validator: validator, controller: controller, textInputAction: TextInputAction.next, bottomSpacing: last ? 0 : DsSpace.lg);
  }
}
