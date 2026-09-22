import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../foundation/ds_responsive.dart';
import '../loading/ds_loaders.dart';
import '../motion/ds_motion_widgets.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';
import 'ds_buttons.dart';
import 'ds_progress.dart';

// Driver-specific building blocks: online/offline state, map overlays,
// incoming request card, route stops, trip metrics, slide-to-confirm.
// All of them are presentational: they take values + callbacks and never
// read controllers themselves.

/// Small colored dot that can pulse (live states: online, on trip, SOS).
///
/// ```dart
/// DsPulseDot(color: c.online, pulse: true, size: 10)
/// ```
class DsPulseDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  final double size;

  const DsPulseDot({super.key, required this.color, this.pulse = true, this.size = 8});

  @override
  State<DsPulseDot> createState() => _DsPulseDotState();
}

class _DsPulseDotState extends State<DsPulseDot> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DsPulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.pulse && !DsMotion.reduced(context);
    if (animate && _c == null) {
      _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    } else if (!animate && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final dot = Container(width: s, height: s, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle));
    if (_c == null) return dot;
    return SizedBox.square(
      dimension: s,
      child: AnimatedBuilder(
        animation: _c!,
        builder: (_, _) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 1 + _c!.value * 1.6,
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(color: widget.color.withValues(alpha: (1 - _c!.value) * 0.5), shape: BoxShape.circle),
              ),
            ),
            dot,
          ],
        ),
      ),
    );
  }
}

