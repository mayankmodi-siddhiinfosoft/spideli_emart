import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/bank_details_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class EnterBankDetailScreen extends StatelessWidget {
  const EnterBankDetailScreen({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<BankDetailsController>(
        init: BankDetailsController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
            appBar: AppBar(
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.arrow_back_ios,
                ),
              ),
              title: Text(
                "${controller.title.value.toString()}",
                style: TextStyle(color: themeChange.getTheme() ? AppColors.assetColorGrey100 : AppColors.assetColorGrey600, fontFamily: AppColors.semiBold, fontSize: 18),
              ),
            ),
            body: Form(
              key: controller.bankDetailFormKey.value,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 10,
                    ),
                    buildTextFiled(validator: validateName, title: "Bank Name".tr, controller: controller.bankNameController.value, context: context),
                    buildTextFiled(validator: validateOthers, title: "Branch Name".tr, controller: controller.branchNameController.value, context: context),
                    buildTextFiled(validator: validateOthers, title: "Holder Name".tr, controller: controller.holderNameController.value, context: context),
                    buildTextFiled(validator: validateOthers, title: "Account Number".tr, controller: controller.accountNoController.value, context: context),
                    buildTextFiled(validator: (String? value) {
                      return null;
                    }, title: "Other Information".tr, controller: controller.otherInfoController.value, context: context),
                    Padding(
                      padding: const EdgeInsets.only(top: 45.0, bottom: 25),
                      child: buildButton(context, title: controller.title.toString(), onPress: () async {
                        if (controller.bankDetailFormKey.value.currentState!.validate()) {
                          controller.user.value.userBankDetails.accountNumber = controller.accountNoController.value.text.toString();
                          controller.user.value.userBankDetails.bankName = controller.bankNameController.value.text.toString();
                          controller.user.value.userBankDetails.branchName = controller.branchNameController.value.text.toString();
                          controller.user.value.userBankDetails.holderName = controller.holderNameController.value.text.toString();
                          controller.user.value.userBankDetails.otherDetails = controller.otherInfoController.value.text.toString();

                          var updatedUser = await FireStoreUtils.updateCurrentUser(controller.user.value);
                          if (updatedUser != null) {
                            MyAppState.currentUser = updatedUser;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                              'Bank Details saved successfully'.tr,
                              style: TextStyle(fontSize: 17),
                            )));
                            Get.back(result: true);
                           // Navigator.pop(context, true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                              "Could not save details, Please try again.".tr,
                              style: TextStyle(fontSize: 17),
                            )));
                            Get.back();
                          }
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  Widget buildTextFiled({required title, required String? Function(String?)? validator, required TextEditingController controller, context}) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextFormField(
              style: TextStyle(color: themeChange.getTheme() ? Colors.white : Colors.black),
              cursorColor: AppColors.colorPrimary,
              textAlignVertical: TextAlignVertical.center,
              validator: validator,
              controller: controller,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                contentPadding: new EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                fillColor: themeChange.getTheme() ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.06),
                filled: true,
                hintText: "Enter ${title}",
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 1.50)),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                  borderRadius: BorderRadius.circular(5.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                  borderRadius: BorderRadius.circular(5.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  buildButton(context, {required String title, required Function()? onPress}) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      width: size.width * 0.8,
      child: MaterialButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        color:AppColors.colorPrimary,
        height: 45,
        onPressed: onPress,
        child: Text(
          title,
          style: TextStyle(fontSize: 19, color: Colors.white),
        ),
      ),
    );
  }
}
