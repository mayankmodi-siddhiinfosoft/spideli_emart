import 'package:get/get.dart';
import 'package:vendor/models/subscription_history.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class SubscriptionHistoryController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<SubscriptionHistoryModel> subscriptionHistoryList = <SubscriptionHistoryModel>[].obs;

  @override
  void onInit() {
    getAllSubscriptionList();
    super.onInit();
  }

  Future<void> getAllSubscriptionList() async {
    subscriptionHistoryList.value = await FireStoreUtils.getSubscriptionHistory();
    isLoading.value = false;
  }
}
