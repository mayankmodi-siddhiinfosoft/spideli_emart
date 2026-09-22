import 'package:customer/themes/app_them_data.dart';
import 'package:flutter/material.dart';

/// Small shared building blocks for the subscription / account screens.
class SubUi {
  SubUi._();

  static Color text(bool isDark) => isDark ? AppThemeData.grey50 : AppThemeData.grey900;

  static Color muted(bool isDark) => isDark ? AppThemeData.grey300 : AppThemeData.grey600;

  static Color surface(bool isDark) => isDark ? AppThemeData.surfaceDark : AppThemeData.surface;

  static AppBar appBar(String title, bool isDark, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
    backgroundColor: surface(isDark),
    centerTitle: false,
    titleSpacing: 0,
    title: Text(title, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 16, color: text(isDark))),
    actions: actions,
    bottom: bottom,
  );

  static Widget card(bool isDark, Widget child, {EdgeInsets margin = const EdgeInsets.only(bottom: 12)}) => Container(
    width: double.infinity,
    margin: margin,
    padding: const EdgeInsets.all(14),
    decoration: ShapeDecoration(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    child: child,
  );

  static Widget heading(String value, bool isDark) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(value, style: TextStyle(fontSize: 16, fontFamily: AppThemeData.semiBold, color: text(isDark))),
  );

  static Widget title(String value, bool isDark) => Text(value, style: TextStyle(fontSize: 16, fontFamily: AppThemeData.semiBold, color: text(isDark)));

  static Widget body(String value, bool isDark) => Text(value, style: TextStyle(fontSize: 14, fontFamily: AppThemeData.regular, color: muted(isDark)));

  static Widget row(String label, String value, bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 13, fontFamily: AppThemeData.regular, color: muted(isDark)))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontFamily: AppThemeData.medium, color: text(isDark)))),
      ],
    ),
  );

  static Widget chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 12, fontFamily: AppThemeData.semiBold)),
  );

  static Widget empty(String value, bool isDark) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: body(value, isDark)));
}
