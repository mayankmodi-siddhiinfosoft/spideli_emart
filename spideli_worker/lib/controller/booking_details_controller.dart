import 'package:spideliworker/model/rating_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/utils/args.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BookingDetailsController extends GetxController {
  RxList<RatingModel> ratingService = <RatingModel>[].obs;
  Rx<TextEditingController> chargesController = TextEditingController().obs;
  Rx<TextEditingController> descriptionController = TextEditingController().obs;
  RxString orderId = ''.obs;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Rx<DateTime> selectedDateTime = DateTime.now().obs;
  Rx<TextEditingController> dateTimeController = TextEditingController().obs;

  RxDouble subTotal = 0.0.obs;
  RxDouble price = 0.0.obs;
  RxDouble discount = 0.0.obs;
  RxDouble totalAmount = 0.0.obs;
  RxDouble adminComm = 0.0.obs;

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      // The wallet screen opens this for a transaction row, and a top-up row
      // carries no `orderId` at all — assigning that null into this RxString
      // threw and left the screen on an empty booking. The push handler can
      // pass a missing payload field the same way. See [argString].
      orderId.value = argString(argumentData, 'orderId');
    }
    await FireStoreUtils.getReviewByProviderServiceId(orderId.toString()).then((value) {
      ratingService.value = value;
    });
    update();
  }
}
