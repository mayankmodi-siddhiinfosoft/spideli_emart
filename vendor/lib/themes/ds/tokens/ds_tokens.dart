import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// 4-pt spacing scale. Use these instead of magic numbers.
///
/// ```dart
/// Padding(padding: const EdgeInsets.all(DsSpace.lg), child: ...)
/// const DsGap(DsSpace.md)
/// ```
abstract final class DsSpace {
  static const double none = 0;
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 56;

  /// Default horizontal page gutter on phones (tablets use DsLayout.gutter).
  static const double gutter = 16;
}

/// Corner radius scale.
abstract final class DsRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  /// Top-only radius for bottom sheets.
  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(xxl));
}

/// Empty space that works in both [Row] and [Column] (and in slivers via
/// [DsGap.sliver]).
class DsGap extends StatelessWidget {
  final double size;
  const DsGap(this.size, {super.key});

  static const DsGap xs = DsGap(DsSpace.xs);
  static const DsGap sm = DsGap(DsSpace.sm);
  static const DsGap md = DsGap(DsSpace.md);
  static const DsGap lg = DsGap(DsSpace.lg);
  static const DsGap xl = DsGap(DsSpace.xl);
  static const DsGap xxl = DsGap(DsSpace.xxl);
  static const DsGap xxxl = DsGap(DsSpace.xxxl);

  /// Vertical gap as a sliver.
  static Widget sliver(double size) => SliverToBoxAdapter(child: SizedBox(height: size));

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

/// Soft, layered shadows. In dark mode shadows are much weaker, so pair
/// elevated surfaces with a hairline border (DsCard does this for you).
abstract final class DsShadows {
  static const List<BoxShadow> none = [];

  static List<BoxShadow> xs(BuildContext context) => _build(context, [(0.0, 1.0, 2.0, 0.05)]);

  static List<BoxShadow> sm(BuildContext context) => _build(context, [(0.0, 1.0, 2.0, 0.04), (0.0, 2.0, 8.0, 0.05)]);

  static List<BoxShadow> md(BuildContext context) => _build(context, [(0.0, 2.0, 4.0, 0.04), (0.0, 8.0, 24.0, 0.07)]);

  static List<BoxShadow> lg(BuildContext context) => _build(context, [(0.0, 4.0, 8.0, 0.05), (0.0, 16.0, 40.0, 0.10)]);

  /// Colored glow for brand-filled heroes / primary FABs.
  static List<BoxShadow> glow(BuildContext context, {Color? color}) {
    final c = color ?? DsColors.of(context).brand;
    return [
      BoxShadow(color: c.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -6),
      BoxShadow(color: c.withValues(alpha: 0.14), blurRadius: 6, offset: const Offset(0, 2)),
    ];
  }

  static List<BoxShadow> _build(BuildContext context, List<(double, double, double, double)> layers) {
    final c = DsColors.of(context);
    final boost = c.isDark ? 3.2 : 1.0;
    return [
      for (final l in layers)
        BoxShadow(color: c.shadow.withValues(alpha: (l.$4 * boost).clamp(0.0, 0.6)), offset: Offset(l.$1, l.$2), blurRadius: l.$3),
    ];
  }
}

/// Durations and curves. Respect "reduce motion" with [DsMotion.of].
abstract final class DsMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration slower = Duration(milliseconds: 600);
  static const Duration page = Duration(milliseconds: 340);

  /// Delay between list items for staggered entrances.
  static const Duration stagger = Duration(milliseconds: 45);

  /// Items with an index above this appear together (no long waits).
  static const int maxStaggerIndex = 10;

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve decelerate = Curves.easeOutQuart;
  static const Curve accelerate = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;

  /// True when the OS "reduce motion"/"remove animations" setting is on.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [d], or [Duration.zero] when the user asked to reduce motion.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

/// Brand gradients. They read the runtime brand color, so always build them
/// inside `build`.
abstract final class DsGradients {
  /// Primary brand gradient for hero headers, balance cards, CTAs.
  static LinearGradient brand(BuildContext context) {
    final c = DsColors.of(context);
    final b = c.brand;
    final hsl = HSLColor.fromColor(b);
    final shifted = hsl.withHue((hsl.hue + 18) % 360).withLightness((hsl.lightness * 0.72).clamp(0.0, 1.0)).toColor();
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(b, Colors.white, 0.06)!, shifted]);
  }

  /// Deep, calm gradient (near-black tinted with brand) for premium /
  /// finance surfaces. Looks good in light and dark.
  static LinearGradient deep(BuildContext context) {
    final b = DsColors.of(context).brand;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(const Color(0xFF0B1220), b, 0.30)!, const Color(0xFF0B1220)],
    );
  }

  /// Very subtle surface-to-brand-tint wash for tinted panels.
  static LinearGradient subtle(BuildContext context) {
    final c = DsColors.of(context);
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.brandSoft, c.surface]);
  }

  /// Gradient for a semantic tone (e.g. success banner).
  static LinearGradient tone(BuildContext context, DsTone tone) {
    final t = DsColors.of(context).tone(tone);
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.main, Color.lerp(t.main, Colors.black, 0.25)!]);
  }

  /// Bottom-up scrim to place text over images.
  static const LinearGradient imageScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xCC000000), Color(0x00000000)],
  );
}
