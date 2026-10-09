import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/online_status_rules.dart';
import 'package:driver/utils/document_verification.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

/// The signed-in driver's online status (`users/{uid}.isActive`), shared by
/// every service dashboard: online for one service is online for all, and
/// every switch and status dot shows the same value.
///
/// Client report (8 Oct): "the driver goes Offline automatically". Nothing
/// in the apps writes `isActive: false` except the driver's own switch, the
/// log-out (client rule 9 Oct: offline first, then sign out) and a brand-new
/// account, but each dashboard showed the value of its OWN copy
/// of the driver, which started empty ("Offline") and was filled only once
/// that dashboard's `users/{uid}` listener ran. That listener started only
/// after the location set-up, which on Android could wait for good (see
/// [DriverLocationRequests]), and a dashboard re-opened with `Get.offAll`
/// (a job push tapped, a service switched) lost its listener altogether. The
/// switch then said "Offline" for a driver the dispatch still saw online.
///
/// The value here comes from its own listener, starts from the copy read at
/// sign-in / app start (never from an empty model), and survives dashboards
/// being rebuilt. It changes only through [write] (the switch, log-out) or the live
/// record (another device, the panel).
abstract final class DriverOnlineStatus {
  static final Rxn<bool> _online = Rxn<bool>();
  static String? _uid;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  static int _ticket = 0;

  /// Online (true), offline (false) or not known yet (null). Read inside an
  /// `Obx` / `GetX` builder to rebuild with it.
  static bool? get value => _online.value;

  static bool get isKnown => _online.value != null;

  static bool get isOnline => _online.value == true;

  /// The shared value, or [fallback] (a dashboard's own copy) while it is
  /// not known.
  static bool isOnlineOr(bool? fallback) => _online.value ?? (fallback == true);

  /// Starts following `users/{uid}.isActive` for the signed-in driver (idempotent).
  /// Called by every dashboard when it starts.
  static void start() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    if (_uid != uid) {
      _sub?.cancel();
      _sub = null;
      _uid = uid;
      _online.value = OnlineStatusRules.initial(uid: uid, copyId: Constant.userModel?.id, copyIsActive: Constant.userModel?.isActive);
    } else {
      _online.value ??= OnlineStatusRules.initial(uid: uid, copyId: Constant.userModel?.id, copyIsActive: Constant.userModel?.isActive);
    }
    if (_sub != null) return;
    _sub = FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).snapshots().listen(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic>? data = snapshot.data();
        // A missing document is the account-deletion path's business
        // (DriverSessions.endDeletedAccount); the status is left as it was.
        if (_uid != uid || !snapshot.exists || data == null) return;
        _online.value = OnlineStatusRules.isOnline(data['isActive']);
      },
      onError: (Object e) {
        log("DriverOnlineStatus listener: $e");
        // The stream has ended: the next dashboard start listens again.
        _sub = null;
      },
    );
  }

  /// Stops listening (log-out, account deletion) and keeps the last value:
  /// [start] resumes it when the deletion did not go through.
  static Future<void> stop() async {
    final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  /// Forgets the driver (signed out).
  static Future<void> reset() async {
    await stop();
    _uid = null;
    _online.value = null;
  }

  /// The driver's switch: writes `isActive` alone (field-level `update`,
  /// never the whole user document, never re-creating a deleted one). Shown
  /// at once; put back when the write fails.
  static Future<UserWrite> write(bool online) async {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return UserWrite.failed;
    final int ticket = ++_ticket;
    final bool? previous = _online.value;
    final bool? previousCopy = Constant.userModel?.isActive;
    _online.value = online;
    if (Constant.userModel?.id == uid) Constant.userModel?.isActive = online;
    final UserWrite result = await FireStoreUtils.updateExistingUserFields(uid, {'isActive': online});
    // A newer tap since: its value stands.
    if (result != UserWrite.done && ticket == _ticket) {
      _online.value = previous;
      if (Constant.userModel?.id == uid) Constant.userModel?.isActive = previousCopy;
    }
    return result;
  }

  /// A tap on the switch of any dashboard. [me]: that dashboard's copy of
  /// the driver (the session copy is used while it is still empty).
  /// Going online checks the documents first (verification pending, an
  /// expired or rejected document); going offline is always allowed.
  /// [write] is the dashboard's `setOnline`.
  static Future<void> request(bool online, {UserModel? me, required Future<void> Function(bool online) write}) async {
    final UserModel? user = (me?.id ?? '').isNotEmpty ? me : Constant.userModel;
    final OnlineSwitchStep step = OnlineStatusRules.switchRequest(
      goingOnline: online,
      checksDocuments: DocumentVerification.checksDocuments(user),
      verificationPending: DocumentVerification.isPending(user),
    );
    switch (step) {
      case OnlineSwitchStep.verificationPending:
        ShowToastDialog.showToast("Document verification is pending. Please proceed to set up your document verification.".tr);
        return;
      case OnlineSwitchStep.checkDocuments:
        // Spec 3.6: expired / rejected documents block going online.
        final String? blockReason = await FireStoreUtils.documentBlockReason();
        if (blockReason != null) {
          ShowToastDialog.showToast(blockReason.tr);
          return;
        }
        break;
      case OnlineSwitchStep.write:
        break;
    }
    await write(online);
  }
}

/// The location plugin's permission and background-mode requests, one at a
/// time for the whole app ([SingleFlight]).
///
/// On Android the plugin keeps ONE pending result for these calls. The four
/// dashboards of a multi-service driver all asked at start-up (and again on
/// every "go online"); each call replaced the previous one's result, so only
/// the last completed and the others waited for ever, together with
/// everything their dashboard did after them.
abstract final class DriverLocationRequests {
  static final SingleFlight<PermissionStatus> _permission = SingleFlight<PermissionStatus>();
  static final SingleFlight<bool> _background = SingleFlight<bool>();

  /// Asks for the location permission (shared by every dashboard).
  static Future<PermissionStatus> requestPermission(Location location) => _permission.run(() => location.requestPermission());

  /// Turns on background mode (the location foreground service). Waits at
  /// most [limit]: the system dialog for "Allow all the time" can stay open,
  /// or never answer, and nothing may wait on it. Never throws.
  static Future<void> enableBackgroundMode(Location location, {Duration limit = const Duration(seconds: 20)}) async {
    await boundedOrDefault<bool>(_background.run(() => location.enableBackgroundMode(enable: true)), limit, false);
  }
}
