import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:spideliworker/constant/constants.dart';
import 'package:spideliworker/model/notification_model.dart';
import 'package:spideliworker/model/user.dart';
import 'package:spideliworker/services/customer_notification.dart';
import 'package:spideliworker/services/firebase_helper.dart';
import 'package:spideliworker/services/push_message.dart';

/// Every push the worker app sends: job status to the customer
/// ([sendFcmMessage]) and chat messages ([sendChatFcmMessage]).
///
/// Two paths, one message (see push_message.dart and
/// `.claude/SERVER-PUSH-CONTRACT.md`):
/// - `serverPushUrl` is an https URL: POST to the `sendPush` function with the
///   worker's Firebase ID token. The service-account key is never downloaded.
/// - otherwise (legacy): FCM HTTP v1 with an OAuth token minted from
///   `serviceJson`, cached until shortly before it expires.
///
/// Both return true only when the push was accepted, and log the HTTP status
/// and FCM error code on failure -- never a token, an access token or the
/// message text.
///
/// A push to a customer whose id is given (`customerId`) is also recorded in
/// the customer's Notification Center (`users/{customerId}/notifications/{id}`,
/// `.claude/CUSTOMER-NOTIFICATIONS.md` 1) and its data carries
/// `notificationId` -- see [_recordForCustomer].
class SendNotification {
  SendNotification._();

  static final List<String> _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  static bool get useServerPush => isHttpsUrl(serverPushUrl);

  static String? _accessToken;
  static DateTime? _accessTokenExpiry;
  static Future<String>? _accessTokenInFlight;

  static Future<http.Response> getCharacters() {
    if (useServerPush) {
      throw StateError('Server push is on: the service-account key is not downloaded.');
    }
    return http.get(Uri.parse(jsonNotificationFileURL.toString())).timeout(const Duration(seconds: 20));
  }

  /// The OAuth access token for FCM (legacy path only). It is a live
  /// credential: never log it.
  static Future<String> getAccessToken() {
    if (useServerPush) {
      throw StateError('Server push is on: no access token is minted on the device.');
    }
    if (_accessToken != null && accessTokenUsable(_accessTokenExpiry, DateTime.now())) {
      return Future<String>.value(_accessToken);
    }
    return _accessTokenInFlight ??= _mintAccessToken().whenComplete(() => _accessTokenInFlight = null);
  }

  static Future<String> _mintAccessToken() async {
    final http.Response response = await getCharacters();
    if (response.statusCode != 200) {
      throw StateError('Service account file not available (HTTP ${response.statusCode}).');
    }
    final ServiceAccountCredentials credentials = ServiceAccountCredentials.fromJson(json.decode(response.body));
    final AutoRefreshingAuthClient client = await clientViaServiceAccount(credentials, _scopes);
    try {
      final AccessToken token = client.credentials.accessToken;
      _accessToken = token.data;
      _accessTokenExpiry = token.expiry;
      return token.data;
    } finally {
      client.close();
    }
  }

  static void _forgetAccessToken() {
    _accessToken = null;
    _accessTokenExpiry = null;
  }

  /// The recipient's current FCM token: `users/{uid}.fcmToken`, else
  /// [fallback] (the copy embedded in the order when it was placed, which goes
  /// stale when the customer's token rotates or was empty on iOS) - but only
  /// when the profile could not be read or does not exist; an existing profile
  /// with no token means signed out, so nothing is sent ([pickRecipientToken]).
  static Future<String> tokenForUser(String? uid, {String? fallback}) async {
    String? fresh;
    final String id = uid?.trim() ?? '';
    if (id.isNotEmpty) {
      try {
        final User? user = await FireStoreUtils.getUser(id);
        fresh = user?.fcmToken;
      } catch (e) {
        debugPrint('push: recipient profile not read: $e');
      }
    }
    return pickRecipientToken(fresh: fresh, snapshot: fallback);
  }

  /// A job-status push from the `dynamic_notification` template [type].
  /// [customerId]: the recipient customer, for the Notification Center record.
  static Future<bool> sendFcmMessage(String type, String token, Map<String, dynamic>? payload, {PushRecipient recipient = PushRecipient.customer, String? customerId}) async {
    // A known customer without a usable token still gets the Notification
    // Center record (no push); anyone else: nothing to do.
    final bool customerKnown = recipient == PushRecipient.customer && (customerId ?? '').trim().isNotEmpty;
    if (!isUsableFcmToken(token) && !customerKnown) {
      debugPrint('push "$type" skipped: the recipient has no FCM token');
      return false;
    }
    try {
      final NotificationModel? template = await FireStoreUtils.getNotificationContent(type);
      final String title = template?.subject ?? '';
      final String body = template?.message ?? '';
      final Map<String, String> data = _recordForCustomer(
        recipient: recipient,
        customerId: customerId,
        title: title,
        body: body,
        data: fcmDataPayload(payload, fallbackType: type),
        kind: type,
      );
      if (!isUsableFcmToken(token)) {
        debugPrint('push "$type" skipped: the recipient has no FCM token (recorded only)');
        return false;
      }
      return await _send(token: token, title: title, body: body, data: data, kind: type, recipient: recipient);
    } catch (e) {
      debugPrint('push "$type" not sent: $e');
      return false;
    }
  }

