import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// A +/- quantity control whose **number is tappable**, so a customer ordering
/// 80 units types 80 instead of pressing + eighty times (client report #21,
/// 1 October).
///
/// The +/- buttons keep their existing behaviour and handlers; tapping the
/// number opens [showQuantityInputSheet], and the typed value is put through
/// [clampQuantity] before it reaches [onQuantity]:
///
/// * below [minQuantity] (the product's minimum, including a wholesale pack
///   floor) is raised to it;
/// * above [maxQuantity] (available stock) is capped, and the customer is told;
/// * `-1` as [maxQuantity] means unlimited stock, as everywhere else in the app;
/// * an empty or non-numeric entry leaves the quantity untouched;
/// * `0` is only accepted where it means something — a cart line, which it
///   removes ([allowZero]).
///
/// Leaving [onQuantity] null keeps a plain stepper (the number is then not
/// tappable), so existing call sites can adopt this one at a time.
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onRemove;
  final VoidCallback onAdd;

  /// Receives the typed, already-clamped quantity. Null → no direct entry.
  final ValueChanged<int>? onQuantity;

  final int minQuantity;

  /// Available stock; `-1` for unlimited.
  final int maxQuantity;

  /// Accept 0 (a cart line, where it removes the line).
  final bool allowZero;

  /// Title of the input sheet.
  final String? label;

  final double buttonSize;
  final BoxDecoration? decoration;
  final double minHeight;
  final MainAxisAlignment alignment;

  /// Fill the available width (a stepper across a card or a sticky bar) rather
  /// than shrink-wrap (a cart line).
  final bool expand;

  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onRemove,
    required this.onAdd,
    this.onQuantity,
    this.minQuantity = 1,
    this.maxQuantity = -1,
    this.allowZero = false,
    this.label,
    this.buttonSize = 32,
    this.decoration,
    this.minHeight = 40,
    this.alignment = MainAxisAlignment.center,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

    Widget number = Text("$quantity", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular);
    if (onQuantity != null) {
      number = Semantics(
        button: true,
        label: label ?? "Quantity".tr,
        child: InkWell(
          onTap: () => showQuantityInputSheet(
            context: context,
            current: quantity,
            minQuantity: minQuantity,
            maxQuantity: maxQuantity,
            allowZero: allowZero,
            label: label,
            onSubmit: onQuantity!,
          ),
          borderRadius: DsRadius.brSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xxs),
            // Underlined so it reads as something you can tap and type into.
            child: Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
              child: Text("$quantity", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.tabular),
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: decoration ?? BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brPill, border: Border.all(color: c.border)),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DsIconButton(icon: Icons.remove_rounded, semanticLabel: 'Remove'.tr, size: buttonSize, onPressed: onRemove),
          number,
          DsIconButton(icon: Icons.add_rounded, semanticLabel: 'Add item'.tr, size: buttonSize, onPressed: onAdd),
        ],
      ),
    );
  }
}

/// Small numeric entry for a quantity. Opens over the keyboard (DsSheet already
/// applies `viewInsets`) and hands back a value that is safe to use.
Future<void> showQuantityInputSheet({
  required BuildContext context,
  required int current,
  required int minQuantity,
  required int maxQuantity,
  required bool allowZero,
  required ValueChanged<int> onSubmit,
  String? label,
}) {
  final TextEditingController controller = TextEditingController(text: "$current");
  controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);

  void submit(BuildContext sheetContext) {
    final String raw = controller.text.trim();
    final int? parsed = int.tryParse(raw);
    Navigator.of(sheetContext).pop();
    // Nothing typed, or not a number: leave the quantity exactly as it was.
    if (raw.isEmpty || parsed == null) return;
    final int value = clampQuantity(parsed, minQuantity: minQuantity, maxQuantity: maxQuantity, allowZero: allowZero);
    if (value != parsed) {
      ShowToastDialog.showToast(
        maxQuantity >= 0 && parsed > maxQuantity ? "${'Only'.tr} $maxQuantity ${'available'.tr}" : "${'Minimum quantity'.tr}: $value",
      );
    }
    if (value == current) return;
    onSubmit(value);
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
    clipBehavior: Clip.antiAliasWithSaveLayer,
    builder: (sheetContext) {
      final c = DsColors.of(sheetContext);
      final t = DsTextTheme(c);
      final List<String> hints = [
        if (minQuantity > 1) "${'Minimum quantity'.tr}: $minQuantity",
        if (maxQuantity >= 0) "${'Only'.tr} $maxQuantity ${'available'.tr}",
      ];
      return DsSheet(
        title: label ?? "Quantity".tr,
        subtitle: hints.isEmpty ? null : hints.join(' · '),
        showClose: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              prefixIcon: Icons.numbers_rounded,
              bottomSpacing: DsSpace.md,
              onSubmitted: (_) => submit(sheetContext),
            ),
            DsButton.primary(label: "Done".tr, expand: true, onPressed: () => submit(sheetContext)),
            const DsGap(DsSpace.sm),
            Text("Leave it empty to keep the current quantity.".tr, style: t.caption, textAlign: TextAlign.center),
          ],
        ),
      );
    },
  );
}

/// Folds a typed quantity into what the product actually allows.
@visibleForTesting
int clampQuantity(int value, {required int minQuantity, required int maxQuantity, bool allowZero = false}) {
  if (allowZero && value <= 0) return 0;
  final int floor = minQuantity < 1 ? 1 : minQuantity;
  var result = value < floor ? floor : value;
  // -1 is this app's "unlimited stock".
  if (maxQuantity >= 0 && result > maxQuantity) result = maxQuantity;
  // A stock cap below the product's own minimum must not produce a quantity
  // nobody can order; the caller's "out of stock" guards still apply.
  if (result < 0) result = 0;
  return result;
}