/// The driver's online / offline switch. Large (56+), high-contrast, tap
/// anywhere to toggle, announces its state to screen readers.
///
/// Controlled: pass the current state and flip it in [onChanged] with the
/// screen's existing handler.
///
/// ```dart
/// Obx(() => DsOnlineToggle(
///   isOnline: c.driverModel.value.isActive == true,
///   loading: c.isUpdating.value,
///   onChanged: (v) => c.updateOnlineStatus(v),      // existing controller call
/// ))
/// DsOnlineToggle(compact: true, ...)                // app-bar pill
/// ```
class DsOnlineToggle extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool>? onChanged;
  final bool loading;

  /// Main label per state (defaults: "You're online" / "You're offline").
  final String? onlineLabel;
  final String? offlineLabel;

  /// Secondary line per state (e.g. "Receiving requests").
  final String? onlineSubtitle;
  final String? offlineSubtitle;

  /// Small pill for app bars / map overlays (48dp hit target).
  final bool compact;

  const DsOnlineToggle({
    super.key,
    required this.isOnline,
    required this.onChanged,
    this.loading = false,
    this.onlineLabel,
    this.offlineLabel,
    this.onlineSubtitle,
    this.offlineSubtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final enabled = onChanged != null && !loading;
    final label = isOnline ? (onlineLabel ?? "You're online".tr) : (offlineLabel ?? "You're offline".tr);
    final subtitle = isOnline ? onlineSubtitle : offlineSubtitle;
    final accent = isOnline ? c.online : c.offline;
    final bg = isOnline ? c.successSoft : c.offlineSoft;
    final fg = isOnline ? c.onlineStrong : c.textPrimary;
    final duration = DsMotion.of(context, DsMotion.base);

    final track = _Track(isOnline: isOnline, loading: loading, compact: compact, enabled: onChanged != null);

    final Widget content;
    if (compact) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsPulseDot(color: accent, pulse: isOnline, size: 8),
          const DsGap(DsSpace.sm),
          Flexible(
            child: Text(
              isOnline ? (onlineLabel ?? 'Online'.tr) : (offlineLabel ?? 'Offline'.tr),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.label.copyWith(color: fg, fontSize: 13),
            ),
          ),
          const DsGap(DsSpace.sm),
          track,
        ],
      );
    } else {
      content = Row(
        children: [
          DsPulseDot(color: accent, pulse: isOnline, size: 12),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: DsTypography.titleSm.copyWith(color: fg, fontWeight: FontWeight.w700)),
                if (subtitle != null && subtitle.isNotEmpty) Text(subtitle, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          const DsGap(DsSpace.md),
          track,
        ],
      );
    }

    return Semantics(
      toggled: isOnline,
      enabled: enabled,
      button: true,
      label: label,
      hint: subtitle,
      excludeSemantics: true,
      child: DsPressable(
        enabled: enabled,
        child: AnimatedContainer(
          duration: duration,
          curve: DsMotion.standard,
          constraints: BoxConstraints(minHeight: compact ? 40 : 64),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: DsRadius.brPill,
            border: Border.all(color: isOnline ? c.online.withValues(alpha: 0.55) : c.borderStrong, width: 1.4),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: DsRadius.brPill,
              onTap: enabled
                  ? () {
                      HapticFeedback.mediumImpact();
                      onChanged!(!isOnline);
                    }
                  : null,
              child: Padding(
                padding: compact
                    ? const EdgeInsetsDirectional.fromSTEB(DsSpace.md, DsSpace.xs, DsSpace.xs, DsSpace.xs)
                    : const EdgeInsetsDirectional.fromSTEB(DsSpace.xl, DsSpace.md, DsSpace.md, DsSpace.md),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  final bool isOnline;
  final bool loading;
  final bool compact;
  final bool enabled;
  const _Track({required this.isOnline, required this.loading, required this.compact, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final w = compact ? 44.0 : 60.0;
    final h = compact ? 26.0 : 34.0;
    final thumb = h - 6;
    final duration = DsMotion.of(context, DsMotion.base);
    final trackColor = !enabled ? c.surfaceAlt : (isOnline ? c.online : c.offline);
    return AnimatedContainer(
      duration: duration,
      curve: DsMotion.standard,
      width: w,
      height: h,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: trackColor, borderRadius: DsRadius.brPill),
      child: AnimatedAlign(
        duration: duration,
        curve: DsMotion.emphasized,
        alignment: isOnline ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(
          width: thumb,
          height: thumb,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: loading
              ? Padding(padding: EdgeInsets.all(thumb * 0.2), child: DsSpinner(size: thumb * 0.6, strokeWidth: 2, color: trackColor))
              : Icon(isOnline ? Icons.power_settings_new_rounded : Icons.power_off_rounded, size: thumb * 0.6, color: trackColor),
        ),
      ),
    );
  }
}

/// Section tag (Cab / Parcel / Rental / Delivery) in the section accent.
///
/// ```dart
/// DsSectionBadge(section: DsSection.fromServiceType(order.serviceType), label: 'Parcel'.tr)
/// ```
class DsSectionBadge extends StatelessWidget {
  final DsSection section;
  final String label;
  final bool solid;
  final IconData? icon;

  const DsSectionBadge({super.key, required this.section, required this.label, this.solid = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final t = DsColors.of(context).section(section);
    final fg = solid ? t.onMain : t.strong;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: solid ? t.main : t.soft, borderRadius: DsRadius.brPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? section.icon, size: 14, color: fg),
          const DsGap(DsSpace.xs),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.labelSm.copyWith(color: fg))),
        ],
      ),
    );
  }
}

