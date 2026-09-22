import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../tokens/ds_tokens.dart';

/// App-wide page transition.
///
/// * iOS / macOS: native Cupertino slide with the interactive swipe-back.
/// * Android & others: a horizontal "shared axis" – the new page fades in
///   while sliding 8% from the trailing edge, the old page drifts 4% the
///   other way.
///
/// Registered once in `main.dart` via `GetMaterialApp(customTransition:
/// DsPageTransition(), transitionDuration: DsMotion.page)` and in the
/// ThemeData `pageTransitionsTheme` (for plain `Navigator.push`). Screens do
/// not need to do anything. Routes pushed with an explicit `transition:` keep
/// their own animation.
class DsPageTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      // Use the route's raw (linear) animations so gestures track the finger.
      return DsPageTransition.build(route, context, route.animation ?? animation, route.secondaryAnimation ?? secondaryAnimation, child);
    }
    return _DsSharedAxis(animation: animation, secondaryAnimation: secondaryAnimation, child: child);
  }

  static bool get _isCupertinoPlatform =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);

  /// Shared builder used by both GetX routes and Material routes.
  static Widget build<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    if (_isCupertinoPlatform) {
      return CupertinoRouteTransitionMixin.buildPageTransitions<T>(route, context, animation, secondaryAnimation, child);
    }
    return _DsSharedAxis(animation: animation, secondaryAnimation: secondaryAnimation, child: child);
  }
}

/// [PageTransitionsBuilder] wrapper so `Navigator.push(MaterialPageRoute)`
/// gets the same motion as GetX routes.
class DsPageTransitionsBuilder extends PageTransitionsBuilder {
  const DsPageTransitionsBuilder();

  @override
  Duration get transitionDuration => DsMotion.page;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return DsPageTransition.build<T>(route, context, animation, secondaryAnimation, child);
  }
}

class _DsSharedAxis extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _DsSharedAxis({required this.animation, required this.secondaryAnimation, required this.child});

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return SlideTransition(
      position: secondaryAnimation.drive(Tween<Offset>(begin: Offset.zero, end: Offset(-0.04 * dir, 0)).chain(CurveTween(curve: DsMotion.emphasized))),
      child: SlideTransition(
        position: animation.drive(Tween<Offset>(begin: Offset(0.08 * dir, 0), end: Offset.zero).chain(CurveTween(curve: DsMotion.emphasized))),
        child: FadeTransition(opacity: animation.drive(CurveTween(curve: const Interval(0.0, 0.7, curve: Curves.easeOut))), child: child),
      ),
    );
  }
}
