import 'package:spideliprovider/model/rating_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/utils/args.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BookingDetailsController extends GetxController {
  RxList<RatingModel> ratingService = <RatingModel>[].obs;
  Rx<TextEditingController> chargesController = TextEditingController().obs;
  Rx<TextEditingController> descriptionController = TextEditingController().obs;
  RxString workerName = ''.obs;

  Rx<User> worker = User().obs;

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
  RxString orderId = ''.obs;

  getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      // The wallet screen opens this for a transaction row, and a top-up row
      // carries no `orderId` at all — assigning that null into this RxString
      // threw and left the screen on an empty booking. The push handler can
      // pass a missing payload field the same way. See [argString].
      orderId.value = argString(argumentData, 'orderId');
    }
    await _loadReviews();
  }

  /// Shows another booking on the open screen (a tapped booking push while a
  /// details screen is already up).
  Future<void> openOrder(String id) async {
    if (id.trim().isEmpty || id.trim() == orderId.value) return;
    orderId.value = id.trim();
    ratingService.clear();
    update();
    await _loadReviews();
  }

  Future<void> _loadReviews() async {
    final String requested = orderId.value;
    final value = await FireStoreUtils.getReviewByProviderServiceId(requested);
    // A booking opened meanwhile keeps its own reviews.
    if (requested == orderId.value) ratingService.value = value;
    update();
  }
}
