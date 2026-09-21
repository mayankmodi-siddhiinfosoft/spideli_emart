import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:get/get.dart';

class TermsConditionController extends GetxController {
  RxString termsAndCondition = ''.obs;
  RxString privacyPolicy = ''.obs;

  @override
  void onInit() {
    FireStoreUtils.firestore.collection(Setting).doc("termsAndConditions").get().then((value) {
      termsAndCondition.value = value['terms_and_condition'].toString();
    });
    FireStoreUtils.firestore.collection(Setting).doc("privacyPolicy").get().then((value) {
      privacyPolicy.value = value['privacy_policy'].toString();
    });
    update();
    super.onInit();
  }
}
