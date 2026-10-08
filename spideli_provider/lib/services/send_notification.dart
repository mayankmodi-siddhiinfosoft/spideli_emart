import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:spideliprovider/model/notification_model.dart';
import 'package:spideliprovider/services/customer_notification.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/push_message.dart';

import '../constant/constants.dart';

/// Every push this app sends: booking status to the customer, assignments to
/// the worker, chat messages.
///
/// Two paths, chosen by `settings/notification_setting.serverPushUrl`
/// (.claude/SERVER-PUSH-CONTRACT.md):
/// * an https URL: the `sendPush` function, authenticated with the provider's
///   Firebase ID token. The service-account file is never downloaded.
/// * otherwise the legacy path: FCM HTTP v1 with an OAuth token minted from the
///   service-account file, cached until shortly before it expires.
///
/// Both send the same message: string-only data with a `type`, the receiving
/// app's Android channel at high priority, and an APNs sound. A send returns
/// true only when FCM (or the function) accepted it; failures are logged with
/// the status and error code, never with a token or credential.
///
/// Every push to a customer whose uid is known is also stored at
/// `users/{customerId}/notifications/{id}` for the customer's Notification
/// Center, and its data then carries `notificationId`
/// (.claude/CUSTOMER-NOTIFICATIONS.md; best effort, never blocks the push).
class SendNotification {
  static const List<String> _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  static const Duration _httpTimeout = Duration(seconds: 20);

  static String? _accessToken;
  static DateTime? _accessTokenExpiry;
  static Future<String>? _minting;
  static String? _serviceAccountProjectId;
  static Future<void>? _settingsLoad;

  static bool get useServerPush => isUsableServerPushUrl(serverPushUrl);

  static String _setting(Map<String, dynamic> data, String key) {
    final String value = (data[key] ?? '').toString().trim();
    return value.toLowerCase() == 'null' ? '' : value;
  }

  /// Reads `settings/notification_setting` into [senderId],
  /// [jsonNotificationFileURL] and [serverPushUrl]. Never logs the document:
  /// `serviceJson` is a tokenised download URL of a service-account key.
  static Future<void> loadNotificationSettings() async {
    try {
      final snapshot = await FireStoreUtils.firestore.collection(Setting).doc('notification_setting').get();
      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
      senderId = _setting(data, 'senderId');
      jsonNotificationFileURL = _setting(data, 'serviceJson');
      // Always assigned, so clearing the field switches back to the legacy path.
      serverPushUrl = _setting(data, 'serverPushUrl');
    } catch (e) {
      log("Notification settings not loaded: $e");
    }
  }

  /// A send can run before main.dart has read the settings (or after that read
  /// failed): read them here once instead of posting to an empty URL.
  static Future<void> _ensureSettings() async {
    if (useServerPush || jsonNotificationFileURL.trim().isNotEmpty) return;
    await (_settingsLoad ??= loadNotificationSettings().whenComplete(() => _settingsLoad = null));
  }

  /// Downloads the service-account file. Refused while the server path is on.
  static Future<http.Response> getCharacters() {
    if (useServerPush) {
      throw StateError('Server push is on: the service-account file is not downloaded.');
    }
    return http.get(Uri.parse(jsonNotificationFileURL.trim())).timeout(_httpTimeout);
  }

  /// An OAuth access token for FCM, minted once and reused until 5 minutes
  /// before it expires. A live credential: never log it. Refused while the
  /// server path is on.
  static Future<String> getAccessToken() async {
    if (useServerPush) {
      throw StateError('Server push is on: no access token is minted on the device.');
    }
    final String? cached = _accessToken;
    if (cached != null && isAccessTokenFresh(_accessTokenExpiry, DateTime.now())) return cached;
    return _minting ??= _mintAccessToken().whenComplete(() => _minting = null);
  }

  static Future<String> _mintAccessToken() async {
    final http.Response response = await getCharacters();
    if (response.statusCode != 200) {
      throw StateError('Service-account file not available (HTTP ${response.statusCode}).');
    }
    final Map<String, dynamic> json = jsonDecode(response.body) as Map<String, dynamic>;
    _serviceAccountProjectId = json['project_id']?.toString();
    final http.Client client = http.Client();
    try {
      final AccessCredentials credentials = await obtainAccessCredentialsViaServiceAccount(ServiceAccountCredentials.fromJson(json), _scopes, client);
      _accessToken = credentials.accessToken.data;
      _accessTokenExpiry = credentials.accessToken.expiry;
      return credentials.accessToken.data;
    } finally {
      client.close();
    }
  }

