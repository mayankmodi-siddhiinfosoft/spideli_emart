import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/theme_controller.dart';

class CustomDialogBox extends StatelessWidget {
  final String title, descriptions, positiveString, negativeString;
  final Widget? widget;
  final Widget? img;
  final Function() positiveClick;
  final Function() negativeClick;

  const CustomDialogBox({
    super.key,
    required this.title,
    required this.descriptions,
    this.widget,
    this.img,
    required this.positiveClick,
    required this.negativeClick,
    required this.positiveString,
    required this.negativeString,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: contentBox(context),
    );
  }

  Container contentBox(context)  {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Container(
      padding: const EdgeInsets.only(left: 20, top: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(shape: BoxShape.rectangle, color: isDark ? AppThemeData.grey800 : AppThemeData.grey100, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (img != null) img!,
          const SizedBox(height: 20),
          Visibility(
            visible: title.isNotEmpty,
            child: Text(
              title,
              style: TextStyle(fontSize: 18, fontFamily: AppThemeData.semiBold, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
            ),
          ),
          const SizedBox(height: 10),
          Visibility(
            visible: descriptions.isNotEmpty,
            child: Text(
              descriptions,
              style: TextStyle(fontSize: 14, fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey200 : AppThemeData.grey700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          if (widget != null) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [widget!, const SizedBox(height: 10)]),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    negativeClick();
                  },
                  child: Container(
                    width: Responsive.width(100, context),
                    height: Responsive.height(5, context),
                    decoration: ShapeDecoration(
                      color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          negativeString.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey100 : AppThemeData.grey900, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    positiveClick();
                  },
                  child: Container(
                    width: Responsive.width(100, context),
                    height: Responsive.height(5, context),
                    decoration: ShapeDecoration(
                      color: AppThemeData.warning400,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          positiveString.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: AppThemeData.medium, color: AppThemeData.grey50, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
