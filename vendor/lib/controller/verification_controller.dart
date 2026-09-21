import 'package:get/get.dart';
import 'package:vendor/models/document_model.dart';
import 'package:vendor/models/driver_document_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class VerificationController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getDocument();
    super.onInit();
  }

  RxList documentList = <DocumentModel>[].obs;
  RxList driverDocumentList = <Documents>[].obs;

  Future<void> getDocument() async {
    await FireStoreUtils.getDocumentList().then((value) {
      documentList.value = value;
    });
    await FireStoreUtils.getDocumentOfDriver().then((value) {
      if (value != null) {
        driverDocumentList.value = value.documents!;
      }
    });
    isLoading.value = false;
    update();
  }
}
