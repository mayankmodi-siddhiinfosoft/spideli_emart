import 'package:spideliworker/controller/terms_condition_controller.dart';
import 'package:spideliworker/themes/app_colors.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class TermsAndCondition extends StatelessWidget {
  const TermsAndCondition({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<TermsConditionController>(
        init: TermsConditionController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
              title: Text(
                'Terms & condition',
                style: TextStyle(color: themeChange.getTheme() ? AppColors.colorWhite : Colors.black, fontSize: 18, fontFamily: AppColors.medium),
              ),
              leading: InkWell(
                  onTap: () {
                    Get.back();
                  },
                  child: const Icon(
                    Icons.arrow_back,
                  )),
            ),
            backgroundColor: Colors.white,
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 10),
                child: controller.termsAndCondition.isNotEmpty
                    ? HtmlWidget(
                        '''
                  ${controller.termsAndCondition.value}
                   ''',
                        onErrorBuilder: (context, element, error) => Text('$element ${"error: "}$error'),
                        onLoadingBuilder: (context, element, loadingProgress) => const CircularProgressIndicator(),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        });
  }
}
