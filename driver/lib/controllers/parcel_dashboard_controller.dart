import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/driver_job_queue_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

import '../constant/constant.dart' show Constant;
import '../themes/theme_controller.dart';
import 'package:driver/utils/background_delivery.dart';

class ParcelDashboardController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    // Xiaomi & co.: explain Autostart once, or a closed app gets no push.
    BackgroundDelivery.maybePrompt();
  }

  RxInt drawerIndex = 0.obs;

  @override
  void onInit() {
    getUser();
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
          (event) async {
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
          // Preload all registered sections into cache
          for (final sid in userModel.value.sectionIds ?? <String>[]) {
            if (!Constant.sectionModels.containsKey(sid)) {
              FireStoreUtils.getSectionBySectionId(sid).then((sectionValue) {
                if (sectionValue != null) Constant.sectionModels[sid] = sectionValue;
              });
            }
          }
        }
      },
      onError: (Object e) => log("ParcelDashboardController users listener: $e"),
    );
  }

  /// Stops this dashboard's location stream and `users/{uid}` listener
  /// (`DriverSessions.stopAll`; also on close).
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

  Location location = Location();
  StreamSubscription<LocationData>? _locationSub;

  /// One location tick while online: only `location` / `rotation`
  /// ([FireStoreUtils.updateUserLocation]), and nothing once signed out
  /// (`getCurrentUid()` threw on the null user).
  Future<void> _writeLocation(LocationData locationData) async {
    Constant.locationDataFinal = locationData;
    if (userModel.value.isActive != true) return;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FireStoreUtils.updateUserLocation(uid, latitude: locationData.latitude, longitude: locationData.longitude, heading: locationData.heading);
  }

  Future<void> updateCurrentLocation() async {
    try {
      PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus == PermissionStatus.granted) {
        try { await location.enableBackgroundMode(enable: true); } catch (_) {}
        location.changeSettings(accuracy: LocationAccuracy.high, distanceFilter: double.parse(Constant.driverLocationUpdate));

        // One listener, however many times the driver goes online; only
        // `location` / `rotation` are written (FireStoreUtils.updateUserLocation).
        _locationSub?.cancel();
        _locationSub = location.onLocationChanged.listen(_writeLocation);
      } else {
        location.requestPermission().then((permissionStatus) async {
          if (permissionStatus == PermissionStatus.granted) {
            try { await location.enableBackgroundMode(enable: true); } catch (_) {}
            location.changeSettings(accuracy: LocationAccuracy.high, distanceFilter: double.parse(Constant.driverLocationUpdate));
            // One listener, however many times the driver goes online; only
            // `location` / `rotation` are written (FireStoreUtils.updateUserLocation).
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
