import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';

class ShowToastDialog {
  static void showToast(String? message, {EasyLoadingToastPosition position = EasyLoadingToastPosition.top}) {
    EasyLoading.showToast(message!.tr, toastPosition: position);
  }

  static void showLoader(String message) {
    EasyLoading.show(status: message, maskType: EasyLoadingMaskType.black, dismissOnTap: false);
  }

  static void closeLoader() {
    EasyLoading.dismiss();
  }
}
