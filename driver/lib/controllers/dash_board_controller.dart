import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/controllers/cab_dashboard_controller.dart';
import 'package:driver/controllers/parcel_dashboard_controller.dart';
import 'package:driver/controllers/rental_dashboard_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_assignment_watcher.dart';
import 'package:driver/services/driver_job_queue_service.dart';
import 'package:driver/services/driver_online_status.dart';
import 'package:driver/services/incoming_offer_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

import '../themes/theme_controller.dart';
import 'package:driver/utils/background_delivery.dart';

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
    await DriverOnlineStatus.stop();
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
  static bool _signingOut = false;

  /// Log out from any dashboard (individual, company, cab, parcel, rental).
  ///
  /// Client report (5 Oct 2026): "When we click on log out, nothing happens".
  /// The handlers awaited each clean-up step before signing out; on a phone
  /// where Google Play services is slow or offline, unsubscribing from the
  /// FCM topics never completed ("Topic operation failed: SERVICE_NOT_AVAILABLE.
  /// Will retry"), so the sign-out was never reached. Every step is now
  /// bounded and can fail on its own; signing out and opening the login
  /// screen always happen.
  static Future<void> signOutToLogin() async {
    if (_signingOut) return;
    _signingOut = true;
    ShowToastDialog.showLoader("Please wait".tr);
    Future<void> step(String name, Future<void> Function() run, Duration limit) async {
      try {
        await run().timeout(limit);
      } catch (e) {
        log("Logout: $name skipped: $e");
      }
    }

    try {
      await step('alert sound', () => AudioPlayerService.playSound(false), const Duration(seconds: 2));
      // Location streams and users listeners stop before the auth user goes
      // away (no tick with a null user, none left to double up after login).
      await step('dashboards', stopAll, const Duration(seconds: 4));
      // Client point 19: stop receiving this driver's work and clear the
      // stored token when it is this device's.
      await step('notifications', () => NotificationService.onSignOut(), const Duration(seconds: 8));
      // Log-out never changes the online status (`isActive`): only the
      // driver's switch does. A driver who logs out online is still online
      // on the next login; one who went offline stays offline.
      await DriverOnlineStatus.reset();
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        log("Logout: signOut failed: $e");
      }
    } finally {
      ShowToastDialog.closeLoader();
      _signingOut = false;
      Get.offAll(const LoginScreen());
    }
  }

  static Future<void> endDeletedAccount() async {
    await stopAll();
    await NotificationService.onSignOut(clearStoredToken: false);
    DriverAssignmentWatcher.stop();
    DriverJobQueueService.reset();
    IncomingOfferService.stop();
    await DriverOnlineStatus.reset();
    await FirebaseAuth.instance.signOut();
    Get.offAll(const LoginScreen());
    ShowToastDialog.showToast("This account no longer exists. Please contact the administrator.".tr);
  }
}

class DashBoardController extends GetxController {
  @override
  void onReady() {
    super.onReady();
    // Xiaomi & co.: explain Autostart once, or a closed app gets no push.
    BackgroundDelivery.maybePrompt();
  }

  RxInt drawerIndex = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit

    // No app-side dispatch trigger here (D1): the dispatch Cloud Functions
    // offer every order themselves. `updateDriverOrder()` rewrote each
    // waiting vendor order from this phone and reverted the ones the
    // function had just dispatched.
    getUser();
    getTheme();
    super.onInit();
  }

  Rx<UserModel> userModel = UserModel().obs;

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  /// Between [getUser] and [stopSession] / close.
  bool _live = false;

  Future<void> getUser() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _live = true;
    // The shared online status first, then this dashboard's listener, and
    // only then the location set-up, never awaited: it can wait on a system
    // permission dialog, and this listener (the driver's record, offers,
    // assignments, topics) used to start only after it.
    DriverOnlineStatus.start();
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
          // Offers dispatched to this driver: the incoming-order dialog (D3).
          IncomingOfferService.onDriverSnapshot(userModel.value);
          // Topics follow the live record (doc 21: zone / region / service changes).
          NotificationService.syncDriverTopics(userModel.value);
        }
      },
      onError: (Object e) => log("DashBoardController users listener: $e"),
    );
    unawaited(updateCurrentLocation());
  }

  /// Stops this dashboard's location stream and `users/{uid}` listener
  /// ([DriverSessions.stopAll]; also on close).
  Future<void> stopSession() async {
    _live = false;
    await _locationSub?.cancel();
    _locationSub = null;
    await _userSub?.cancel();
    _userSub = null;
  }

  @override
  void onClose() {
    _live = false;
    _locationSub?.cancel();
    _locationSub = null;
    _userSub?.cancel();
    _userSub = null;
    super.onClose();
  }

  /// Online / offline. Writes `isActive` and nothing else
  /// ([DriverOnlineStatus.write], shared by every service): the toggle wrote
  /// the whole user document from this controller's copy, which rolled back
  /// any assignment, offer or wallet change made since the last snapshot.
  Future<void> setOnline(bool value) async {
    if (FirebaseAuth.instance.currentUser?.uid == null) return;
    final bool? previous = userModel.value.isActive;
    userModel.value.isActive = value;
    userModel.refresh();
    if (value) updateCurrentLocation();
    final UserWrite result = await DriverOnlineStatus.write(value);
    if (result == UserWrite.done) return;
    userModel.value.isActive = previous;
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

  /// Starts this dashboard's location stream. Never awaited by anything
  /// that matters: a permission dialog may stay open (or never answer).
  Future<void> updateCurrentLocation() async {
    try {
      PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus != PermissionStatus.granted) {
        // One request for the whole app (DriverLocationRequests).
        permissionStatus = await DriverLocationRequests.requestPermission(location);
        ShowToastDialog.closeLoader();
      }
      // Signed out / closed meanwhile: no stream outlives the session.
      if (permissionStatus != PermissionStatus.granted || !_live) return;
      location.changeSettings(accuracy: LocationAccuracy.high, distanceFilter: double.parse(Constant.driverLocationUpdate));
      // One listener, however many times the driver goes online.
      await _locationSub?.cancel();
      _locationSub = location.onLocationChanged.listen(_writeLocation);
      // Background mode once the stream runs, bounded and shared: the
      // "Allow all the time" dialog must not hold anything up.
      await DriverLocationRequests.enableBackgroundMode(location);
    } catch (e) {
      log("DashBoardController location: $e");
    }
  }
}
