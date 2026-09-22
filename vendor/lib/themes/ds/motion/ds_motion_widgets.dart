import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../loading/ds_skeleton.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';

/// Entrance animation: fades in while sliding up a few pixels.
///
/// Pass [index] inside lists to get a staggered cascade. Items only animate
/// on first appearance while the enclosing scrollable is still at its start
/// offset, so items that are recycled while the user scrolls simply appear
/// (no replay jank). Honors "reduce motion".
///
/// ```dart
/// ListView.builder(itemBuilder: (_, i) => DsFadeSlideIn(index: i, child: OrderCard(...)))
/// Column(children: DsFadeSlideIn.stagger([header, stats, list]))
/// ```
class DsFadeSlideIn extends StatefulWidget {
  final Widget child;

  /// Position in a list, used to compute the stagger delay.
  final int index;

  /// Extra delay before the animation starts.
  final Duration delay;
  final Duration duration;

  /// Starting offset in logical pixels (default: 16 px below).
  final Offset offset;
  final Curve curve;

  const DsFadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = DsMotion.slow,
    this.offset = const Offset(0, 16),
    this.curve = DsMotion.emphasized,
  });

  /// Wraps each widget of [children] with a staggered [DsFadeSlideIn].
  static List<Widget> stagger(List<Widget> children, {Duration delay = Duration.zero, Offset offset = const Offset(0, 16)}) => [
    for (var i = 0; i < children.length; i++) DsFadeSlideIn(index: i, delay: delay, offset: offset, child: children[i]),
  ];

  @override
  State<DsFadeSlideIn> createState() => _DsFadeSlideInState();
}

class _DsFadeSlideInState extends State<DsFadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: widget.curve);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final position = Scrollable.maybeOf(context)?.position;
    final scrolled = position != null && position.hasPixels && position.hasContentDimensions && (position.pixels - position.minScrollExtent).abs() > 1;
    if (DsMotion.reduced(context) || scrolled || widget.index > DsMotion.maxStaggerIndex * 2) {
      _c.value = 1;
      return;
    }
    final i = widget.index.clamp(0, DsMotion.maxStaggerIndex);
    final delay = widget.delay + DsMotion.stagger * i;
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        if (v >= 1) return child!;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(offset: widget.offset * (1 - v), child: child),
        );
      },
    );
  }
}

/// Animates a number from its previous value to [value] (count-up on first
/// build). Uses tabular figures so the width does not jitter.
///
/// ```dart
/// DsAnimatedCounter(value: controller.totalOrders.value, style: t.metric)
/// DsAnimatedCounter(value: earnings, format: (v) => Constant.amountShow(amount: v.toString()))
/// ```
class DsAnimatedCounter extends StatelessWidget {
  final num value;

  /// Formats the in-flight value. Defaults to an integer (or 2 decimals when
  /// [value] is a double with a fractional part).
  final String Function(num value)? format;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  /// Count up from zero on first build (otherwise start at [value]).
  final bool countUpOnStart;

  const DsAnimatedCounter({
    super.key,
    required this.value,
    this.format,
    this.style,
    this.duration = DsMotion.slower,
    this.curve = DsMotion.decelerate,
    this.textAlign,
    this.countUpOnStart = true,
  });

  @override
  Widget build(BuildContext context) {
    final isInt = value is int || value == value.roundToDouble();
    String fmt(num v) => format != null ? format!(v) : (isInt ? v.round().toString() : v.toStringAsFixed(2));
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: countUpOnStart ? 0 : value.toDouble(), end: value.toDouble()),
      duration: DsMotion.of(context, duration),
      curve: curve,
      builder: (context, v, _) => Text(
        fmt(isInt ? v.round() : v),
        textAlign: textAlign,
        style: (style ?? DefaultTextStyle.of(context).style).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        semanticsLabel: fmt(value),
      ),
    );
  }
}

/// Tactile press feedback: scales the child down slightly while pressed.
///
/// * With [onTap]: behaves as a button (adds semantics, optional haptics).
/// * Without [onTap]: feedback only – wrap an existing InkWell / button so its
///   own gesture handling keeps working.
///
/// ```dart
/// DsPressable(onTap: () => Get.to(...), child: DsCard(...))
/// ```
class DsPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale while pressed (0.97 = 3% smaller).
  final double pressedScale;
  final bool haptic;
  final String? semanticLabel;
  final bool enabled;

  const DsPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.haptic = false,
    this.semanticLabel,
    this.enabled = true,
  });

  @override
  State<DsPressable> createState() => _DsPressableState();
}

class _DsPressableState extends State<DsPressable> {
  bool _down = false;

  void _set(bool v) {
    if (!widget.enabled || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedScale(
      scale: _down ? widget.pressedScale : 1,
      duration: DsMotion.of(context, DsMotion.fast),
      curve: DsMotion.standard,
      child: widget.child,
    );
    child = Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: child,
    );
    if (widget.onTap == null && widget.onLongPress == null) return child;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled && widget.onTap != null
            ? () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        onTapCancel: () => _set(false),
        child: child,
      ),
    );
  }
}

/// Network (or asset) image with shimmer placeholder, graceful error state,
/// fade-in, rounded corners and optional [heroTag] for shared-element
/// transitions between list and detail screens.
///
/// ```dart
/// DsImage(url: product.photo, heroTag: 'product-${product.id}', width: 72, height: 72, radius: DsRadius.md)
/// ```
class DsImage extends StatelessWidget {
  final String? url;

  /// Use an asset instead of a network image.
  final String? asset;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final Object? heroTag;

  /// Icon shown when the image is missing / fails.
  final IconData errorIcon;
  final String? semanticLabel;

  const DsImage({
    super.key,
    this.url,
    this.asset,
    this.width,
    this.height,
    this.radius = DsRadius.md,
    this.fit = BoxFit.cover,
    this.heroTag,
    this.errorIcon = Icons.image_outlined,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    Widget fallback() => Container(
      width: width,
      height: height,
      color: c.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(errorIcon, color: c.textMuted, size: 22),
    );

    Widget image;
    if (asset != null) {
      image = Image.asset(asset!, width: width, height: height, fit: fit, errorBuilder: (_, _, _) => fallback());
    } else if (url == null || url!.isEmpty || !(url!.startsWith('http'))) {
      image = fallback();
    } else {
      image = CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: DsMotion.of(context, DsMotion.base),
        placeholder: (_, _) => DsSkeleton.box(width: width, height: height, radius: 0),
        errorWidget: (_, _, _) => fallback(),
      );
    }
    image = ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
    if (semanticLabel != null) image = Semantics(image: true, label: semanticLabel, child: image);
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }
    return image;
  }
}
