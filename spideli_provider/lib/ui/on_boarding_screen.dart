import 'package:cached_network_image/cached_network_image.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/on_boarding_controller.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/ui/auth/auth_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class OnBoardingScreen extends StatelessWidget {
  const OnBoardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<OnBoardingController>(
      init: OnBoardingController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: themeChange.getTheme() ? AppColors.assetColorGrey1000 : AppColors.assetColorLightGrey400,
            leading: controller.selectedPageIndex.value == 0
                ? null
                : InkWell(
                    onTap: () {
                      controller.pageController.jumpToPage(controller.selectedPageIndex.value - 1);
                    },
                    child: Icon(Icons.arrow_back)),
          ),
          body: controller.isLoading.value
              ? Center(
                  child: CircularProgressIndicator(),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: PageView.builder(
                            controller: controller.pageController,
                            onPageChanged: controller.selectedPageIndex.call,
                            itemCount: controller.onBoardingList.length,
                            itemBuilder: (context, index) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: CachedNetworkImage(
                                      imageUrl: controller.onBoardingList[index].image.toString(),
                                      placeholder: (context, url) => loader(),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        controller.onBoardingList.length,
                                        (index) => Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 4),
                                            width: controller.selectedPageIndex.value == index ? 38 : 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: controller.selectedPageIndex.value == index
                                                  ? themeChange.getTheme()
                                                      ? AppColors.colorGrey
                                                      : AppColors.colorPrimary
                                                  : AppColors.colorGrey,
                                              borderRadius: const BorderRadius.all(Radius.circular(20.0)),
                                            )),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      controller.onBoardingList[index].title.toString().tr,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: themeChange.getTheme() ? AppColors.colorWhite : AppColors.colorDark,
                                        fontSize: 24,
                                        fontFamily: AppColors.semiBold,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      controller.onBoardingList[index].description.toString().tr,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.colorGrey500,
                                        fontSize: 14,
                                        fontFamily: AppColors.regular,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                      ),
                      const SizedBox(
                        height: 32,
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.colorPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.0),
                            side: BorderSide(
                              color: AppColors.colorPrimary,
                            ),
                          ),
                        ),
                        child: Text(
                          'Next'.tr,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeChange.getTheme() ? Colors.black : Colors.white,
                          ),
                        ),
                        onPressed: () {
                          if (controller.selectedPageIndex.value == 2) {
                            Preferences.setBoolean(Preferences.isFinishOnBoardingKey, true);
                            Get.offAll(AuthScreen());
                          } else {
                            controller.pageController.jumpToPage(controller.selectedPageIndex.value + 1);
                          }
                        },
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      controller.selectedPageIndex.value == 2
                          ? const Text(
                              '',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.colorGrey500,
                                fontSize: 16,
                                fontFamily: AppColors.medium,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : InkWell(
                              onTap: () {
                                Preferences.setBoolean(Preferences.isFinishOnBoardingKey, true);
                                Get.offAll(AuthScreen());
                              },
                              child: Text(
                                'Skip'.tr,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.DARK_BG_COLOR,
                                  fontSize: 16,
                                  fontFamily: AppColors.medium,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
