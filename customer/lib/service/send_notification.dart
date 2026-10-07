import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:customer/constant/constant.dart';
import 'package:customer/models/notification_model.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/service/push_message.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// Sends pushes to the other apps (stores, drivers, providers, workers).
///
/// Two paths, chosen by `settings/notification_setting.serverPushUrl`
/// (`.claude/SERVER-PUSH-CONTRACT.md`): the `sendPush` function when it is an
/// https URL (the service-account key is then never downloaded), otherwise
/// FCM HTTP v1 directly. Both send the same title, body, string data and
/// receiving-app channel ([PushChannels]). Every method returns whether FCM
/// accepted the message, and logs why not, but never the token, the access
/// token or the key's URL.
class SendNotification {
  static final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  static const Duration _timeout = Duration(seconds: 15);

  static bool get useServerPush => PushPayload.isServerPushUrl(Constant.serverPushUrl);

  /// Downloads the service-account key (legacy path only).
  static Future<http.Response> getCharacters() {
    if (useServerPush) throw StateError('serverPushUrl is set: the service-account key is not downloaded');
    return http.get(Uri.parse(Constant.jsonNotificationFileURL.toString())).timeout(_timeout);
  }

  static CachedAccessToken? _accessToken;
  static Future<CachedAccessToken>? _minting;

  /// An OAuth token for FCM, minted from the service account and reused until
  /// shortly before it expires (it used to download the key for every push).
  static Future<String> getAccessToken({bool forceRefresh = false}) async {
    if (useServerPush) throw StateError('serverPushUrl is set: no access token is minted on the device');
    final CachedAccessToken? cached = _accessToken;
    if (!forceRefresh && cached != null && cached.isUsable(DateTime.now().toUtc())) return cached.token;
    final CachedAccessToken minted = await (_minting ??= _mintAccessToken().whenComplete(() => _minting = null));
    return minted.token;
  }

  static Future<CachedAccessToken> _mintAccessToken() async {
    final http.Response response = await getCharacters();
    if (response.statusCode != 200) throw StateError('service account download returned HTTP ${response.statusCode}');
    final credentials = ServiceAccountCredentials.fromJson(json.decode(response.body));
    final AutoRefreshingAuthClient client = await clientViaServiceAccount(credentials, _scopes);
    try {
      final AccessToken token = client.credentials.accessToken;
      return _accessToken = CachedAccessToken(token: token.data, expiry: token.expiry.toUtc());
    } finally {
      client.close();
    }
  }

  /// A template push (`dynamic_notification` of [type]) to [token].
  /// [recipient] picks the receiving app's channel and sound.
  static Future<bool> sendFcmMessage(String type, String token, Map<String, dynamic>? payload, {PushRecipient? recipient}) async {
    if (!PushPayload.isUsableToken(token)) {
      log('push "$type" not sent: the recipient has no FCM token');
      return false;
    }
    try {
      final NotificationModel? template = await FireStoreUtils.getNotificationContent(type);
      return await _send(token: token, title: template?.subject ?? '', body: template?.message ?? '', payload: payload, kind: type, recipient: recipient);
    } catch (e) {
      log('push "$type" failed (${e.runtimeType})');
      return false;
    }
  }

  static Future<bool> sendOneNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
    PushRecipient? recipient,
  }) {
    return _send(token: token, title: title, body: body, payload: payload, recipient: recipient);
  }

  /// A chat message. [recipient] is the other side of the thread.
  static Future<bool> sendChatFcmMessage(String title, String message, String token, Map<String, dynamic>? payload, {PushRecipient? recipient}) {
    return _send(token: token, title: title, body: message, payload: payload, kind: 'chat', recipient: recipient);
  }

  static Future<bool> _send({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? kind,
    PushRecipient? recipient,
  }) async {
    final String label = kind ?? payload?['type']?.toString() ?? 'push';
    if (!PushPayload.isUsableToken(token)) {
      log('push "$label" not sent: the recipient has no FCM token');
      return false;
    }
    final PushChannelSpec spec = PushChannels.forRecipient(recipient, kind: kind);
    // A chat's `type` is the caller's (orderChat); `chat` is only the kind.
    final Map<String, String> data = PushPayload.stringData(payload, type: kind == 'chat' ? null : kind, spec: spec);
    try {
      if (useServerPush) {
        return await _sendViaServer(token: token, title: title, body: body, data: data, kind: kind, spec: spec, label: label);
      }
      return await _sendViaFcm(token: token, title: title, body: body, data: data, spec: spec, label: label);
    } catch (e) {
      log('push "$label" failed (${e.runtimeType})');
      return false;
    }
  }

  static String? _firebaseProjectId() {
    try {
      return Firebase.app().options.projectId;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _sendViaFcm({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required PushChannelSpec spec,
    required String label,
  }) async {
    // The project id the app was built with. Settings hold the project
    // NUMBER as `senderId`; it is only the fallback.
    final String projectId = PushPayload.projectId(firebaseProjectId: _firebaseProjectId(), settingsSenderId: Constant.senderId);
    if (projectId.isEmpty) {
      log('push "$label" not sent: no Firebase project id');
      return false;
    }
    final String requestBody = jsonEncode({'message': PushPayload.fcmV1Message(token: token, title: title, body: body, data: data, spec: spec)});
    Future<http.Response> post(String accessToken) => http
        .post(PushPayload.fcmSendUri(projectId), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'}, body: requestBody)
        .timeout(_timeout);

    http.Response response = await post(await getAccessToken());
    if (response.statusCode == 401) {
      // The cached token was revoked or expired early: mint a new one, once.
      response = await post(await getAccessToken(forceRefresh: true));
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return true;

    final FcmSendError error = FcmSendError.parse(response.statusCode, response.body);
    log('push "$label" refused by FCM: $error');
    if (error.isDeadToken) {
      // The recipient is another account (store, driver, provider, worker):
      // the customer app must not write their user document. Their app saves
      // a fresh token the next time it starts.
      log('push "$label": the recipient\'s FCM token is no longer valid');
    }
    return false;
  }

  static Future<bool> _sendViaServer({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required PushChannelSpec spec,
    required String label,
    String? kind,
  }) async {
    final auth.User? user = auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      log('push "$label" not sent: no signed-in user for the server path');
      return false;
    }
    final String requestBody = jsonEncode(PushPayload.serverRequest(token: token, title: title, body: body, data: data, spec: spec, kind: kind));
    Future<http.Response> post(bool refreshIdToken) async {
      final String? idToken = await user.getIdToken(refreshIdToken);
      return http
          .post(Uri.parse(Constant.serverPushUrl.trim()), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${idToken ?? ''}'}, body: requestBody)
          .timeout(_timeout);
    }

    http.Response response = await post(false);
    if (response.statusCode == 401) response = await post(true);
    if (response.statusCode == 200) return true;
    log('push "$label" refused by the server: HTTP ${response.statusCode} ${_serverError(response.body)}');
    return false;
  }

  /// `error` and `field` of a sendPush error body (never the message text).
  static String _serverError(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map) return '${decoded['error'] ?? '-'}${decoded['field'] != null ? ' (${decoded['field']})' : ''}';
    } catch (_) {
      // Not JSON.
    }
    return '-';
  }
}
