import 'package:flutter/material.dart';
import 'package:spideliworker/themes/ds/ds.dart';

class Styles {
  /// Kept for compatibility; returns the design-system theme
  /// (see lib/themes/ds/DESIGN_SYSTEM.md).
  static ThemeData themeData(bool isDarkTheme, BuildContext context) {
    return DsTheme.build(isDarkTheme);
  }
}