/// Round floating control for use on top of a map (recenter, navigate, SOS,
/// layers). Always 48dp+, with a strong shadow so it reads over any map
/// tile. Pass [label] for an extended pill ("Navigate").
///
/// ```dart
/// DsMapButton(icon: Icons.my_location_rounded, semanticLabel: 'My location'.tr, onPressed: c.recenter)
/// DsMapButton(icon: Icons.navigation_rounded, label: 'Navigate'.tr, semanticLabel: 'Navigate'.tr, tone: DsTone.brand, onPressed: ...)
/// ```
class DsMapButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final String? label;

  /// `neutral` = surface button; any other tone = solid tone fill.
  final DsTone tone;
  final double size;

  const DsMapButton({super.key, required this.icon, required this.semanticLabel, required this.onPressed, this.label, this.tone = DsTone.neutral, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final t = c.tone(tone);
    final solid = tone != DsTone.neutral;
    final bg = solid ? t.main : c.surfaceRaised;
    final fg = onPressed == null ? c.textDisabled : (solid ? t.onMain : c.textPrimary);
    final h = size < 48 ? 48.0 : size;
    final shape = label == null ? const CircleBorder() : const StadiumBorder();
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: semanticLabel,
        excludeSemantics: true,
        child: DsPressable(
          enabled: onPressed != null,
          pressedScale: 0.94,
          child: DecoratedBox(
            decoration: ShapeDecoration(shape: shape, shadows: DsShadows.md(context)),
            child: Material(
              color: bg,
              shape: shape.copyWith(side: solid ? BorderSide.none : BorderSide(color: c.border)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: h, minWidth: h),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : DsSpace.lg),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: fg, size: 24),
                        if (label != null) ...[
                          const DsGap(DsSpace.sm),
                          Text(label!, style: DsTypography.label.copyWith(color: fg, fontSize: 15)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel that sits on top of a full-screen map: live trip / navigation
/// panel, "you're offline" card, request preview.
///
/// * Phones: docked to the bottom, rounded top, drag-handle look, safe-area
///   padded.
/// * Tablets / iPad (or `floating: true`): a floating card at the bottom
///   start corner (max 440 wide) so the map stays visible.
///
/// Put it in a `Stack` above the map: `Stack(children: [map, Align(alignment: Alignment.bottomCenter, child: DsMapPanel(...))])`.
///
/// ```dart
/// DsMapPanel(
///   header: Row(children: [DsStatusChip(label: 'On the way'.tr, tone: DsTone.info, pulse: true), const Spacer(), Text(eta, style: t.titleSm)]),
///   child: DsRouteStops(stops: [...]),
///   actions: DsSlideToConfirm(label: 'Slide to start trip'.tr, onConfirmed: c.startTrip),
/// )
/// ```
class DsMapPanel extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final Widget? actions;
  final EdgeInsetsGeometry padding;
  final bool showHandle;

  /// Force floating card style (defaults to `true` on tablets).
  final bool? floating;

  const DsMapPanel({
    super.key,
    required this.child,
    this.header,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.sm, DsSpace.xl, DsSpace.lg),
    this.showHandle = true,
    this.floating,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final l = DsLayout.of(context);
    final isFloating = floating ?? l.isWide;
    final radius = isFloating ? DsRadius.brXl : DsRadius.sheetTop;

    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHandle && !isFloating)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: DsSpace.sm, bottom: DsSpace.xs),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
            ),
          ),
        Padding(
          padding: isFloating ? padding.add(const EdgeInsets.only(top: DsSpace.md)) : padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[header!, const DsGap(DsSpace.md)],
              child,
              if (actions != null) ...[const DsGap(DsSpace.lg), actions!],
            ],
          ),
        ),
      ],
    );

    body = Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: radius,
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: DsShadows.lg(context),
      ),
      child: Material(type: MaterialType.transparency, borderRadius: radius, clipBehavior: Clip.antiAlias, child: body),
    );

    if (isFloating) {
      return SafeArea(
        top: false,
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          heightFactor: 1,
          child: Padding(
            padding: EdgeInsets.all(l.gutter),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: body),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: DsLayout.contentMax),
      child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom), child: body),
    );
  }
}

enum DsStopKind { pickup, stop, drop }

/// One stop of a [DsRouteStops] list.
class DsRouteStop {
  final DsStopKind kind;

  /// Small caption above the address ("Pickup", "Drop-off", store name).
  final String? label;
  final String address;

  /// Right side content (time, distance, a call / navigate button).
  final Widget? trailing;

  /// Stop already reached (greyed / checked).
  final bool done;

  const DsRouteStop({required this.kind, required this.address, this.label, this.trailing, this.done = false});
}

