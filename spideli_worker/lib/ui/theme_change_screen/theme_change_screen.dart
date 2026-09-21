import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/controller/theme_change_controller.dart';
import 'package:spideliworker/services/preferences.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:spideliworker/widgets/common_ui.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class ThemeChangeScreen extends StatelessWidget {
  const ThemeChangeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX(
        init: ThemChangeController(),
        builder: (controller) {
          return Scaffold(
            appBar: CommonUI.customAppBar(context,
                title: Text(
                  "Select Theme",
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
                          child: Column(children: [
                            InkWell(
                              onTap: () {
                                controller.lightDarkMode.value = "Light";
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Light",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: AppColors.medium,
                                        color: themeChange.getTheme() ? AppColors.assetColorGrey100 : AppColors.assetColorGrey1000,
                                      ),
                                    ),
                                  ),
                                  Radio<String>(
                                    value: "Light",
                                    groupValue: controller.lightDarkMode.value,
                                    activeColor: AppColors.colorPrimary,
                                    onChanged: controller.handleGenderChange,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 5),
                              child: Divider(
                                color: AppColors.assetColorGrey300,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                controller.lightDarkMode.value = "Dark";
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Dark",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: AppColors.medium,
                                        color: themeChange.getTheme() ? AppColors.assetColorGrey100 : AppColors.assetColorGrey1000,
                                      ),
                                    ),
                                  ),
                                  Radio<String>(
                                    value: "Dark",
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    groupValue: controller.lightDarkMode.value,
                                    activeColor: AppColors.colorPrimary,
                                    onChanged: controller.handleGenderChange,
                                  ),
                                ],
                              ),
                            ),
                          ]),
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
                                  side:  BorderSide(
                                    color: AppColors.colorPrimary,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                Preferences.setString(Preferences.themeKey, controller.lightDarkMode.value);
                                if (controller.lightDarkMode.value == "Dark") {
                                  themeChange.darkTheme = 0;
                                } else if (controller.lightDarkMode.value == "Light") {
                                  themeChange.darkTheme = 1;
                                } else {
                                  themeChange.darkTheme = 2;
                                }
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
