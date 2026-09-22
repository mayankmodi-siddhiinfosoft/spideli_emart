import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

/// Toasts and the blocking loader. Their look (raised DS panel, brand
/// loader, DS typography, light / dark) comes from `configEasyLoading()` in
/// `easy_loading_config.dart`; keep calling these from screens and
/// controllers.
class ShowToastDialog {
  /// Show a toast message with customizable position.
  static void showToast(
    String? message, {
    EasyLoadingToastPosition position = EasyLoadingToastPosition.top,
  }) {
    if (message == null || message.isEmpty) return;
    EasyLoading.showToast(message, toastPosition: position);
    _announce(message);
  }

  /// Show a loading indicator with a status message.
  static void showLoader(String message) {
    EasyLoading.show(
      status: message,
      dismissOnTap: false,
      maskType: EasyLoadingMaskType.clear,
    );
    _announce(message);
  }

  /// Dismiss any active loading indicator.
  static void closeLoader() {
    EasyLoading.dismiss();
  }

  /// Reads toasts / loader status to screen-reader users (TalkBack /
  /// VoiceOver). The EasyLoading overlay is not a live region by itself.
  static void _announce(String message) {
    try {
      final binding = WidgetsBinding.instance;
      if (!binding.platformDispatcher.accessibilityFeatures.accessibleNavigation) return;
      final view = binding.platformDispatcher.implicitView;
      if (view == null) return;
      final ctx = Get.context;
      final direction = (ctx != null ? Directionality.maybeOf(ctx) : null) ?? TextDirection.ltr;
      SemanticsService.sendAnnouncement(view, message, direction);
    } catch (_) {
      // Announcements are best effort only.
    }
  }
}