/// Vertical pickup → drop list with connecting line. Addresses wrap (max 2
/// lines by default) and never overflow at large text scales.
///
/// ```dart
/// DsRouteStops(stops: [
///   DsRouteStop(kind: DsStopKind.pickup, label: 'Pickup'.tr, address: order.sourceLocationName ?? ''),
///   DsRouteStop(kind: DsStopKind.drop, label: 'Drop-off'.tr, address: order.destinationLocationName ?? ''),
/// ])
/// ```
class DsRouteStops extends StatelessWidget {
  final List<DsRouteStop> stops;
  final int addressMaxLines;

  const DsRouteStops({super.key, required this.stops, this.addressMaxLines = 2});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < stops.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      const DsGap(2),
                      _StopMarker(stop: stops[i]),
                      if (i < stops.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(color: stops[i].done ? c.brand : c.borderStrong, borderRadius: DsRadius.brPill),
                          ),
                        ),
                    ],
                  ),
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < stops.length - 1 ? DsSpace.lg : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (stops[i].label != null) Text(stops[i].label!, style: DsTypography.caption.copyWith(color: c.textMuted)),
                              Text(
                                stops[i].address,
                                maxLines: addressMaxLines,
                                overflow: TextOverflow.ellipsis,
                                style: DsTypography.bodyStrong.copyWith(color: stops[i].done ? c.textSecondary : c.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        if (stops[i].trailing != null) ...[const DsGap(DsSpace.sm), stops[i].trailing!],
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

class _StopMarker extends StatelessWidget {
  final DsRouteStop stop;
  const _StopMarker({required this.stop});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    if (stop.done) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: 13, color: c.onBrand),
      );
    }
    switch (stop.kind) {
      case DsStopKind.pickup:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle, border: Border.all(color: c.routePickup, width: 2)),
          child: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.routePickup, shape: BoxShape.circle))),
        );
      case DsStopKind.stop:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.borderStrong, width: 2)),
        );
      case DsStopKind.drop:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: c.routeDrop, borderRadius: BorderRadius.circular(5)),
          child: const Icon(Icons.flag_rounded, size: 13, color: Colors.white),
        );
    }
  }
}

/// One cell of [DsTripMetrics].
class DsTripMetric {
  final IconData? icon;
  final String value;
  final String label;
  const DsTripMetric({this.icon, required this.value, required this.label});
}

/// Row of 2–4 glanceable trip numbers (distance, time, fare, weight)
/// separated by hairlines.
///
/// ```dart
/// DsTripMetrics(items: [
///   DsTripMetric(icon: Icons.route_rounded, value: '4.2 km', label: 'Distance'.tr),
///   DsTripMetric(icon: Icons.schedule_rounded, value: '12 min', label: 'ETA'.tr),
///   DsTripMetric(icon: Icons.payments_outlined, value: fare, label: 'Fare'.tr),
/// ])
/// ```
class DsTripMetrics extends StatelessWidget {
  final List<DsTripMetric> items;

  /// Draw inside a subtle filled container.
  final bool filled;

  const DsTripMetrics({super.key, required this.items, this.filled = true});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final cells = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) cells.add(VerticalDivider(width: DsSpace.lg, thickness: 1, color: c.divider, indent: 4, endIndent: 4));
      final m = items[i];
      cells.add(
        Expanded(
          child: Semantics(
            label: '${m.label}: ${m.value}',
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.icon != null) ...[Icon(m.icon, size: 18, color: c.iconDefault), const DsGap(DsSpace.xs)],
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(m.value, maxLines: 1, style: DsTypography.titleSm.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700).tabular),
                ),
                Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: DsTypography.caption.copyWith(color: c.textMuted)),
              ],
            ),
          ),
        ),
      );
    }
    final row = IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells));
    if (!filled) return row;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md, horizontal: DsSpace.sm),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
      child: row,
    );
  }
}

