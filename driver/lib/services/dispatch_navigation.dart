import 'package:driver/app/multi_service/multi_service_dashboard_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/cab_dashboard_controller.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/parcel_dashboard_controller.dart';
import 'package:driver/controllers/rental_dashboard_controller.dart';
import 'package:driver/controllers/signup_controller.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/services/incoming_offer_service.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Opens the job screen (the module's home) of a dispatched service, from
/// wherever the driver is: after an accept in the incoming-offer dialog, or a
/// tap on a dispatch push for an order that is no longer waiting.
///
/// Inside the running dashboards it switches tab (multi-service shell) and
/// the module's drawer back to its home, then returns to the dashboard route
/// — never `Get.offAll`, which rebuilt every dashboard and dropped their
/// live listeners. Only when no dashboard is open (a cold start) is the
/// driver's dashboard opened the usual way.
abstract final class DispatchNavigation {
  static void openJob(DispatchKind kind) {
    final List<String> services = DriverServiceTypes.normalizeAll(Constant.userModel?.serviceTypes);
    final bool shell = services.length > 1 && Get.isRegistered<MultiServiceDashboardController>();
    if (shell) {
      final int index = services.indexOf(kind.serviceType);
      if (index >= 0) Get.find<MultiServiceDashboardController>().currentIndex.value = index;
    }
    if (shell || _dashboardOpen(kind)) {
      _homeTab(kind);
      Get.until((route) => route.isFirst);
      return;
    }
    final me = Constant.userModel;
    if (me != null) SignupController.navigateByUserModel(me);
  }

  /// The route on top of the app's navigator now — the screen or sheet a
  /// controller is acting from — or null when that is the incoming-order
  /// dialog. Captured BEFORE a network wait and closed afterwards with
  /// [closeRoute].
  static Route<dynamic>? ownRoute() {
    Route<dynamic>? top;
    // A predicate that holds at once pops nothing: it only reads the top.
    Get.key.currentState?.popUntil((route) {
      top = route;
      return true;
    });
    return IncomingOfferService.isDialogRoute(top) ? null : top;
  }

  /// Closes [route] (from [ownRoute]) wherever it is now. `Get.back()` pops
  /// whatever is on top, and the incoming-order dialog may have opened above
  /// the screen during its network wait: it was popped instead (PopScope
  /// does not stop a pop()) and the screen stayed. Never the first route.
  static void closeRoute(Route<dynamic>? route, {dynamic result}) {
    if (route == null || !route.isActive || route.isFirst) return;
    final NavigatorState? navigator = route.navigator;
    if (navigator == null) return;
    if (route.isCurrent) {
      navigator.pop(result);
    } else {
      navigator.removeRoute(route, result);
    }
  }

  static bool _dashboardOpen(DispatchKind kind) {
    switch (kind) {
      case DispatchKind.delivery:
        return Get.isRegistered<DashBoardController>();
      case DispatchKind.cab:
        return Get.isRegistered<CabDashBoardController>();
      case DispatchKind.parcel:
        return Get.isRegistered<ParcelDashboardController>();
      case DispatchKind.rental:
        return Get.isRegistered<RentalDashboardController>();
    }
  }

  static void _homeTab(DispatchKind kind) {
    switch (kind) {
      case DispatchKind.delivery:
        if (Get.isRegistered<DashBoardController>()) Get.find<DashBoardController>().drawerIndex.value = 0;
      case DispatchKind.cab:
        if (Get.isRegistered<CabDashBoardController>()) Get.find<CabDashBoardController>().drawerIndex.value = 0;
      case DispatchKind.parcel:
        if (Get.isRegistered<ParcelDashboardController>()) Get.find<ParcelDashboardController>().drawerIndex.value = 0;
      case DispatchKind.rental:
        if (Get.isRegistered<RentalDashboardController>()) Get.find<RentalDashboardController>().drawerIndex.value = 0;
    }
  }
}
