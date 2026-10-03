import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/cab_dashboard_controller.dart';
import 'package:driver/controllers/parcel_dashboard_controller.dart';
import 'package:driver/controllers/rental_dashboard_controller.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/driver_job_queue_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

import '../themes/theme_controller.dart';

/// The location stream and `users/{uid}` listener of every dashboard alive
/// (the multi-service shell keeps all four in one IndexedStack). Logout and
/// account deletion stop them all BEFORE the auth user goes away: a tick that
/// ran afterwards threw on the null user, a tick after the account deletion
/// re-created `users/{uid}` as a stub, and a stream that outlived its
/// controller doubled every write after the next login.
class DriverSessions {
  DriverSessions._();

  static Future<void> stopAll() async {
    if (Get.isRegistered<DashBoardController>()) await Get.find<DashBoardController>().stopSession();
    if (Get.isRegistered<CabDashBoardController>()) await Get.find<CabDashBoardController>().stopSession();
    if (Get.isRegistered<ParcelDashboardController>()) await Get.find<ParcelDashboardController>().stopSession();
    if (Get.isRegistered<RentalDashboardController>()) await Get.find<RentalDashboardController>().stopSession();
    try {
      await Location().enableBackgroundMode(enable: false);
    } catch (_) {}
  }

  /// Undoes [stopAll] when the account deletion did not go through.
  static void resumeAll() {
    if (Get.isRegistered<DashBoardController>()) Get.find<DashBoardController>().getUser();
    if (Get.isRegistered<CabDashBoardController>()) Get.find<CabDashBoardController>().getUser();
    if (Get.isRegistered<ParcelDashboardController>()) Get.find<ParcelDashboardController>().getUser();
    if (Get.isRegistered<RentalDashboardController>()) Get.find<RentalDashboardController>().getUser();
  }

  /// `users/{uid}` is gone while the driver is still signed in (the account
  /// deletion removed it but could not delete the auth user, or an admin
  /// deleted it). Ends the session WITHOUT writing to `users/{uid}`: any write
  /// there would re-create it as a stub that locks the number out of login
  /// and sign-up. NotificationService.onSignOut runs without its token write
  /// (a merge set): it used to be skipped altogether, which left the device
  /// subscribed to the deleted driver's FCM topics (job pushes kept coming).
  static Future<void> endDeletedAccount() async {
    await stopAll();
    await NotificationService.onSignOut(clearStoredToken: false);
    DriverAssignmentWatcher.stop();
    DriverJobQueueService.reset();
    await FirebaseAuth.instance.signOut();
    Get.offAll(const LoginScreen());
    ShowToastDialog.showToast("This account no longer exists. Please contact the administrator.".tr);
  }
}

class DashBoardController extends GetxController {
  RxInt drawerIndex = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit

