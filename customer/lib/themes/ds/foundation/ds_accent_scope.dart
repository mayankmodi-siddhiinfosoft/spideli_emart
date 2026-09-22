import 'package:flutter/material.dart';

import '../tokens/ds_section.dart';
import 'ds_theme.dart';

/// Pins the brand accent for a subtree to one service section (or any
/// color), so `context.dsColors.brand`, `DsTone.brand`, `DsGradients.brand`,
/// DS components and (with [retheme]) Material widgets all use it.
///
/// You normally do **not** need it: inside a service `c.brand` is already the
/// active section color. Use it where a screen shows another section than
/// the active one, e.g. a cross-service history row, a section tile on the
/// service list, or a cab card inside the food home.
///
/// ```dart
/// DsAccentScope.section(section: DsSection.cab, child: RideCard(...))
/// DsAccentScope(color: DsColors.fromHex(section.color) ?? context.dsColors.brand, child: ...)
/// ```
class DsAccentScope extends StatelessWidget {
  final Color? color;
  final DsSection? section;
  final Widget child;

  /// Also rebuild the Material [Theme] around [child] so switches, pickers,
  /// progress indicators and text selection use the accent. Turn off for
  /// small, frequently rebuilt subtrees that only use DS widgets.
  final bool retheme;

  const DsAccentScope({super.key, required Color this.color, required this.child, this.retheme = true}) : section = null;

  const DsAccentScope.section({super.key, required DsSection this.section, required this.child, this.retheme = true}) : color = null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inherited = DsAccentInherited(color: color, section: section, child: child);
    if (!retheme) return inherited;
    final accent = inherited.resolve(isDark);
    return DsAccentInherited(
      color: color,
      section: section,
      child: Theme(data: DsTheme.build(isDark, brand: accent), child: child),
    );
  }
}

/// Inherited data behind [DsAccentScope]; read by `DsColors.of`.
class DsAccentInherited extends InheritedWidget {
  final Color? color;
  final DsSection? section;

  const DsAccentInherited({super.key, this.color, this.section, required super.child});

  /// The accent color for [isDark] (null = no override).
  Color? resolve(bool isDark) {
    if (color != null) return color;
    final s = section;
    if (s == null || s == DsSection.none) return null;
    return s.base(isDark);
  }

  @override
  bool updateShouldNotify(DsAccentInherited oldWidget) => oldWidget.color != color || oldWidget.section != section;
}
