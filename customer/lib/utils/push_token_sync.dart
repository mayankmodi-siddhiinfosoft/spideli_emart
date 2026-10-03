import 'dart:async';
import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/utils/push_token.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Keeps `users/{uid}.fcmToken` pointing at this device.
///
/// Every write is field-level (`update({'fcmToken': ...})`), never a whole
/// user, and an empty token is never written. Called on app start, after
/// login / sign-up / OTP, and on `onTokenRefresh`; sign-out clears the field
/// only while it still holds this device's token.
abstract final class PushTokenSync {
  static StreamSubscription<String>? _refreshSubscription;

  static bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// This device's FCM token, or null when there is none yet.
  ///
  /// On iOS, waits (up to [apnsWait]) for the APNs token first: `getToken()`
  /// throws `apns-token-not-set` until it has arrived, which is why iPhones
  /// used to save '' and never receive anything.
  static Future<String?> deviceToken({Duration apnsWait = const Duration(seconds: 10)}) async {
    try {
      if (_isIOS) {
        final bool apnsReady = await PushToken.waitForApns(() => FirebaseMessaging.instance.getAPNSToken(), maxWait: apnsWait);
        if (!apnsReady) {
          log('push: no APNs token yet (push capability / APNs key / entitlement?), FCM token not requested');
          return PushToken.device;
        }
      }
      final String? token = await FirebaseMessaging.instance.getToken();
      if (PushToken.isUsable(token)) PushToken.device = token!.trim();
    } catch (e) {
      log('push: getToken failed (${e.runtimeType})');
    }
    return PushToken.device;
  }

  /// Saves this device's token on the signed-in customer's document and keeps
  /// listening for token refreshes. Safe to call repeatedly and without
  /// awaiting; it never throws.
  static Future<void> syncForCurrentUser() async {
    _listenForRefresh();
    if (FirebaseAuth.instance.currentUser == null) return;
    await _save(await deviceToken());
  }

  static void _listenForRefresh() {
    _refreshSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (String token) {
        if (PushToken.isUsable(token)) PushToken.device = token.trim();
        unawaited(_save(token));
      },
      onError: (Object e) => log('push: onTokenRefresh error (${e.runtimeType})'),
    );
  }

  static Future<void> _save(String? token) async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !PushToken.isUsable(token)) return;
    final String value = token!.trim();
    try {
      final ref = FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid);
      final snapshot = await ref.get();
      // No document yet (sign-up in progress): never create a stub user here.
      // Sign-up calls this again once it has written the document.
      if (!snapshot.exists) return;
      final String? write = PushToken.toWrite(deviceToken: value, storedToken: snapshot.data()?['fcmToken']?.toString());
      if (write != null) await ref.update({'fcmToken': write});
      final model = Constant.userModel;
      if (model != null && model.id == uid) model.fcmToken = value;
    } catch (e) {
      log('push: fcmToken save failed (${e.runtimeType})');
    }
  }

  /// Before signing out: clears `users/{uid}.fcmToken` if it is still this
  /// device's token, so the signed-out phone stops getting the customer's
  /// pushes without wiping the token of a phone they signed in on since.
  static Future<void> clearOnSignOut() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    final String? device = PushToken.device;
    if (uid == null || !PushToken.isUsable(device)) return;
    try {
      final ref = FireStoreUtils.fireStore.collection(CollectionName.users).doc(uid);
      await FireStoreUtils.fireStore
          .runTransaction((transaction) async {
            final snapshot = await transaction.get(ref);
            if (!snapshot.exists) return;
            if (PushToken.shouldClearOnSignOut(storedToken: snapshot.data()?['fcmToken']?.toString(), deviceToken: device)) {
              transaction.update(ref, {'fcmToken': ''});
            }
          })
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      log('push: fcmToken clear on sign-out skipped (${e.runtimeType})');
    }
  }
}
