import 'dart:io';

import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProfileController extends GetxController {
  Rx<User> user = User().obs;

  Rx<GlobalKey<FormState>> key = GlobalKey<FormState>().obs;
  AutovalidateMode validate = AutovalidateMode.disabled;
  Rx<TextEditingController> firstName = TextEditingController().obs;
  Rx<TextEditingController> lastName = TextEditingController().obs;
  Rx<TextEditingController> email = TextEditingController().obs;
  Rx<TextEditingController> mobile = TextEditingController().obs;
  File? image;

  RxBool isLoading = true.obs;
  @override
  void onInit() {
    // TODO: implement onInit
    getData();
    super.onInit();
  }

  getData() async {
    await FireStoreUtils.getCurrentUser(MyAppState.currentUser!.id).then((value) {
      print("======>");
      print(value!.phoneNumber);
      user.value = value;
      MyAppState.currentUser = value;
      firstName.value.text = MyAppState.currentUser!.firstName.toString();
      lastName.value.text = MyAppState.currentUser!.lastName.toString();
      email.value.text = MyAppState.currentUser!.email.toString();
      mobile.value.text = MyAppState.currentUser!.phoneNumber.toString();
      update();
      isLoading.value = false;
    });
  }
}