    getUser();
    updateDriverOrder();
    getTheme();
    super.onInit();
  }

  Rx<UserModel> userModel = UserModel().obs;

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  Future<void> getUser() async {
    await updateCurrentLocation();
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _userSub?.cancel();
    _userSub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).snapshots().listen(
      (event) {
        if (event.exists) {
          userModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = UserModel.fromJson(event.data()!);
          RegionService.applyDriver(Constant.userModel);
          // Automatic driver-notification queue (admin spec §14): re-offer the
          // orders placed while this driver was away, once per going-online.
          DriverJobQueueService.onDriverSnapshot(userModel.value);
          // Jobs ASSIGNED to this driver, picked up from the records alone (panel
          // report 01 §4: a hand assignment may now come without any push).
          DriverAssignmentWatcher.onDriverSnapshot(userModel.value);
        }
      },
      onError: (Object e) => log("DashBoardController users listener: $e"),
    );
  }

  /// Stops this dashboard's location stream and `users/{uid}` listener
  /// ([DriverSessions.stopAll]; also on close).
  Future<void> stopSession() async {
    await _locationSub?.cancel();
    _locationSub = null;
    await _userSub?.cancel();
    _userSub = null;
  }

  @override
  void onClose() {
    _locationSub?.cancel();
    _locationSub = null;
    _userSub?.cancel();
    _userSub = null;
    super.onClose();
  }

  /// Online / offline. Writes `isActive` and nothing else: the toggle wrote
  /// the whole user document from this controller's copy, which rolled back
  /// any assignment, offer or wallet change made since the last snapshot.
  Future<void> setOnline(bool value) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final bool? previous = userModel.value.isActive;
    userModel.value.isActive = value;
    Constant.userModel?.isActive = value;
    userModel.refresh();
    if (value) updateCurrentLocation();
    // `update`, never a merge set: a toggle after the account was deleted
    // must not re-create users/{uid} as an {isActive} stub.
    final UserWrite result = await FireStoreUtils.updateExistingUserFields(uid, {'isActive': value});
    if (result == UserWrite.done) return;
    userModel.value.isActive = previous;
    Constant.userModel?.isActive = previous;
    userModel.refresh();
    if (result == UserWrite.missing) {
      await DriverSessions.endDeletedAccount();
      return;
    }
    ShowToastDialog.showToast("Something went wrong. Please try again.".tr);
  }

  RxString isDarkMode = "Light".obs;
  RxBool isDarkModeSwitch = false.obs;

  void getTheme() {
    bool isDark = Preferences.getBoolean(Preferences.themKey);
    isDarkMode.value = isDark ? "Dark" : "Light";
    isDarkModeSwitch.value = isDark;
  }

  void toggleDarkMode(bool value) {
    isDarkModeSwitch.value = value;
    isDarkMode.value = value ? "Dark" : "Light";
    Preferences.setBoolean(Preferences.themKey, value);
    // Update ThemeController for instant app theme change
    if (Get.isRegistered<ThemeController>()) {
      final themeController = Get.find<ThemeController>();
      themeController.isDark.value = value;
    }
  }

  Future<void> updateDriverOrder() async {
    Timestamp startTimestamp = Timestamp.now();
    DateTime currentDate = startTimestamp.toDate();
    currentDate = currentDate.subtract(const Duration(hours: 3));
    startTimestamp = Timestamp.fromDate(currentDate);

    List<OrderModel> orders = [];

    await FireStoreUtils.fireStore
        .collection(CollectionName.vendorOrders)
        .where('status', whereIn: [Constant.orderAccepted, Constant.orderRejected])
        .where('createdAt', isGreaterThan: startTimestamp)
        .get()
        .then((value) async {
          await Future.forEach(value.docs, (QueryDocumentSnapshot<Map<String, dynamic>> element) {
            try {
              orders.add(OrderModel.fromJson(element.data()));
            } catch (e, s) {
              print('watchOrdersStatus parse error ${element.id}$e $s');
            }
          });
        });

    orders.forEach((element) async {
      OrderModel orderModel = element;
      orderModel.triggerDelivery = Timestamp.now();
      await FireStoreUtils.setOrder(orderModel);
    });
  }

  Location location = Location();
  StreamSubscription<LocationData>? _locationSub;

  /// One location tick. Always written, regardless of isActive, so the
  /// home / cab maps stay centred; only `location` / `rotation`
  /// ([FireStoreUtils.updateUserLocation]), and nothing once signed out
  /// (`getCurrentUid()` threw on the null user).
  Future<void> _writeLocation(LocationData locationData) async {
    Constant.locationDataFinal = locationData;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FireStoreUtils.updateUserLocation(uid, latitude: locationData.latitude, longitude: locationData.longitude, heading: locationData.heading);
  }

  Future<void> updateCurrentLocation() async {
    try {
      PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus == PermissionStatus.granted) {
        try {
          await location.enableBackgroundMode(enable: true);
        } catch (_) {}
        location.changeSettings(accuracy: LocationAccuracy.high, distanceFilter: double.parse(Constant.driverLocationUpdate));

        // One listener, however many times the driver goes online.
        _locationSub?.cancel();
        _locationSub = location.onLocationChanged.listen(_writeLocation);
      } else {
        location.requestPermission().then((permissionStatus) async {
          if (permissionStatus == PermissionStatus.granted) {
            try {
              await location.enableBackgroundMode(enable: true);
            } catch (_) {}
            location.changeSettings(accuracy: LocationAccuracy.high, distanceFilter: double.parse(Constant.driverLocationUpdate));
            _locationSub?.cancel();
            _locationSub = location.onLocationChanged.listen((locationData) async {
              await _writeLocation(locationData);
              ShowToastDialog.closeLoader();
            });
          } else {
            ShowToastDialog.closeLoader();
          }
        });
      }
    } catch (e) {
      print(e);
    }
  }
}
