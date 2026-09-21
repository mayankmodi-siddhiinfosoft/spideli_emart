import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:get/get.dart';

class AllServicesController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<ProviderServiceModel> providerList = <ProviderServiceModel>[].obs;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  getData() async {
    await FireStoreUtils.getProviderServices().then((value) {
      providerList.value = value;
    });

    isLoading.value = false;
  }
}
