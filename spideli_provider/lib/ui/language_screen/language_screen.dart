import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/language_controller.dart';
import 'package:spideliprovider/services/localization_service.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    return GetX(
      init: LanguageController(),
      builder: (controller) {
        return DsScaffold(
          backgroundColor: c.background,
          appBar: const DsAppBar(title: "Select Language"),
          body: controller.isLoading.value
              ? const DsSkeletonList(itemCount: 6, trailing: false)
              : DsResponsive(
                  maxWidth: DsLayout.contentMax,
                  padded: true,
                  child: ListView.builder(
                    itemCount: controller.languageList.length,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: DsSpace.lg),
                    itemBuilder: (context, index) {
                      return Obx(() {
                        final bool selected = controller.languageList[index].slug == controller.selectedLanguage.value;
                        final String? flag = controller.languageList[index].flag?.toString();
                        return DsFadeSlideIn(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: DsSpace.md),
                            child: DsCard.outlined(
                              onTap: () {
                                controller.selectedLanguage.value = controller.languageList[index].slug.toString();
                              },
                              borderColor: selected ? c.brand : null,
                              padding: const EdgeInsets.all(DsSpace.md),
                              semanticLabel: controller.languageList[index].title.toString(),
                              child: Row(
                                children: [
                                  // Flag plate – the visual anchor of each row.
                                  DsImage(url: flag ?? placeholderImage, height: 48, width: 60, radius: DsRadius.sm, errorIcon: Icons.flag_outlined),
                                  const DsGap(DsSpace.lg),
                                  Expanded(child: Text(controller.languageList[index].title.toString(), style: context.dsText.titleSm)),
                                  AnimatedOpacity(
                                    duration: DsMotion.of(context, DsMotion.fast),
                                    opacity: selected ? 1 : 0,
                                    child: DsIconWell(icon: Icons.check_rounded, tone: DsTone.brand, size: 32, circle: true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      });
                    },
                  ),
                ),
          bottomBar: controller.isLoading.value
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: 'Save'.tr,
                    icon: Icons.check_rounded,
                    expand: true,
                    size: DsButtonSize.lg,
                    onPressed: () {
                      LocalizationService().changeLocale(controller.selectedLanguage.value);
                      Preferences.setString(Preferences.languageKey, controller.selectedLanguage.value);
                      ShowToastDialog.showToast("Language Changed Successfully".tr);
                    },
                  ),
                ),
        );
      },
    );
  }
}
