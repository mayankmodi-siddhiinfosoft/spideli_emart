import 'dart:io';

import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:get/get.dart';

class ProfileController extends GetxController {
  Rx<User> provider = User().obs;
  RxBool online = true.obs;

  RxString firstName = ''.obs;
  RxString lastName = ''.obs;
  RxString email = ''.obs;
  File? image;

  @override
  void onInit() {
    super.onInit();
    getData();
  }

  void getData() async {
    await FireStoreUtils.getWorkerCurrentUser(MyAppState.currentUser!.id.toString()).then((value) {
      MyAppState.currentUser = value;
      firstName.value = MyAppState.currentUser?.firstName ?? '';
      lastName.value = MyAppState.currentUser?.lastName ?? '';
      email.value = MyAppState.currentUser?.email ?? '';
      online.value = MyAppState.currentUser?.online ?? false;
    });

    await FireStoreUtils.getProviderUser(MyAppState.currentUser!.providerId.toString()).then((value) {
      provider.value = value!;
    });
    update();
  }
}
