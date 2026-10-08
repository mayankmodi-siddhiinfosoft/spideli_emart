import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/dashboard_navigation.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/login_validation.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// What happened when a signed-in user's driver account was opened.
enum AccountOutcome {
  /// The dashboard was opened.
  opened,

  /// There is no users/{uid} document yet (the caller decides: sign-up or an
  /// error). The user is still signed in.
  missing,

  /// The account belongs to another app (signed out again).
  notDriver,

  /// The driver is not approved / disabled (signed out again).
  inactive,

  /// The profile could not be loaded (signed out again).
  failed,
}

class AccountResult {
  final AccountOutcome outcome;

  /// The message to show for [outcome] (a translation key), or null.
  final String? message;

  const AccountResult(this.outcome, [this.message]);
}

/// The one way every sign-in path (email, Google, Apple, phone) turns a
/// Firebase Auth user into an open driver dashboard.
///
/// Driver report (3 Oct): signing in with email and password could spin for
/// ever. Login caught only FirebaseAuthException, so anything else after
/// sign-in — a driver document with an unexpected value, an empty service
/// list (`serviceTypes.first`), a slow write — escaped with the loader still
/// up; an approved driver was not taken anywhere when auto-approve was off;
/// and every error toast was dismissed by the loader closing after it.
class DriverSignIn {
  DriverSignIn._();

  /// Loads the driver profile of [uid] and opens the right dashboard. Never
  /// throws. Every outcome except [AccountOutcome.opened] and
  /// [AccountOutcome.missing] signs out again.
  static Future<AccountResult> open(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid).get();
      } catch (e) {
        log("Driver profile could not be loaded: $e");
        await signOutQuietly();
        return const AccountResult(AccountOutcome.failed, "Could not load your profile. Please check your internet connection and try again.");
      }
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) return const AccountResult(AccountOutcome.missing);

      final UserModel userModel = UserModel.fromJson(data);
      // The signed-in uid, never a missing or different `id` stored in the
      // document: updateUser writes to users/<id>.
      userModel.id = uid;
      if (userModel.role != Constant.userRoleDriver) {
        await signOutQuietly();
        return const AccountResult(AccountOutcome.notDriver, "This user is not created in driver application.");
      }
      // `active` is the approval itself: sign-up sets it from the auto-approve
      // setting and the admin turns it on. Email login used to also require
      // auto-approve to be on, so an approved driver went nowhere when it was
      // off.
      if (userModel.active != true) {
        await signOutQuietly();
        return const AccountResult(AccountOutcome.inactive, "This user is disable please contact to administrator");
      }
      // The session user before the write: updateUser sets it only once the
      // server confirms, and the Cab / Parcel / Rental / Owner dashboards read
      // Constant.userModel! on their first frame (offline or slow start).
      Constant.userModel = userModel;
      // Normalises legacy fields, as before; bounded so a slow write cannot
      // hold the loader up.
      await FireStoreUtils.updateUser(userModel).timeout(const Duration(seconds: 8), onTimeout: () => false);
      // Client point 19: the token (field-level) and the topics, on every
      // sign-in. Not awaited: on iOS it may wait for the APNs token.
      unawaited(NotificationService.syncSignedInDevice(userModel));
      openDashboard(userModel);
      return const AccountResult(AccountOutcome.opened);
    } catch (e) {
      log("Opening the driver account failed: $e");
      await signOutQuietly();
      return const AccountResult(AccountOutcome.failed, "Something went wrong. Please try again.");
    }
  }

  /// The dashboard for this driver. An empty service list (a driver created
  /// without one) used to throw on `.first`; it now opens the delivery
  /// dashboard, like a missing list always did.
  static void openDashboard(UserModel userModel) {
    unawaited(DashboardNavigation.open(userModel));
  }

  static Future<void> signOutQuietly() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// A message (translation key) for a Firebase Auth sign-in error. A wrong
  /// email, a wrong password or both all give "Invalid email or password.",
  /// so the app never says which one was wrong.
  static String authErrorMessage(FirebaseAuthException e) => LoginValidation.authErrorMessage(e.code);
}
