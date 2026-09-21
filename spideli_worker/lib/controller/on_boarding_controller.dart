import 'package:spideliworker/model/on_boarding_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OnBoardingController extends GetxController {
  var selectedPageIndex = 0.obs;

  bool get isLastPage => selectedPageIndex.value == onBoardingList.length - 1;
  var pageController = PageController();

  @override
  void onInit() {
    getOnBoardingData();
    super.onInit();
  }

  RxBool isLoading = true.obs;
  RxList<OnBoardingModel> onBoardingList = <OnBoardingModel>[].obs;

  Future<void> getOnBoardingData() async {
    await FireStoreUtils.getOnBoardingList().then((value) {
      onBoardingList.value = value;
      isLoading.value = false;
    });
    update();
  }
  // getOnBoardingData() async {
  //   onBoardingList.add(OnBoardingModel(
  //       image: "assets/images/onBoarding_1.svg",
  //       id: "1",
  //       description: "Manage your work schedule, view bookings, and update their status - all in one place.",
  //       title: "Welcome to spideli Worker!"));
  //   onBoardingList.add(OnBoardingModel(
  //       image: "assets/images/onBoarding_2.svg",
  //       id: "2",
  //       description: "Manage bookings, chat in multiple languages, and get things done efficiently with spideli Worker.",
  //       title: "Work Simplified, Globally."));
  //   onBoardingList.add(OnBoardingModel(
  //       image: "assets/images/onBoarding_3.svg",
  //       id: "3",
  //       description: "See booking details, update status, and chat with ease. spideli Worker - Available in multiple languages.",
  //       title: "Your All-in-One Work App."));
  //   update();
  //   isLoading.value = false;
  // }
}
