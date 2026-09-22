import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/user.dart';

import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/controller/verification_controller.dart';
import 'package:spideliworker/ui/booking_list/booking_list.dart';
import 'package:spideliworker/ui/documents/documents_screen.dart';
import 'package:spideliworker/ui/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DashBoardController extends GetxController {
  RxBool isLoading = true.obs;

  RxInt selectedIndex = 0.obs;

  RxList pageList = [
    const BookingListScreen(),
    const DocumentsScreen(),
    ProfileScreen(),
  ].obs;

  PageController pageController = PageController(
    initialPage: 0,
  );

  void onItemTapped(int index) {
    selectedIndex.value = index;
    pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Rx<User> user = User().obs;
  RxString userId = ''.obs;

  @override
  void onInit() {
    // Verification status + worker region, read by Jobs / Documents / Profile.
    Get.put(VerificationController());
    getData();
    super.onInit();
  }

  @override
  void onClose() {
    Get.delete<VerificationController>(force: true);
    super.onClose();
  }

  void getData() {
    FireStoreUtils.getWorkerCurrentUser(MyAppState.currentUser!.id.toString()).then((value) {
      MyAppState.currentUser = value;
    });

    isLoading.value = false;
    FireStoreUtils.getPlaceHolderImage();

    /// On iOS, we request notification permissions, Does nothing and returns null on Android
    FireStoreUtils.firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }
}

class DrawerItem {
  String title;
  String icon;

  DrawerItem(this.title, this.icon);
}
