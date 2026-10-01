/// Safe openers for the date / time pickers used across the Store app.
///
/// Report #8: "the schedule-time calendar does not display". Every opener in
/// this app went straight to `showDatePicker` with bounds the current value
/// could fall outside of - a coupon whose expiry has passed, an advertisement
/// whose campaign started before today - and `showDatePicker` asserts that the
/// initial date sits inside `firstDate`..`lastDate`. The dialog then never
/// appeared. The time pickers had the matching problem of always opening on
/// "now" instead of the time already saved, so a stored slot looked lost.
///
/// These helpers clamp first, so a picker always opens, and always opens on
/// the value that is already stored.
library;

import 'package:flutter/material.dart';

/// [value] pulled inside `first`..`last`, comparing whole days so a time of
/// day can never push a valid date out of range.
DateTime clampPickerDate(DateTime value, DateTime first, DateTime last) {
  final DateTime lower = DateUtils.dateOnly(first);
  final DateTime upper = DateUtils.dateOnly(last);
  final DateTime day = DateUtils.dateOnly(value);
  if (upper.isBefore(lower)) return lower;
  if (day.isBefore(lower)) return lower;
  if (day.isAfter(upper)) return upper;
  return day;
}

/// `showDatePicker` with the initial date pulled inside the caller's bounds
/// first, so the calendar always opens. [first] / [last] default to a wide
/// window around today.
///
/// Clamping rather than widening keeps the caller's rule (a coupon that may
/// only expire today or later still cannot be given a past date); it is the
/// *dialog* that must stop disappearing, not the rule.
Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) {
  final DateTime now = DateTime.now();
  final DateTime lower = DateUtils.dateOnly(first ?? DateTime(now.year - 5));
  DateTime upper = DateUtils.dateOnly(last ?? DateTime(now.year + 10, 12, 31));
  if (upper.isBefore(lower)) upper = lower;
  return showDatePicker(context: context, initialDate: clampPickerDate(initial ?? now, lower, upper), firstDate: lower, lastDate: upper);
}

/// `showTimePicker` opening on the time that is already stored.
Future<TimeOfDay?> pickTime(BuildContext context, {TimeOfDay? initial}) {
  return showTimePicker(context: context, initialTime: initial ?? TimeOfDay.now());
}

/// "HH:mm", "H:mm" or "h:mm AM/PM" as a [TimeOfDay], or null when it cannot be
/// read. Both shapes occur: working hours and discounts are stored 24-hour,
/// while the dine-in fields hold what `TimeOfDay.format` produced.
TimeOfDay? parseTimeOfDay(String? value) {
  if (value == null) return null;
  final String text = value.trim();
  if (text.isEmpty) return null;
  final RegExpMatch? match = RegExp(r'^(\d{1,2})\s*:\s*(\d{1,2})\s*([AaPp])?\.?[Mm]?\.?$').firstMatch(text);
  if (match == null) return null;
  int? hour = int.tryParse(match.group(1)!);
  final int? minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return null;
  final String? meridiem = match.group(3)?.toLowerCase();
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (meridiem == 'p' ? 12 : 0);
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}
