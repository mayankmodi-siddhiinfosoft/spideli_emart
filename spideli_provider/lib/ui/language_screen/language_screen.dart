import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/language_controller.dart';
import 'package:spideliprovider/services/localization_service.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/common_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX(
        init: LanguageController(),
        builder: (controller) {
          return Scaffold(
            appBar: CommonUI.customAppBar(context,
                title: Text(
                  "Select Language",
                  style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
                ),
                isBack: true),
            body: controller.isLoading.value
                ? loader()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: controller.languageList.length,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              return InkWell(
                                onTap: () {
                                  controller.selectedLanguage.value = controller.languageList[index].slug.toString();
                                },
                                child: Obx(
                                  () => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Container(
                                      decoration: controller.languageList[index].slug == controller.selectedLanguage.value
                                          ? BoxDecoration(
                                              border: Border.all(color: AppColors.colorPrimary),
                                              borderRadius: const BorderRadius.all(Radius.circular(5.0) //                 <--- border radius here
                                                  ),
                                            )
                                          : null,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Row(
                                          children: [
                                            controller.languageList[index].flag != null
                                                ? Image.network(
                                                    controller.languageList[index].flag.toString(),
                                                    height: 60,
                                                    width: 60,
                                                  )
                                                : Image.network(
                                                    placeholderImage,
                                                    height: 60,
                                                    width: 60,
                                                  ),
                                            Padding(
                                              padding: const EdgeInsets.only(left: 10, right: 10),
                                              child: Text(controller.languageList[index].title.toString(), style: const TextStyle(fontSize: 16)),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 40.0, left: 40.0, top: 40.0),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: double.infinity),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.colorPrimary,
                                padding: const EdgeInsets.only(top: 12, bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                  side: BorderSide(
                                    color: AppColors.colorPrimary,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                LocalizationService().changeLocale(controller.selectedLanguage.value);
                                Preferences.setString(Preferences.languageKey, controller.selectedLanguage.value);
                                ShowToastDialog.showToast("Language Changed Successfully".tr);
                              },
                              child: Text(
                                'Save'.tr,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: themeChange.getTheme() ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
          );
        });
  }
}
