import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/model/language_model.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/preferences.dart';
import 'package:get/get.dart';

class LanguageController extends GetxController {
  RxString selectedLanguage = "en".obs;

  void handleLanguageChange(String? value) {
    selectedLanguage.value = value!;
  }

  RxBool isLoading = true.obs;

  @override
  void onInit() {
    getLightDarkMode();
    super.onInit();
  }

  RxList<LanguageModel> languageList = <LanguageModel>[].obs;


  Future<void> getLightDarkMode() async {
    await FireStoreUtils.firestore.collection(Setting).doc("languages").get().then((value) {
      List list = value.data()!["list"];
      for (int i = 0; i < list.length; i++) {
        if (list[i]['isActive'] == true) {
          LanguageModel languageModel = LanguageModel.fromJson(list[i]);
          languageList.add(languageModel);
        }
      }
    });

    if (Preferences.getString(Preferences.languageKey).toString().isNotEmpty) {
      selectedLanguage.value = Preferences.getString(Preferences.languageKey).toString();
    }
    isLoading.value = false;
    update();
  }
}
