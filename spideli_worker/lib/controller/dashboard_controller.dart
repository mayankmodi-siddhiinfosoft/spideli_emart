import 'package:spideliworker/main.dart';
import 'package:spideliworker/model/user.dart';

import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/ui/booking_list/booking_list.dart';
import 'package:spideliworker/ui/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DashBoardController extends GetxController {
  RxBool isLoading = true.obs;

  RxInt selectedIndex = 0.obs;

  RxList pageList = [
    const BookingListScreen(),
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
    // TODO: implement onInit

    getData();
    super.onInit();
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
