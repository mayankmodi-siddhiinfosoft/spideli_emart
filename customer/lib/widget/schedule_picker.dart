import 'package:bottom_picker/bottom_picker.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The one place the app opens a date **and** time picker (checkout schedule,
/// on-demand booking slot, ...).
///
/// Everything that can leave the sheet empty is handled here:
///
/// * `bottom_picker` asserts `minDateTime.isBefore(maxDateTime)` and the
///   underlying `CupertinoDatePicker` asserts that the initial value sits
///   inside the range — a half-set value (a schedule time saved yesterday, a
///   max that is already in the past) used to throw inside the tap handler and
///   nothing appeared. [clampScheduleDateTime] folds the value into the range
///   first, and an inconsistent range is dropped rather than asserted on.
/// * The sheet itself is still opened defensively: if it ever throws again the
///   user gets a toast instead of a tap that silently does nothing.
///
/// `bottom_picker` 5 is built on the standalone `material_ui` / `cupertino_ui`
/// packages; their localization delegates are registered in `main.dart`, which
/// is what actually lets this sheet appear at all.
void showSchedulePicker({
  required BuildContext context,
  required String title,
  required ValueChanged<DateTime> onPicked,
  DateTime? initialDateTime,
  DateTime? minDateTime,
  DateTime? maxDateTime,
}) {
  final c = context.dsColors;
  final t = context.dsText;

  // An inconsistent range (min after max) is never worth throwing over: keep
  // the lower bound, which is the one every caller actually cares about.
  DateTime? min = minDateTime;
  DateTime? max = maxDateTime;
  if (min != null && max != null && !min.isBefore(max)) max = null;

  final DateTime initial = clampScheduleDateTime(initialDateTime, min: min, max: max);

  try {
    // onSubmit / displaySubmitButton / buttonSingleColor are deprecated in
    // bottom_picker 5 in favour of buttonBuilder; they are kept so the sheet
    // stays the one the app already shipped.
    // ignore_for_file: deprecated_member_use
    BottomPicker<DateTime>.dateTime(
      onSubmit: (value) {
        if (value is DateTime) onPicked(value);
      },
      initialDateTime: initial,
      minDateTime: min,
      maxDateTime: max,
      displaySubmitButton: true,
      buttonAlignment: MainAxisAlignment.center,
      buttonSingleColor: c.brand,
      backgroundColor: c.surfaceRaised,
      pickerTextStyle: t.bodyStrong,
      // bottom_picker 5 dropped pickerTitle and the built-in close icon; rebuild the same header.
      headerBuilder: (context) => Row(
        children: [
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong)),
          DsIconButton(icon: Icons.close_rounded, semanticLabel: 'Close'.tr, size: 36, onPressed: () => Navigator.pop(context)),
        ],
      ),
    ).show(context);
  } catch (e, s) {
    debugPrint('showSchedulePicker failed: $e');
    debugPrintStack(stackTrace: s);
    ShowToastDialog.showToast("Something went wrong, please try again.".tr);
  }
}

/// Folds [value] into `[min, max]` so a stale or half-set schedule time can
/// never put the picker outside its own bounds. Falls back to "now", clamped
/// the same way, when there is nothing usable to start from.
@visibleForTesting
DateTime clampScheduleDateTime(DateTime? value, {DateTime? min, DateTime? max}) {
  var result = value ?? DateTime.now();
  if (min != null && result.isBefore(min)) result = min;
  if (max != null && result.isAfter(max)) result = max;
  return result;
}
