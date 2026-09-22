import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../foundation/ds_responsive.dart';
import '../motion/ds_motion_widgets.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';
import 'ds_buttons.dart';

/// Friendly empty state: illustration/icon in a soft halo, title, message
/// and optional action. Animates in.
///
/// ```dart
/// DsEmptyState(icon: Icons.local_shipping_outlined, title: 'No trips yet'.tr, message: 'Go online to start receiving requests.'.tr, actionLabel: 'Go online'.tr, onAction: ...)
/// ```
class DsEmptyState extends StatelessWidget {
  final IconData? icon;

  /// Custom illustration (SvgPicture / Image) – replaces [icon].
  final Widget? illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final DsTone tone;

  /// Smaller version for use inside cards / sections.
  final bool compact;

  const DsEmptyState({
    super.key,
    this.icon,
    this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.tone = DsTone.brand,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final t = c.tone(tone);
    final halo = compact ? 72.0 : 112.0;
    final visual = illustration != null
        ? SizedBox(height: compact ? 96 : 160, child: illustration)
        : Container(
            width: halo,
            height: halo,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [t.soft, t.soft.withValues(alpha: 0)], stops: const [0.55, 1]),
            ),
            alignment: Alignment.center,
            child: Container(
              width: halo * 0.62,
              height: halo * 0.62,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle, border: Border.all(color: t.main.withValues(alpha: 0.18))),
              child: Icon(icon ?? Icons.inbox_outlined, size: halo * 0.3, color: t.strong),
            ),
          );

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: DsSpace.xxl, vertical: compact ? DsSpace.lg : DsSpace.xxxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: DsFadeSlideIn.stagger([
              visual,
              Padding(
                padding: EdgeInsets.only(top: compact ? DsSpace.md : DsSpace.xl),
                child: Text(title, textAlign: TextAlign.center, style: (compact ? DsTypography.titleSm : DsTypography.title).copyWith(color: c.textPrimary)),
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.sm),
                  child: Text(message!, textAlign: TextAlign.center, style: DsTypography.body.copyWith(color: c.textSecondary)),
                ),
              if (actionLabel != null && onAction != null)
                Padding(
                  padding: EdgeInsets.only(top: compact ? DsSpace.lg : DsSpace.xxl),
                  child: DsButton.primary(label: actionLabel!, icon: actionIcon, onPressed: onAction),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Error state with retry.
///
/// ```dart
/// DsErrorState(message: 'Could not load orders'.tr, onRetry: c.getOrders)
/// ```
class DsErrorState extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData icon;
  final bool compact;

  const DsErrorState({super.key, this.title, this.message, this.onRetry, this.retryLabel, this.icon = Icons.cloud_off_rounded, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      icon: icon,
      tone: DsTone.danger,
      compact: compact,
      title: title ?? 'Something went wrong'.tr,
      message: message ?? 'Please check your connection and try again.'.tr,
      actionLabel: onRetry != null ? (retryLabel ?? 'Try again'.tr) : null,
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
    );
  }
}

/// Inline alert / banner (tips, warnings, verification notices).
///
/// ```dart
/// DsInlineAlert(tone: DsTone.warning, title: 'Documents pending'.tr, message: 'Upload your documents to start driving.'.tr, actionLabel: 'Upload'.tr, onAction: ...)
/// ```
class DsInlineAlert extends StatelessWidget {
  final DsTone tone;
  final String? title;
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  const DsInlineAlert({super.key, this.tone = DsTone.info, this.title, required this.message, this.icon, this.actionLabel, this.onAction, this.onClose});

  IconData get _defaultIcon => switch (tone) {
    DsTone.success => Icons.check_circle_outline_rounded,
    DsTone.warning => Icons.warning_amber_rounded,
    DsTone.danger => Icons.error_outline_rounded,
    _ => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final t = c.tone(tone);
    return Semantics(
      container: true,
      liveRegion: tone == DsTone.danger,
      child: Container(
        padding: const EdgeInsets.all(DsSpace.md),
        decoration: BoxDecoration(color: t.soft, borderRadius: DsRadius.brMd, border: Border.all(color: t.main.withValues(alpha: 0.25))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? _defaultIcon, color: t.strong, size: 20),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) Text(title!, style: DsTypography.label.copyWith(color: t.strong)),
                  Text(message, style: DsTypography.bodySm.copyWith(color: c.textPrimary)),
                  if (actionLabel != null && onAction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpace.xs),
                      child: InkWell(
                        onTap: onAction,
                        borderRadius: DsRadius.brXs,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                          child: Text(actionLabel!, style: DsTypography.label.copyWith(color: t.strong, decoration: TextDecoration.underline, decorationColor: t.strong)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onClose != null) DsIconButton(icon: Icons.close_rounded, semanticLabel: 'Dismiss'.tr, size: 32, color: t.strong, onPressed: onClose),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet content frame: drag handle, optional title/subtitle/close,
/// scrollable body, optional sticky actions, keyboard & safe-area aware,
/// width-capped on tablets.
///
/// Use directly inside an existing `Get.bottomSheet(...)` /
/// `showModalBottomSheet` call, or via [DsBottomSheet.show].
class DsSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;

  /// Sticky footer (buttons).
  final Widget? actions;
  final bool showClose;
  final EdgeInsetsGeometry? padding;

  const DsSheet({super.key, this.title, this.subtitle, required this.child, this.actions, this.showClose = false, this.padding});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: DsLayout.contentMax, maxHeight: mq.size.height * 0.92),
          child: Material(
            color: c.surfaceRaised,
            shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: DsSpace.sm, bottom: DsSpace.xs),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
                    ),
                  ),
                  if (title != null || showClose)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.sm, DsSpace.sm, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: DsSpace.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (title != null) Semantics(header: true, child: Text(title!, style: DsTypography.title.copyWith(color: c.textPrimary))),
                                  if (subtitle != null) Text(subtitle!, style: DsTypography.bodySm.copyWith(color: c.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                          if (showClose) DsIconButton(icon: Icons.close_rounded, semanticLabel: 'Close'.tr, variant: DsIconButtonVariant.tonal, size: 36, onPressed: () => Navigator.of(context).maybePop()),
                        ],
                      ),
                    ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: padding ?? const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.lg, DsSpace.xl, DsSpace.lg),
                      child: child,
                    ),
                  ),
                  if (actions != null)
                    Padding(padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.sm, DsSpace.xl, DsSpace.lg), child: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper to present a [DsSheet] with GetX.