/// Label / value row for fare breakdowns, receipts, vehicle & document
/// details.
///
/// ```dart
/// DsInfoRow(label: 'Base fare'.tr, value: Constant.amountShow(amount: order.subTotal))
/// DsInfoRow(label: 'Total'.tr, value: total, emphasize: true, divider: false)
/// ```
class DsInfoRow extends StatelessWidget {
  final String label;
  final String? value;

  /// Custom value widget (overrides [value]).
  final Widget? valueWidget;
  final IconData? icon;

  /// Bigger, bold value (totals).
  final bool emphasize;

  /// Color the value with a tone (e.g. success for discounts).
  final DsTone? valueTone;
  final bool divider;

  const DsInfoRow({super.key, required this.label, this.value, this.valueWidget, this.icon, this.emphasize = false, this.valueTone, this.divider = false});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final valueColor = valueTone != null ? c.tone(valueTone!).strong : c.textPrimary;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: c.iconDefault), const DsGap(DsSpace.sm)],
          Expanded(
            child: Text(label, style: (emphasize ? DsTypography.titleSm : DsTypography.body).copyWith(color: emphasize ? c.textPrimary : c.textSecondary)),
          ),
          const DsGap(DsSpace.md),
          Flexible(
            child: valueWidget ??
                Text(
                  value ?? '',
                  textAlign: TextAlign.end,
                  style: (emphasize ? DsTypography.title : DsTypography.bodyStrong).copyWith(color: valueColor).tabular,
                ),
          ),
        ],
      ),
    );
    if (!divider) return row;
    return Column(mainAxisSize: MainAxisSize.min, children: [row, Divider(height: 1, thickness: 1, color: c.divider)]);
  }
}

/// Swipe-to-confirm control for irreversible, on-the-road actions (start
/// trip, picked up, delivered, complete ride). A deliberate horizontal drag
/// prevents accidental taps on a mounted phone. Screen readers get a normal
/// double-tap button. RTL aware.
///
/// While [loading] is true after confirming, the thumb stays at the end with
/// a spinner; when loading ends (or the parent never sets it) it slides back.
///
/// ```dart
/// DsSlideToConfirm(label: 'Slide to start trip'.tr, icon: Icons.play_arrow_rounded, onConfirmed: c.startTrip)
/// DsSlideToConfirm(label: 'Slide when delivered'.tr, tone: DsTone.success, loading: c.isLoading.value, onConfirmed: ...)
/// ```
class DsSlideToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback? onConfirmed;
  final IconData icon;
  final DsTone tone;
  final bool loading;
  final double height;

  const DsSlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.icon = Icons.double_arrow_rounded,
    this.tone = DsTone.brand,
    this.loading = false,
    this.height = 64,
  });

  @override
  State<DsSlideToConfirm> createState() => _DsSlideToConfirmState();
}

class _DsSlideToConfirmState extends State<DsSlideToConfirm> with SingleTickerProviderStateMixin {
  static const double _threshold = 0.82;
  late final AnimationController _c = AnimationController(vsync: this, duration: DsMotion.base);
  bool _confirmed = false;

  bool get _enabled => widget.onConfirmed != null && !widget.loading && !_confirmed;

  @override
  void didUpdateWidget(covariant DsSlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading && !widget.loading) _reset();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _reset() {
    if (!mounted) return;
    _confirmed = false;
    _c.animateTo(0, duration: DsMotion.of(context, DsMotion.base), curve: DsMotion.standard);
    setState(() {});
  }

