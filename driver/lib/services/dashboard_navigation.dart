import 'dart:async';

import 'package:driver/app/cab_screen/cab_dashboard_screen.dart';
import 'package:driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:driver/app/multi_service/multi_service_dashboard_screen.dart';
import 'package:driver/app/owner_screen/owner_dashboard_screen.dart';
import 'package:driver/app/parcel_screen/parcel_dashboard_screen.dart';
import 'package:driver/app/rental_service/rental_dashboard_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/cab_dashboard_controller.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/owner_dashboard_controller.dart';
import 'package:driver/controllers/parcel_dashboard_controller.dart';
import 'package:driver/controllers/rental_dashboard_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/online_status_rules.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Every way into a driver's dashboards: sign-in / app start, sign-up, a
/// section (service) change, a job push or chat push tapped, a password
/// reset.
///
/// They all used `Get.offAll(<dashboard>)`, also while the dashboards were
/// already running. The new screens then adopted the running controllers
/// (GetX finds a registered one instead of creating it) and the screens
/// being removed deleted them right after: the dashboards' `users/{uid}`
/// listeners and location streams stopped, and each drawer opened on a new
/// empty controller whose switch said "Offline" (reported as the driver
/// going offline after switching service, or after tapping a push while
/// the app was in the background). Now:
/// - nothing running: opened as before;
/// - the same dashboards running: the driver is taken back to them;
/// - different dashboards (another service set): the running ones are
///   closed completely before the new ones open, so they start fresh.
abstract final class DashboardNavigation {
  static String? _openLayout;
  static bool _rebuilding = false;

  /// A service dashboard (or the company one, or the multi-service shell) is alive.
  static bool get running =>
      Get.isRegistered<DashBoardController>() ||
      Get.isRegistered<CabDashBoardController>() ||
      Get.isRegistered<ParcelDashboardController>() ||
      Get.isRegistered<RentalDashboardController>() ||
      Get.isRegistered<OwnerDashboardController>() ||
      Get.isRegistered<MultiServiceDashboardController>();

  static String layoutOf(UserModel user) => OnlineStatusRules.dashboardLayout(isOwner: user.isOwner == true, modules: user.serviceModules);

  /// The dashboard screen of [user]. An empty service list (a driver created
  /// without one) opens the delivery dashboard.
  static Widget pageFor(UserModel user) {
    if (user.isOwner == true) return OwnerDashboardScreen();
    if (user.serviceModules.length > 1) return const MultiServiceDashboardScreen();
    // Read through the spec's aliases (`parcel-service` is the parcel module).
    switch (user.serviceModules.firstOrNull) {
      case 'cab-service':
        return const CabDashboardScreen();
      case 'parcel_delivery':
        return const ParcelDashboardScreen();
      case 'rental-service':
        return const RentalDashboardScreen();
      default:
        return const DashBoardScreen();
    }
  }

  /// Shows [user]'s dashboards. [rebuild]: start them fresh even when the
  /// same ones are running (a section change).
  static Future<void> open(UserModel user, {bool rebuild = false}) async {
    final String layout = layoutOf(user);
    switch (OnlineStatusRules.dashboardRoute(running: running, openLayout: _openLayout, wanted: layout, rebuild: rebuild)) {
      case DashboardRoute.open:
        _openLayout = layout;
        Get.offAll(pageFor(user));
        break;
      case DashboardRoute.reuse:
        _toHome();
        break;
      case DashboardRoute.rebuild:
        await _replace(() => pageFor(user), layout);
        break;
    }
  }

  /// Back to the home page of the running dashboards (a password reset sent).
  static Future<void> home() async {
    final UserModel? me = Constant.userModel;
    if (me != null) return open(me);
    if (running) _toHome();
  }

  /// The delivery dashboard on drawer page [drawerIndex] (admin / order
  /// chat pushes). Returns once that dashboard is on screen.
  static Future<void> openDeliveryPage(int drawerIndex) async {
    if (!Get.isRegistered<DashBoardController>()) {
      // Not running (a cold start, or a driver without the delivery
      // service): opened the way these pushes always opened it.
      if (running) {
        await _replace(() => const DashBoardScreen(), 'delivery-service');
      } else {
        _openLayout = 'delivery-service';
        Get.offAll(const DashBoardScreen());
      }
      await _waitFor(() => Get.isRegistered<DashBoardController>());
    } else {
      _selectTab('delivery-service');
      Get.until((route) => route.isFirst);
    }
    if (Get.isRegistered<DashBoardController>()) Get.find<DashBoardController>().drawerIndex.value = drawerIndex;
  }

  static void _toHome() {
    if (Get.isRegistered<DashBoardController>()) Get.find<DashBoardController>().drawerIndex.value = 0;
    if (Get.isRegistered<CabDashBoardController>()) Get.find<CabDashBoardController>().drawerIndex.value = 0;
    if (Get.isRegistered<ParcelDashboardController>()) Get.find<ParcelDashboardController>().drawerIndex.value = 0;
    if (Get.isRegistered<RentalDashboardController>()) Get.find<RentalDashboardController>().drawerIndex.value = 0;
    if (Get.isRegistered<OwnerDashboardController>()) Get.find<OwnerDashboardController>().drawerIndex.value = 0;
    Get.until((route) => route.isFirst);
  }

  static void _selectTab(String module) {
    if (!Get.isRegistered<MultiServiceDashboardController>()) return;
    final int index = (Constant.userModel?.serviceModules ?? const <String>[]).indexOf(module);
    if (index >= 0) Get.find<MultiServiceDashboardController>().currentIndex.value = index;
  }

  /// Closes the running dashboards completely (their screens, controllers,
  /// listeners and location streams) and then opens [page].
  static Future<void> _replace(Widget Function() page, String layout) async {
    if (_rebuilding) return;
    _rebuilding = true;
    try {
      _openLayout = null;
      Get.offAll(() => const _DashboardSwitchScreen());
      await _waitFor(() => !running);
      // The removed routes are disposed once their screens are gone (GetX
      // deletes what they registered then): two more frames.
      await _frame();
      await _frame();
      _openLayout = layout;
      Get.offAll(page());
    } finally {
      _rebuilding = false;
    }
  }

  /// Waits frame by frame (at most [limit]) until [done].
  static Future<void> _waitFor(bool Function() done, {Duration limit = const Duration(seconds: 3)}) async {
    final Stopwatch watch = Stopwatch()..start();
    while (!done() && watch.elapsed < limit) {
      await _frame();
    }
  }

  /// The end of the next frame; bounded, as no frame comes while the app is
  /// in the background.
  static Future<void> _frame() => boundedOrDefault<void>(WidgetsBinding.instance.endOfFrame, const Duration(milliseconds: 250), null);
}

/// Shown for the few frames between closing the old dashboards and opening
/// the new ones.
class _DashboardSwitchScreen extends StatelessWidget {
  const _DashboardSwitchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dsColors.background,
      body: const Center(child: DsSpinner(size: 32)),
    );
  }
}
