import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';

class ShowToastDialog {
  static void showToast(String? message, {EasyLoadingToastPosition position = EasyLoadingToastPosition.top}) {
    EasyLoading.showToast(message!.tr, toastPosition: position);
  }

  static void showToastDuration(String? message, {EasyLoadingToastPosition position = EasyLoadingToastPosition.top, required Duration duration}) {
    EasyLoading.showToast(message!.tr, toastPosition: position, duration: duration);
  }

  static void showLoader(String message) {
    EasyLoading.show(status: message.tr);
  }

  static void closeLoader() {
    EasyLoading.dismiss();
  }
}