  void _confirm() {
    if (!_enabled) return;
    setState(() => _confirmed = true);
    HapticFeedback.mediumImpact();
    _c.animateTo(1, duration: DsMotion.of(context, DsMotion.fast), curve: DsMotion.standard);
    widget.onConfirmed!();
    // If the parent does not switch to `loading`, slide back after a moment.
    Future.delayed(DsMotion.slower, () {
      if (mounted && !widget.loading) _reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final t = c.tone(widget.tone);
    final disabled = widget.onConfirmed == null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final h = widget.height < 56 ? 56.0 : widget.height;
    const inset = 4.0;
    final thumb = h - inset * 2;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      onTap: _enabled ? _confirm : null,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
          final maxDrag = (w - thumb - inset * 2).clamp(1.0, double.infinity);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _enabled
                ? (d) {
                    final delta = (d.primaryDelta ?? 0) / maxDrag;
                    _c.value = (_c.value + (rtl ? -delta : delta)).clamp(0.0, 1.0);
                  }
                : null,
            onHorizontalDragEnd: _enabled
                ? (_) {
                    if (_c.value >= _threshold) {
                      _confirm();
                    } else {
                      _c.animateTo(0, duration: DsMotion.of(context, DsMotion.base), curve: DsMotion.spring);
                    }
                  }
                : null,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final v = _c.value;
                return Container(
                  height: h,
                  decoration: BoxDecoration(
                    color: disabled ? c.surfaceAlt : t.soft,
                    borderRadius: DsRadius.brPill,
                    border: Border.all(color: disabled ? c.border : t.main.withValues(alpha: 0.4)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Filled progress behind the thumb.
                      PositionedDirectional(
                        start: 0,
                        top: 0,
                        bottom: 0,
                        width: thumb + inset * 2 + v * maxDrag,
                        child: Container(decoration: BoxDecoration(color: disabled ? Colors.transparent : t.main.withValues(alpha: 0.22 + 0.5 * v), borderRadius: DsRadius.brPill)),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.only(start: thumb + DsSpace.md, end: DsSpace.lg),
                        child: Opacity(
                          opacity: (1 - v * 1.6).clamp(0.0, 1.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DsTypography.label.copyWith(color: disabled ? c.textDisabled : t.strong, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const DsGap(DsSpace.xs),
                              Icon(rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: disabled ? c.textDisabled : t.strong.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: inset + v * maxDrag,
                        top: inset,
                        child: Container(
                          width: thumb,
                          height: thumb,
                          decoration: BoxDecoration(
                            color: disabled ? c.textDisabled : t.main,
                            shape: BoxShape.circle,
                            boxShadow: disabled ? null : DsShadows.glow(context, color: t.main).take(1).toList(),
                          ),
                          child: Center(
                            child: widget.loading || (_confirmed && v >= 0.99)
                                ? (widget.loading ? DsSpinner(size: thumb * 0.4, color: t.onMain) : Icon(Icons.check_rounded, color: t.onMain, size: thumb * 0.45))
                                : Transform.flip(flipX: rtl, child: Icon(widget.icon, color: disabled ? c.surface : t.onMain, size: thumb * 0.45)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Incoming request card (new ride / delivery / parcel / rental offer):
/// section tag, countdown ring, big fare, pickup → drop, trip metrics and
/// large Accept / Reject buttons (or slide-to-accept).
///
/// It only displays values; pass the screen's existing handlers.
///
/// ```dart
/// DsRequestCard(
///   title: 'New ride request'.tr,
///   section: DsSection.cab, sectionLabel: 'Cab'.tr,
///   fare: Constant.amountShow(amount: order.subTotal), fareCaption: order.paymentMethod,
///   countdown: secondsLeft / 30, countdownLabel: '$secondsLeft',
///   stops: [DsRouteStop(kind: DsStopKind.pickup, label: 'Pickup'.tr, address: ...), DsRouteStop(kind: DsStopKind.drop, label: 'Drop-off'.tr, address: ...)],
///   metrics: [DsTripMetric(icon: Icons.route_rounded, value: '4.2 km', label: 'Distance'.tr)],
///   onReject: () => c.rejectOrder(order),
///   onAccept: () => c.acceptOrder(order),
/// )
/// ```
class DsRequestCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final DsSection? section;
  final String? sectionLabel;
  final String? fare;
  final String? fareCaption;
  final List<DsRouteStop> stops;
  final List<DsTripMetric> metrics;

  /// Remaining time as 0..1 (ring turns warning under 30%). Null hides it.
  final double? countdown;
  final String? countdownLabel;

  /// Customer row / notes / parcel info between route and actions.
  final Widget? extra;
  final String? acceptLabel;
  final VoidCallback? onAccept;
  final bool accepting;
  final String? rejectLabel;
  final VoidCallback? onReject;

  /// Use a [DsSlideToConfirm] for accept instead of buttons.
  final bool slideToAccept;
  final EdgeInsetsGeometry? margin;

  const DsRequestCard({
    super.key,
    required this.title,
    this.subtitle,
    this.section,
    this.sectionLabel,
    this.fare,
    this.fareCaption,
    this.stops = const [],
    this.metrics = const [],
    this.countdown,
    this.countdownLabel,
    this.extra,
    this.acceptLabel,
    this.onAccept,
    this.accepting = false,
    this.rejectLabel,
    this.onReject,
    this.slideToAccept = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final urgent = countdown != null && countdown! < 0.3;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (section != null && sectionLabel != null) ...[DsSectionBadge(section: section!, label: sectionLabel!), const DsGap(DsSpace.sm)],
              Semantics(header: true, child: Text(title, style: DsTypography.title.copyWith(color: c.textPrimary))),
              if (subtitle != null) Text(subtitle!, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
        if (countdown != null)
          DsProgressRing(
            value: countdown!,
            size: 56,
            stroke: 6,
            tone: urgent ? DsTone.danger : DsTone.brand,
            semanticLabel: 'Time left'.tr,
            center: countdownLabel == null
                ? null
                : Text(countdownLabel!, style: DsTypography.titleSm.copyWith(color: urgent ? c.dangerStrong : c.textPrimary, fontWeight: FontWeight.w700).tabular),
          ),
      ],
    );

    final Widget actions;
    if (slideToAccept) {
      actions = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSlideToConfirm(label: acceptLabel ?? 'Slide to accept'.tr, tone: DsTone.success, icon: Icons.check_rounded, loading: accepting, onConfirmed: onAccept),
          if (onReject != null) ...[const DsGap(DsSpace.sm), DsButton.ghost(label: rejectLabel ?? 'Reject'.tr, expand: true, color: c.dangerStrong, onPressed: onReject)],
        ],
      );
    } else {
      final accept = DsButton.success(label: acceptLabel ?? 'Accept'.tr, icon: Icons.check_rounded, size: DsButtonSize.xl, expand: true, loading: accepting, onPressed: onAccept);
      actions = onReject == null
          ? accept
          : Row(
              children: [
                Expanded(child: DsButton.dangerTonal(label: rejectLabel ?? 'Reject'.tr, size: DsButtonSize.xl, expand: true, onPressed: onReject)),
                const DsGap(DsSpace.md),
                Expanded(flex: 2, child: accept),
              ],
            );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: DsRadius.brXl,
        border: Border.all(color: urgent ? c.danger.withValues(alpha: 0.6) : c.brandMuted, width: 1.4),
        boxShadow: DsShadows.lg(context),
      ),
      padding: const EdgeInsets.all(DsSpace.xl),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            if (fare != null) ...[
              const DsGap(DsSpace.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(fare!, style: DsTypography.metricLg.copyWith(color: c.textPrimary)))),
                  if (fareCaption != null) ...[
                    const DsGap(DsSpace.sm),
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(fareCaption!, style: DsTypography.labelSm.copyWith(color: c.textSecondary))),
                  ],
                ],
              ),
            ],
            if (stops.isNotEmpty) ...[const DsGap(DsSpace.lg), DsRouteStops(stops: stops)],
            if (metrics.isNotEmpty) ...[const DsGap(DsSpace.lg), DsTripMetrics(items: metrics)],
            if (extra != null) ...[const DsGap(DsSpace.lg), extra!],
            const DsGap(DsSpace.xl),
            actions,
          ],
        ),
      ),
    );
  }
}