  /// A chat message push. [customerId]: the recipient customer, for the
  /// Notification Center record (also written when the customer has no usable
  /// token; a `notificationId` already in [payload] is reused). [record]
  /// false: a retry of a push already recorded - the record is not written
  /// again (a second `set` would reset its `read` and `createdAt`).
  static Future<bool> sendChatFcmMessage(String title, String message, String token, Map<String, dynamic>? payload, {PushRecipient recipient = PushRecipient.customer, String? customerId, bool record = true}) async {
    final bool customerKnown = record && recipient == PushRecipient.customer && (customerId ?? '').trim().isNotEmpty;
    if (!isUsableFcmToken(token) && !customerKnown) {
      debugPrint('chat push skipped: the recipient has no FCM token');
      return false;
    }
    try {
      final Map<String, String> payloadData = fcmDataPayload(payload, fallbackType: 'orderChat');
      final Map<String, String> data = record
          ? _recordForCustomer(
              recipient: recipient,
              customerId: customerId,
              title: title,
              body: message,
              data: payloadData,
              kind: chatPushKind,
            )
          : payloadData;
      if (!isUsableFcmToken(token)) {
        debugPrint('chat push skipped: the recipient has no FCM token (recorded only)');
        return false;
      }
      return await _send(token: token, title: title, body: message, data: data, kind: chatPushKind, recipient: recipient);
    } catch (e) {
      debugPrint('chat push not sent: $e');
      return false;
    }
  }

  /// Records a push to a customer in their Notification Center
  /// (`users/{customerId}/notifications/{id}`: the push's title, body, type,
  /// category, order, status and data, `read` false, `source` worker) and
  /// returns [data] with `notificationId` added, so the customer app knows it
  /// is stored. Best effort: the write is not awaited (Firestore queues it
  /// offline) and a failure is only logged; the push goes out either way.
  /// Anything else (another recipient, no customer id, an empty push) is
  /// returned unchanged.
  static Map<String, String> _recordForCustomer({
    required PushRecipient recipient,
    required String? customerId,
    required String title,
    required String body,
    required Map<String, String> data,
    required String kind,
  }) {
    if (!shouldRecordCustomerNotification(recipient: recipient, customerId: customerId, title: title, body: body)) return data;
    try {
      final String id = existingNotificationId(data) ?? FireStoreUtils.newCustomerNotificationId(customerId!);
      final Map<String, String> sent = withNotificationId(data, id);
      final Map<String, dynamic> record = customerNotificationRecord(id: id, title: title, body: body, kind: kind, data: sent);
      unawaited(
        FireStoreUtils.recordCustomerNotification(customerId!, id, record).catchError((Object e) {
          debugPrint('push "$kind": customer notification not recorded: $e');
        }),
      );
      return sent;
    } catch (e) {
      debugPrint('push "$kind": customer notification not recorded: $e');
      return data;
    }
  }

  static Future<bool> _send({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required String kind,
    required PushRecipient recipient,
  }) {
    final PushChannel channel = pushChannelFor(recipient);
    if (useServerPush) {
      return _sendViaServer(buildServerPushBody(token: token, title: title, body: body, data: data, channel: channel, kind: kind), kind);
    }
    return _sendLegacy(buildFcmV1Message(token: token, title: title, body: body, data: data, channel: channel), kind);
  }

  static Future<bool> _sendLegacy(Map<String, dynamic> message, String kind) async {
    String projectId = '';
    try {
      projectId = Firebase.app().options.projectId;
    } catch (_) {
      // No default app (should not happen once main() ran): use settings.
    }
    projectId = fcmProjectId(optionsProjectId: projectId, settingsSenderId: senderId);
    if (projectId.isEmpty) {
      debugPrint('push "$kind" not sent: no Firebase project id');
      return false;
    }
    final Uri url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');
    final String requestBody = jsonEncode(message);

    Future<http.Response> post() async {
      final String accessToken = await getAccessToken();
      return http
          .post(url, headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'}, body: requestBody)
          .timeout(const Duration(seconds: 20));
    }

    http.Response response = await post();
    if (response.statusCode == 401) {
      // The cached access token was revoked or expired early: mint once more.
      _forgetAccessToken();
      response = await post();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return true;
    final PushSendError error = parseFcmError(response.statusCode, response.body);
    // A dead customer token is not cleared from here: the worker must not
    // write other users' profiles, and the customer app saves its fresh token
    // on its next start.
    debugPrint('push "$kind" rejected by FCM: $error');
    return false;
  }

  static Future<bool> _sendViaServer(Map<String, dynamic> body, String kind) async {
    final auth.User? user = auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('push "$kind" not sent: no signed-in worker for the server push');
      return false;
    }
    final String requestBody = jsonEncode(body);

    Future<http.Response> post(bool refreshIdToken) async {
      final String? idToken = await user.getIdToken(refreshIdToken);
      return http
          .post(
            Uri.parse(serverPushUrl.trim()),
            headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer ${idToken ?? ''}'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));
    }

    try {
      http.Response response = await post(false);
      if (response.statusCode == 401) response = await post(true);
      if (response.statusCode == 200) return true;
      debugPrint('push "$kind" rejected by sendPush: ${parseServerPushError(response.statusCode, response.body)}');
      return false;
    } catch (e) {
      debugPrint('push "$kind" server call failed: $e');
      return false;
    }
  }
}
