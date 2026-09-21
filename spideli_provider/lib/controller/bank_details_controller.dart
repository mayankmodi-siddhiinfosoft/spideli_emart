import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BankDetailsController extends GetxController {
  RxString title = "Add Bank".tr.obs;
  Rx<TextEditingController> bankNameController = TextEditingController().obs;
  Rx<TextEditingController> branchNameController = TextEditingController().obs;
  Rx<TextEditingController> holderNameController = TextEditingController().obs;
  Rx<TextEditingController> accountNoController = TextEditingController().obs;
  Rx<TextEditingController> otherInfoController = TextEditingController().obs;
  Rx<GlobalKey<FormState>> bankDetailFormKey = GlobalKey<FormState>().obs;
  Rx<User> user = User().obs;
  RxBool isBankDetailsAdded = false.obs;
  Rx<UserBankDetails> userBankDetails = UserBankDetails().obs;

  @override
  void onInit() {
    super.onInit();
    userBankDetails.value = MyAppState.currentUser!.userBankDetails;
    isBankDetailsAdded.value = userBankDetails.value.accountNumber.isNotEmpty;

    FireStoreUtils.getCurrentUser(MyAppState.currentUser!.id).then((value) {
      user.value = value!;
      MyAppState.currentUser = value;
      if (user.value.userBankDetails.accountNumber.isNotEmpty) {
        title.value = "Edit Bank".tr;
        bankNameController.value = TextEditingController(text: user.value.userBankDetails.bankName);
        branchNameController.value = TextEditingController(text: user.value.userBankDetails.branchName);
        holderNameController.value = TextEditingController(text: user.value.userBankDetails.holderName);
        accountNoController.value = TextEditingController(text: user.value.userBankDetails.accountNumber);
        otherInfoController.value = TextEditingController(text: user.value.userBankDetails.otherDetails);
      }
      update();
    });
  }
}
