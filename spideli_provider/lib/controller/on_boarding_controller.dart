import 'package:spideliprovider/model/on_boarding_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
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

  // getOnBoardingData() async {
  //   onBoardingList.add(OnBoardingModel(image: "assets/images/onBoarding_1.svg", id: "1", description: "Manage your business, workers, and services – all in one place.", title: "Welcome to spideli-Provider!"));
  //   onBoardingList.add(OnBoardingModel(image: "assets/images/onBoarding_2.svg", id: "2", description: "Add services, assign tasks, and track progress effortlessly..", title: "Simplify Your Workflow"));
  //   onBoardingList.add(OnBoardingModel(image: "assets/images/onBoarding_3.svg", id: "3", description: "Add & manage workers, assign tasks, and boost collaboration.", title: "Build Your Dream Team"));
  //   update();
  //   isLoading.value = false;
  // }


  getOnBoardingData() async {
    await FireStoreUtils.getOnBoardingList().then((value) {
      onBoardingList.value = value;
      isLoading.value = false;
    });
    update();
  }
}
