import 'package:spideliprovider/themes/app_colors.dart';
import 'package:flutter/material.dart';


class Styles {
  static ThemeData themeData(bool isDarkTheme, BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: isDarkTheme ? AppColors.assetColorGrey1000 : AppColors.assetColorLightGrey400,
      primaryColor: isDarkTheme ? AppColors.colorPrimary : AppColors.colorPrimary,
      brightness: isDarkTheme ? Brightness.dark : Brightness.light,
    );
  }
}
