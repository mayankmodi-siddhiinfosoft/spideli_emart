import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Shared bits of the Spideli Finance screens.
abstract final class FinanceUi {
  static DsTone tone(String key) {
    switch (key) {
      case 'success':
        return DsTone.success;
      case 'warning':
        return DsTone.warning;
      case 'danger':
        return DsTone.danger;
      case 'info':
        return DsTone.info;
    }
    return DsTone.neutral;
  }

  static Widget kycBadge(String? status) => DsBadge(label: KycStatus.label(status).tr, tone: tone(KycStatus.tone(status)));

  /// A Firestore timestamp as a DateTime, or null.
  static DateTime? toDate(dynamic value) => value is Timestamp ? value.toDate() : null;

  /// Date and time: "05 Oct 2026, 14:30", from a Timestamp or a DateTime.
  static String date(dynamic value) {
    final DateTime? d = value is DateTime ? value : toDate(value);
    if (d == null) return '-';
    return ltr(DateFormat('dd MMM yyyy, HH:mm').format(d));
  }

  /// The day only: "05 Oct 2026", from a Timestamp or a DateTime.
  static String day(dynamic value) {
    final DateTime? d = value is DateTime ? value : toDate(value);
    if (d == null) return '-';
    return ltr(DateFormat('dd MMM yyyy').format(d));
  }

  /// "1 day", "3 days": [n] with the singular or plural key.
  static String count(num n, String one, String many) => '$n ${(n == 1 ? one : many).tr}';

  /// Runs [action] behind the loader; a server refusal becomes its translated message.
  static Future<bool> run(Future<void> Function() action, {String? success}) async {
    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      await action();
      ShowToastDialog.closeLoader();
      if (success != null) ShowToastDialog.showToast(success.tr);
      return true;
    } on FinanceException catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(FinanceErrors.messageKey(e.reason).tr);
      return false;
    } catch (_) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(FinanceErrors.messageKey(null).tr);
      return false;
    }
  }
}
