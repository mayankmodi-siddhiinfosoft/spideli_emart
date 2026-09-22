import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:flutter/material.dart';

/// Legacy entry point for the app theme. Now returns the design-system theme
/// ([DsTheme]) so any remaining caller gets the same look as `main.dart`.
class Styles {
  static ThemeData themeData(bool isDarkTheme, BuildContext context) {
    return DsTheme.build(isDarkTheme);
  }
}