  static void _forgetAccessToken() {
    _accessToken = null;
    _accessTokenExpiry = null;
  }

  static String _appProjectId() {
    try {
      return Firebase.app().options.projectId;
    } catch (_) {
      return '';
    }
  }

  /// A `dynamic_notification` template ([type], e.g. `provider_accepted`,
  /// `worker_assigned`) to its recipient. The recipient app (customer or
  /// worker) follows from the type.
  ///
  /// [recipientId] is the recipient's uid: their token is then read fresh
  /// (`users/{id}` for a customer, `providers_workers/{id}` for a worker) and
  /// [token] is only the fallback. The customer's token on a booking is a copy
  /// taken when the booking was placed -- '' when the customer's iPhone had no
  /// token yet, stale after a reinstall -- so status pushes never arrived.
  ///
  /// [recipient] overrides the app derived from [type]. The title and body
  /// are always the template's `subject` / `message`: when the template is
  /// not set up, nothing is sent (no "setup notification" stub, no app text).
  static Future<bool> sendFcmMessage(String type, String token, Map<String, dynamic>? payload, {String? recipientId, PushApp? recipient}) async {
    try {
      final PushApp app = recipient ?? recipientForKind(type);
      final String target = await _currentToken(app, recipientId, fallback: token);
      // A customer with no usable token still gets the Notification Center
      // entry (below); anyone else: nothing to do.
      final bool customerKnown = app == PushApp.customer && (recipientId ?? '').trim().isNotEmpty;
      if (!isUsableFcmToken(target) && !customerKnown) {
        log("Push '$type' not sent: the recipient has no FCM token.");
        return false;
      }
      final NotificationModel? template = await FireStoreUtils.getNotificationContent(type);
      // getNotificationContent answers a stub (no id, no type) when the template does not exist.
      final bool templateMissing = template == null || ((template.id ?? '').isEmpty && (template.type ?? '').isEmpty) || ((template.subject ?? '').trim().isEmpty && (template.message ?? '').trim().isEmpty);
      if (templateMissing) {
        log("Push '$type' not sent: no notification template.");
        return false;
      }
      final String title = template.subject ?? '';
      final String body = template.message ?? '';
      final Map<String, String> data = await _recordForCustomer(
        data: buildPushData(payload, kind: type),
        title: title,
        body: body,
        kind: type,
        recipient: app,
        recipientId: recipientId,
      );
      if (!isUsableFcmToken(target)) {
        log("Push '$type' not sent: the recipient has no FCM token (Notification Center entry only).");
        return false;
      }
      return await _send(token: target, title: title, body: body, data: data, kind: type, recipient: app);
    } catch (e) {
      log("Push '$type' not sent: $e");
      return false;
    }
  }

  /// The recipient's token as stored now; [fallback] only when the record
  /// could not be read or does not exist ([preferFreshToken]).
  static Future<String> _currentToken(PushApp recipient, String? recipientId, {required String fallback}) async {
    final String id = (recipientId ?? '').trim();
    if (id.isEmpty) return preferFreshToken(fallback: fallback);
    try {
      final String collection = recipient == PushApp.worker ? WORKERS : USERS;
      final snapshot = await FireStoreUtils.firestore.collection(collection).doc(id).get();
      // A missing record (null) may use the copy; an existing one with no token may not.
      return preferFreshToken(fresh: snapshot.exists ? (snapshot.data()?['fcmToken']?.toString() ?? '') : null, fallback: fallback);
    } catch (e) {
      log("Recipient token not read, using the one on the record: $e");
      return preferFreshToken(fallback: fallback);
    }
  }