abstract final class DsBottomSheet {
  /// ```dart
  /// DsBottomSheet.show(title: 'Filter orders'.tr, child: FilterForm(), actions: DsButton.primary(label: 'Apply'.tr, expand: true, onPressed: ...));
  /// ```
  static Future<T?> show<T>({
    required Widget child,
    String? title,
    String? subtitle,
    Widget? actions,
    bool showClose = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return Get.bottomSheet<T>(
      DsSheet(title: title, subtitle: subtitle, actions: actions, showClose: showClose, child: child),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      barrierColor: DsColors.resolve(Get.isDarkMode).scrim,
    );
  }
}

/// Modern dialog: tone icon, title, message, optional custom content and
/// one or two actions (stacked vertically when space is tight).
///
/// Use as the child of an existing `showDialog` / `Get.dialog`, or via
/// [DsDialog.show] / [DsDialog.confirm].
class DsDialog extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final DsTone tone;
  final Widget? content;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Primary action is destructive (red).
  final bool destructive;

  const DsDialog({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.tone = DsTone.brand,
    this.content,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.destructive = false,
  });

  /// Shows any [DsDialog] with a scale+fade entrance.
  static Future<T?> show<T>(DsDialog dialog, {bool barrierDismissible = true}) {
    return Get.dialog<T>(dialog, barrierDismissible: barrierDismissible, barrierColor: DsColors.resolve(Get.isDarkMode).scrim, transitionDuration: DsMotion.base);
  }

  /// Confirmation dialog. Resolves `true` when the primary action is tapped,
  /// `false` otherwise.
  ///
  /// ```dart
  /// final ok = await DsDialog.confirm(title: 'Cancel trip?'.tr, message: '...'.tr, confirmLabel: 'Delete'.tr, destructive: true);
  /// if (ok) controller.cancelTrip();
  /// ```
  static Future<bool> confirm({
    required String title,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
    IconData? icon,
    bool destructive = false,
  }) async {
    final r = await show<bool>(
      DsDialog(
        title: title,
        message: message,
        icon: icon ?? (destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded),
        tone: destructive ? DsTone.danger : DsTone.brand,
        destructive: destructive,
        primaryLabel: confirmLabel ?? 'Confirm'.tr,
        onPrimary: () => Get.back(result: true),
        secondaryLabel: cancelLabel ?? 'Cancel'.tr,
        onSecondary: () => Get.back(result: false),
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    final t = c.tone(tone);
    final primary = primaryLabel == null
        ? null
        : (destructive ? DsButton.danger(label: primaryLabel!, expand: true, onPressed: onPrimary) : DsButton.primary(label: primaryLabel!, expand: true, onPressed: onPrimary));
    final secondary = secondaryLabel == null ? null : DsButton.secondary(label: secondaryLabel!, expand: true, onPressed: onSecondary);

    return Dialog(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: DsRadius.brXl),
      insetPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl, vertical: DsSpace.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DsSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: DsMotion.of(context, DsMotion.slow),
                  curve: DsMotion.spring,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                    child: Icon(icon, color: t.strong, size: 30),
                  ),
                ),
                const DsGap(DsSpace.lg),
              ],
              Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: DsTypography.title.copyWith(color: c.textPrimary))),
              if (message != null) ...[
                const DsGap(DsSpace.sm),
                Text(message!, textAlign: TextAlign.center, style: DsTypography.body.copyWith(color: c.textSecondary)),
              ],
              if (content != null) ...[const DsGap(DsSpace.lg), content!],
              if (primary != null || secondary != null) ...[
                const DsGap(DsSpace.xxl),
                LayoutBuilder(
                  builder: (context, cons) {
                    final stack = cons.maxWidth < 280 || MediaQuery.textScalerOf(context).scale(14) > 18;
                    if (primary != null && secondary != null && !stack) {
                      return Row(children: [Expanded(child: secondary), const DsGap(DsSpace.md), Expanded(child: primary)]);
                    }
                    return Column(children: [?primary, if (primary != null && secondary != null) const DsGap(DsSpace.sm), ?secondary]);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
