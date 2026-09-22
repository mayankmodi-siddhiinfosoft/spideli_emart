import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';

/// Animated linear progress. `value: null` → indeterminate.
///
/// ```dart
/// DsProgressBar(value: 0.6, label: 'Profile completion'.tr, showPercent: true)
/// ```
class DsProgressBar extends StatelessWidget {
  final double? value;
  final DsTone tone;
  final double height;
  final String? label;
  final bool showPercent;

  const DsProgressBar({super.key, this.value, this.tone = DsTone.brand, this.height = 8, this.label, this.showPercent = false});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final t = c.tone(tone);
    final v = value?.clamp(0.0, 1.0);
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: v == null
            ? LinearProgressIndicator(color: t.main, backgroundColor: c.surfaceAlt, minHeight: height)
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: v),
                duration: DsMotion.of(context, DsMotion.slower),
                curve: DsMotion.emphasized,
                builder: (context, x, _) => Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: c.surfaceAlt)),
                    FractionallySizedBox(
                      widthFactor: x,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height),
                          gradient: LinearGradient(colors: [Color.lerp(t.main, Colors.white, 0.15)!, t.main]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
    final semantic = Semantics(
      label: label,
      value: v == null ? null : '${(v * 100).round()}%',
      child: bar,
    );
    if (label == null && !showPercent) return semantic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (label != null) Expanded(child: Text(label!, style: DsTypography.labelSm.copyWith(color: c.textSecondary))) else const Spacer(),
            if (showPercent && v != null) Text('${(v * 100).round()}%', style: DsTypography.labelSm.copyWith(color: t.strong)),
          ],
        ),
        const DsGap(DsSpace.sm),
        ExcludeSemantics(child: bar),
      ],
    );
  }
}

/// Animated circular progress ring with centered content.
///
/// ```dart
/// DsProgressRing(value: 0.72, size: 96, center: Text('72%', style: t.titleSm))
/// ```
class DsProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final DsTone tone;
  final Widget? center;

  /// Colors for use on gradient heroes (white on translucent white).
  final bool onBrand;
  final String? semanticLabel;

  const DsProgressRing({super.key, required this.value, this.size = 72, this.stroke = 8, this.tone = DsTone.brand, this.center, this.onBrand = false, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final t = c.tone(tone);
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: v),
          duration: DsMotion.of(context, DsMotion.slower),
          curve: DsMotion.emphasized,
          builder: (context, x, child) => CustomPaint(
            painter: _RingPainter(
              value: x,
              stroke: stroke,
              color: onBrand ? Colors.white : t.main,
              track: onBrand ? Colors.white.withValues(alpha: 0.22) : c.surfaceAlt,
            ),
            child: child,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color color;
  final Color track;
  _RingPainter({required this.value, required this.stroke, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.value != value || o.color != color || o.track != track || o.stroke != stroke;
}

enum DsStepState { done, current, upcoming, error }

/// One entry of a [DsTimeline].
class DsTimelineStep {
  final String title;
  final String? subtitle;

  /// Right-aligned meta (time / date).
  final String? meta;
  final DsStepState state;
  final IconData? icon;

  /// Extra content under the subtitle.
  final Widget? content;

  const DsTimelineStep({required this.title, this.subtitle, this.meta, this.state = DsStepState.upcoming, this.icon, this.content});
}

/// Vertical timeline (order tracking, payout history, audit log). The
/// current step pulses softly.
///
/// ```dart
/// DsTimeline(steps: [
///   DsTimelineStep(title: 'Order placed'.tr, meta: '10:24', state: DsStepState.done),
///   DsTimelineStep(title: 'Preparing'.tr, state: DsStepState.current),
///   DsTimelineStep(title: 'Delivered'.tr),
/// ])
/// ```
class DsTimeline extends StatelessWidget {
  final List<DsTimelineStep> steps;
  const DsTimeline({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      _StepDot(step: steps[i], index: i),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: steps[i].state == DsStepState.done ? c.brand : c.border,
                              borderRadius: DsRadius.brPill,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < steps.length - 1 ? DsSpace.xl : 0, top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                steps[i].title,
                                style: DsTypography.bodyStrong.copyWith(
                                  color: steps[i].state == DsStepState.upcoming ? c.textMuted : c.textPrimary,
                                  fontWeight: steps[i].state == DsStepState.current ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (steps[i].meta != null) Text(steps[i].meta!, style: DsTypography.caption.copyWith(color: c.textMuted)),
                          ],
                        ),
                        if (steps[i].subtitle != null) ...[const DsGap(DsSpace.xxs), Text(steps[i].subtitle!, style: DsTypography.bodySm.copyWith(color: c.textSecondary))],
                        if (steps[i].content != null) ...[const DsGap(DsSpace.sm), steps[i].content!],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final DsTimelineStep step;
  final int index;
  const _StepDot({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    switch (step.state) {
      case DsStepState.done:
        return _circle(c.brand, Icon(step.icon ?? Icons.check_rounded, size: 14, color: c.onBrand));
      case DsStepState.error:
        return _circle(c.tone(DsTone.danger).main, Icon(step.icon ?? Icons.close_rounded, size: 14, color: Colors.white));
      case DsStepState.current:
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1),
          duration: DsMotion.of(context, DsMotion.slower),
          curve: DsMotion.spring,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.brandSoft, border: Border.all(color: c.brand, width: 2)),
            child: Center(
              child: step.icon != null
                  ? Icon(step.icon, size: 12, color: c.brandStrong)
                  : Container(width: 8, height: 8, decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle)),
            ),
          ),
        );
      case DsStepState.upcoming:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.surface, border: Border.all(color: c.borderStrong, width: 2)),
          child: step.icon != null ? Icon(step.icon, size: 12, color: c.textMuted) : null,
        );
    }
  }

  Widget _circle(Color color, Widget child) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Center(child: child),
  );
}

/// Horizontal step indicator for wizards / multi-step forms.
///
/// ```dart
/// Obx(() => DsStepper(steps: ['Details'.tr, 'Pricing'.tr, 'Media'.tr], current: c.step.value))
/// ```
class DsStepper extends StatelessWidget {
  final List<String> steps;
  final int current;

  /// Optional tap to jump to a completed step.
  final ValueChanged<int>? onStepTap;

  const DsStepper({super.key, required this.steps, required this.current, this.onStepTap});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final done = i < current;
      final active = i == current;
      children.add(
        Expanded(
          child: Semantics(
            label: '${i + 1}. ${steps[i]}',
            selected: active,
            child: InkWell(
              borderRadius: DsRadius.brSm,
              onTap: onStepTap != null && done ? () => onStepTap!(i) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: DsMotion.of(context, DsMotion.slow),
                      curve: DsMotion.emphasized,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: DsRadius.brPill,
                        color: done || active ? c.brand : c.surfaceAlt,
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    Text(
                      steps[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.labelSm.copyWith(color: active ? c.brandStrong : (done ? c.textPrimary : c.textMuted)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (i < steps.length - 1) children.add(const DsGap(DsSpace.sm));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
