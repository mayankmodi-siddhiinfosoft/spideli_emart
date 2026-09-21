import 'package:spideliprovider/controller/terms_condition_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';

class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<TermsConditionController>(
        init: TermsConditionController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 10),
                child: controller.privacyPolicy.isNotEmpty
                    ? HtmlWidget(
                        '''
                  ${controller.privacyPolicy.value}
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
