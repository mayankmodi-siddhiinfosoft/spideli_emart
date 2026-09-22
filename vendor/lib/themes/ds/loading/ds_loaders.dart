import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/ds_observe.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';

/// Animated brand loader: a rotating gradient arc around a softly pulsing
/// brand core (optionally the logo). Use for full-screen / blocking waits
/// when no meaningful skeleton exists (splash, payment processing...).
///
/// `Constant.loader()` already returns a centered DsBrandLoader.
///
/// ```dart
/// const DsBrandLoader()
/// DsBrandLoader(size: 72, label: 'Processing payment'.tr, logo: Image.asset('assets/images/ic_logo.png'))
/// ```
class DsBrandLoader extends StatefulWidget {
  final double size;
  final String? label;

  /// Optional widget drawn in the center (e.g. the app logo).
  final Widget? logo;

  /// Override the arc color (defaults to the brand color).
  final Color? color;

  const DsBrandLoader({super.key, this.size = 52, this.label, this.logo, this.color});

  @override
  State<DsBrandLoader> createState() => _DsBrandLoaderState();
}

class _DsBrandLoaderState extends State<DsBrandLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final color = widget.color ?? c.brand;
    final reduced = DsMotion.reduced(context);
    final loader = SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = reduced ? 0.0 : _c.value;
          final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
          return CustomPaint(
            painter: _ArcPainter(progress: t, color: color, track: c.brandSoft),
            child: Center(
              child: widget.logo != null
                  ? SizedBox.square(dimension: widget.size * 0.5, child: widget.logo)
                  : Container(
                      width: widget.size * (0.22 + 0.06 * pulse),
                      height: widget.size * (0.22 + 0.06 * pulse),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.55 + 0.45 * pulse),
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35 * pulse), blurRadius: 12)],
                      ),
                    ),
            ),
          );
        },
      ),
    );
    return Semantics(
      label: widget.label ?? 'Loading',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loader,
          if (widget.label != null) ...[
            const DsGap(DsSpace.md),
            Text(widget.label!, textAlign: TextAlign.center, style: DsTypography.bodyStrong.copyWith(color: c.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  _ArcPainter({required this.progress, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawCircle(rect.center, arcRect.width / 2, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track);

    // Sweep length breathes between ~25% and ~70% of the circle.
    final sweep = math.pi * 2 * (0.25 + 0.45 * (0.5 - 0.5 * math.cos(progress * 2 * math.pi)));
    final start = progress * math.pi * 4 - math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: [color.withValues(alpha: 0.05), color],
        transform: GradientRotation(start),
      ).createShader(arcRect);
    canvas.drawArc(arcRect, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress || old.color != color || old.track != track;
}

/// Small inline spinner (buttons, list footers, "loading more").
class DsSpinner extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  const DsSpinner({super.key, this.size = 20, this.color, this.strokeWidth = 2.4});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, strokeCap: StrokeCap.round, color: color ?? DsColors.of(context).brand),
    );
  }
}

/// Cross-fades between loading / error / empty / content states.
///
/// Content is built lazily through [builder] so it is never built with
/// missing data. Put it inside your existing `Obx`/`GetBuilder` – it does not
/// read controllers itself.
///
/// ```dart
/// Obx(() => DsAsync(
///   isLoading: controller.isLoading.value,
///   skeleton: const DsSkeletonList(),
///   isEmpty: controller.orders.isEmpty,
///   empty: DsEmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet'.tr),
///   builder: (_) => OrdersList(controller: controller),
/// ))
/// ```
class DsAsync extends StatelessWidget {
  final bool isLoading;
  final Widget skeleton;
  final WidgetBuilder builder;
  final bool hasError;
  final Widget? error;
  final bool isEmpty;
  final Widget? empty;
  final Duration duration;

  const DsAsync({
    super.key,
    required this.isLoading,
    required this.builder,
    this.skeleton = const Center(child: DsBrandLoader()),
    this.hasError = false,
    this.error,
    this.isEmpty = false,
    this.empty,
    this.duration = DsMotion.slow,
  });

  @override
  Widget build(BuildContext context) {
    final String state;
    final Widget child;
    if (isLoading) {
      state = 'loading';
      child = skeleton;
    } else if (hasError && error != null) {
      state = 'error';
      child = error!;
    } else if (isEmpty && empty != null) {
      state = 'empty';
      child = empty!;
    } else {
      state = 'content';
      // Observe reads made while building content: the builder runs here,
      // after any enclosing Obx/GetX has finished tracking.
      child = DsObserve(builder: builder);
    }
    return AnimatedSwitcher(
      duration: DsMotion.of(context, duration),
      switchInCurve: DsMotion.standard,
      switchOutCurve: DsMotion.accelerate,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(state), child: child),
    );
  }
}