  /// A chat message to the holder of [token]; [recipient] is the app on the
  /// other side of the thread (a customer or a worker). [recipientId] is the
  /// recipient's uid: a customer's gets the message in their Notification
  /// Center.
  static Future<bool> sendChatFcmMessage(String title, String message, String token, Map<String, dynamic>? payload, {PushApp recipient = PushApp.customer, String? recipientId}) async {
    try {
      // Recorded for a customer even without a usable token (no push then).
      final Map<String, String> data = await _recordForCustomer(
        data: buildPushData(payload, kind: 'chat'),
        title: title,
        body: message,
        kind: 'chat',
        recipient: recipient,
        recipientId: recipientId,
      );
      if (!isUsableFcmToken(token)) {
        log("Chat push not sent: the recipient has no FCM token.");
        return false;
      }
      return await _send(token: token, title: title, body: message, data: data, kind: 'chat', recipient: recipient);
    } catch (e) {
      log("Chat push not sent: $e");
      return false;
    }
  }

  /// A push to a customer is also stored in their Notification Center
  /// (.claude/CUSTOMER-NOTIFICATIONS.md), with the same text and data,
  /// whether or not a push follows; the push then names the record so the
  /// customer app does not store it twice. Returns [data] (with the id when
  /// recorded).
  static Future<Map<String, String>> _recordForCustomer({
    required Map<String, String> data,
    required String title,
    required String body,
    required String kind,
    required PushApp recipient,
    String? recipientId,
  }) async {
    if (shouldRecordCustomerNotification(recipient: recipient, customerId: recipientId ?? '', title: title, body: body)) {
      final String? notificationId = await FireStoreUtils.recordCustomerNotification(customerId: recipientId!, title: title, body: body, kind: kind, data: data);
      if (notificationId != null) data[notificationIdDataKey] = notificationId;
    }
    return data;
  }

  static Future<bool> _send({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required String kind,
    required PushApp recipient,
  }) async {
    final PushRoute route = pushRouteFor(recipient, kind: kind);
    await _ensureSettings();
    if (useServerPush) {
      return _sendViaServer(token: token, title: title, body: body, data: data, kind: kind, route: route);
    }
    return _sendViaFcm(token: token, title: title, body: body, data: data, kind: kind, route: route);
  }

  static Future<bool> _sendViaFcm({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required String kind,
    required PushRoute route,
  }) async {
    if (jsonNotificationFileURL.trim().isEmpty) {
      log("Push '$kind' not sent: settings/notification_setting has no serviceJson.");
      return false;
    }
    Future<http.Response> post() async {
      final String accessToken = await getAccessToken();
      final String projectId = fcmProjectId(optionsProjectId: _appProjectId(), serviceAccountProjectId: _serviceAccountProjectId, settingsSenderId: senderId);
      return http
          .post(
            fcmSendUri(projectId),
            headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
            body: jsonEncode(buildFcmV1Message(token: token, title: title, body: body, data: data, route: route)),
          )
          .timeout(_httpTimeout);
    }

    http.Response response = await post();
    if (response.statusCode == 401) {
      // Revoked or expired early: mint a new token and try once more.
      _forgetAccessToken();
      response = await post();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return true;
    _logFailure(kind, token, parseFcmError(response.statusCode, response.body));
    return false;
  }

  static Future<bool> _sendViaServer({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required String kind,
    required PushRoute route,
  }) async {
    final auth.User? user = auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      log("Push '$kind' not sent: nobody is signed in.");
      return false;
    }
    final String requestBody = jsonEncode(buildServerPushRequest(token: token, title: title, body: body, data: data, kind: kind, route: route));
    Future<http.Response> post(bool refreshIdToken) async {
      // The ID token is a credential too: never log it.
      final String? idToken = await user.getIdToken(refreshIdToken);
      return http
          .post(
            Uri.parse(serverPushUrl.trim()),
            headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer ${idToken ?? ''}'},
            body: requestBody,
          )
          .timeout(_httpTimeout);
    }

    http.Response response = await post(false);
    if (response.statusCode == 401) response = await post(true);
    if (response.statusCode == 200) return true;
    _logFailure(kind, token, parseServerPushError(response.statusCode, response.body));
    return false;
  }

  static void _logFailure(String kind, String token, PushSendError error) {
    log("Push '$kind' failed: $error, recipient token ${tokenFingerprint(token)}.");
    if (error.isDeadToken) {
      // The token belongs to another user (a customer or a worker), whose
      // record this app does not own: their app saves a fresh token on its
      // next start (and on every token refresh).
      log("Push '$kind': the recipient's token is no longer valid; it is replaced when the recipient opens their app.");
    }
  }
}
