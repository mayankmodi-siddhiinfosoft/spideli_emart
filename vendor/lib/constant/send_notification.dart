// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/notification_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/push_payload.dart';

/// Sends the store's pushes to customers and drivers.
///
/// Every send:
/// - goes to the recipient's CURRENT token (`users/{recipientId}.fcmToken`
///   when the id is known; the copy on an order is from checkout and goes
///   stale when the customer reinstalls or the token rotates), and is skipped
///   (logged) when there is no usable token;
/// - carries string-only `data` with `type` (FCM rejects the whole message
///   otherwise) and `android` / `apns` blocks naming the receiving app's
///   channel and a sound, so it shows and sounds in the background on both
///   platforms;
/// - checks the HTTP result: a failure returns false and logs the status and
///   FCM error code (never a token), and a dead recipient token is cleared
///   when it is still the stored one;
/// - uses the `sendPush` server function when
///   `settings/notification_setting.serverPushUrl` is an https URL
///   (`.claude/SERVER-PUSH-CONTRACT.md`), and then never downloads the
///   service-account key. Otherwise the legacy FCM v1 call, with the access
///   token cached until shortly before it expires.
class SendNotification {
  static final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  /// True when pushes go through the server function.
  static bool get useServerPush => PushPayload.isServerPushUrl(Constant.serverPushUrl);

  // ── Legacy access token (cached; never logged) ──

  static String? _accessToken;
  static DateTime? _accessTokenExpiry;
  static String? _accessTokenKeyUrl;
  static Future<String>? _minting;

  /// Downloads the service-account key. Refused while the server path is on.
  static Future<http.Response> getCharacters() {
    if (useServerPush) {
      throw StateError('serverPushUrl is set: the service-account key is not downloaded');
    }
    return http.get(Uri.parse(Constant.jsonNotificationFileURL.toString())).timeout(const Duration(seconds: 20));
  }

  /// An FCM access token, minted from the service-account key and reused until
  /// five minutes before it expires. It used to download the key and mint a
  /// new token for every single push. Refused while the server path is on.
  static Future<String> getAccessToken({bool forceRefresh = false}) async {
    if (useServerPush) {
      throw StateError('serverPushUrl is set: no access token is minted on the device');
    }
    final String keyUrl = Constant.jsonNotificationFileURL;
    final DateTime now = DateTime.now().toUtc();
    final String? cached = _accessToken;
    final DateTime? expiry = _accessTokenExpiry;
    if (!forceRefresh && cached != null && expiry != null && _accessTokenKeyUrl == keyUrl && now.isBefore(expiry.subtract(const Duration(minutes: 5)))) {
      return cached;
    }
    final Future<String>? inFlight = _minting;
    if (!forceRefresh && inFlight != null) return inFlight;
    final Future<String> minting = _mintAccessToken(keyUrl);
    _minting = minting;
    try {
      return await minting;
    } finally {
      if (identical(_minting, minting)) _minting = null;
    }
  }

  static Future<String> _mintAccessToken(String keyUrl) async {
    final http.Response response = await getCharacters();
    if (!PushPayload.isSuccess(response.statusCode)) {
      throw Exception('service-account key download failed: HTTP ${response.statusCode}');
    }
    final ServiceAccountCredentials serviceAccountCredentials = ServiceAccountCredentials.fromJson(json.decode(response.body));
    final http.Client client = http.Client();
    try {
      final AccessCredentials credentials = await obtainAccessCredentialsViaServiceAccount(serviceAccountCredentials, _scopes, client);
      _accessToken = credentials.accessToken.data;
      _accessTokenExpiry = credentials.accessToken.expiry;
      _accessTokenKeyUrl = keyUrl;
      return credentials.accessToken.data;
    } finally {
      client.close();
    }
  }

  static void _dropAccessToken() {
    _accessToken = null;
    _accessTokenExpiry = null;
  }

  static String _firebaseProjectId() {
    try {
      return Firebase.app().options.projectId;
    } catch (_) {
      return '';
    }
  }

  // ── Public senders (signatures kept; recipient details are optional) ──

  /// A templated push (`dynamic_notification` of [type]).
  ///
  /// [recipientId] is the recipient's user id: their current token is read
  /// from `users/{recipientId}` and [token] is only the fallback.
  /// [recipient] picks the receiving app's channel.
  static Future<bool> sendFcmMessage(String type, String token, Map<String, dynamic>? payload, {String? recipientId, PushRecipient recipient = PushRecipient.customer}) async {
    try {
      final String target = await _resolveToken(token, recipientId);
      if (!PushPayload.isUsableToken(target)) {
        debugPrint("push '$type' skipped: no FCM token for ${_who(recipientId)}");
        return false;
      }
      final NotificationModel? notificationModel = await FireStoreUtils.getNotificationContent(type);
      // `notificationModel!` threw whenever the admin had no template for this
      // type, and the catch below turned that into a silent `false` - the
      // customer was simply never told. Say so in the log and stop, rather than
      // pretending to have sent something.
      if (notificationModel == null) {
        debugPrint("sendFcmMessage: no notification template stored for type '$type'");
        return false;
      }
      return await _send(
        token: target,
        recipientId: recipientId,
        title: notificationModel.subject ?? '',
        body: notificationModel.message ?? '',
        data: PushPayload.stringData(payload, type: type),
        kind: type,
        recipient: recipient,
      );
    } catch (e) {
      debugPrint("push '$type' failed: $e");
      return false;
    }
  }

  /// A push with a fixed title and body.
  static Future<bool> sendOneNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
    String? recipientId,
    PushRecipient recipient = PushRecipient.customer,
  }) async {
    try {
      final String target = await _resolveToken(token, recipientId);
      final Map<String, String> data = PushPayload.stringData(payload);
      if (!PushPayload.isUsableToken(target)) {
        debugPrint("push '${data['type'] ?? ''}' skipped: no FCM token for ${_who(recipientId)}");
        return false;
      }
      // No kind: data.type alone decides the channel (contract section 5).
      return await _send(token: target, recipientId: recipientId, title: title, body: body, data: data, recipient: recipient);
    } catch (e) {
      debugPrint("push failed: $e");
      return false;
    }
  }

  /// A chat message push.
  static Future<bool> sendChatFcmMessage(String title, String message, String token, Map<String, dynamic>? payload, {String? recipientId, PushRecipient recipient = PushRecipient.customer}) async {
    try {
      final String target = await _resolveToken(token, recipientId);
      if (!PushPayload.isUsableToken(target)) {
        debugPrint("chat push skipped: no FCM token for ${_who(recipientId)}");
        return false;
      }
      return await _send(
        token: target,
        recipientId: recipientId,
        title: title,
        body: message,
        data: PushPayload.stringData(payload, type: 'orderChat'),
        kind: 'chat',
        recipient: recipient,
      );
    } catch (e) {
      debugPrint("chat push failed: $e");
      return false;
    }
  }

  // ── Internals ──

  static String _who(String? recipientId) => (recipientId ?? '').isEmpty ? 'the recipient' : 'user $recipientId';

  /// The recipient's current token from their user record, else [fallback].
  static Future<String> _resolveToken(String fallback, String? recipientId) async {
    if ((recipientId ?? '').trim().isNotEmpty) {
      try {
        final String current = await FireStoreUtils.getUserFcmToken(recipientId!.trim());
        if (PushPayload.isUsableToken(current)) return current.trim();
      } catch (e) {
        debugPrint('push: could not read the current token of ${_who(recipientId)}: $e');
      }
    }
    return fallback.trim();
  }

  static Future<bool> _send({
    required String token,
    String? recipientId,
    required String title,
    required String body,
    required Map<String, String> data,
    String? kind,
    required PushRecipient recipient,
  }) async {
    final PushChannel channel = PushPayload.channelFor(recipient, kind ?? data['type']);
    final String label = kind ?? data['type'] ?? '';
    final http.Response? response = useServerPush
        ? await _postToServer(token: token, title: title, body: body, data: data, kind: kind, channel: channel)
        : await _postToFcm(token: token, title: title, body: body, data: data, channel: channel);
    if (response == null) return false;
    if (PushPayload.isSuccess(response.statusCode)) {
      debugPrint("push '$label' sent (${useServerPush ? 'server' : 'legacy'}, ${response.statusCode})");
      return true;
    }
    final String code = PushPayload.errorCode(response.body);
    debugPrint("push '$label' FAILED (${useServerPush ? 'server' : 'legacy'}): HTTP ${response.statusCode} ${code.isEmpty ? '' : code}");
    if (PushPayload.isDeadToken(response.statusCode, response.body)) {
      await _clearDeadToken(recipientId, token);
    }
    return false;
  }

  /// Legacy FCM v1 call.
  static Future<http.Response?> _postToFcm({required String token, required String title, required String body, required Map<String, String> data, required PushChannel channel}) async {
    final String projectId = PushPayload.fcmProjectId(firebaseProjectId: _firebaseProjectId(), settingsSenderId: Constant.senderId);
    if (projectId.isEmpty) {
      debugPrint('push skipped: no Firebase project id');
      return null;
    }
    if (Constant.jsonNotificationFileURL.trim().isEmpty) {
      debugPrint('push skipped: settings/notification_setting has no serviceJson yet');
      return null;
    }
    final String message = jsonEncode(PushPayload.legacyMessage(token: token, title: title, body: body, data: data, channel: channel));
    Future<http.Response> post(String accessToken) => http
        .post(
          PushPayload.fcmSendUri(projectId),
          headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
          body: message,
        )
        .timeout(const Duration(seconds: 20));
    http.Response response = await post(await getAccessToken());
    if (response.statusCode == 401) {
      // The cached token was revoked or expired early: mint once more.
      _dropAccessToken();
      response = await post(await getAccessToken(forceRefresh: true));
    }
    return response;
  }

  /// `sendPush` server function, with the signed-in user's Firebase ID token.
  static Future<http.Response?> _postToServer({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    String? kind,
    required PushChannel channel,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('push skipped: nobody is signed in for the server push');
      return null;
    }
    final String requestBody = jsonEncode(PushPayload.serverBody(token: token, title: title, body: body, data: data, kind: kind, channel: channel));
    Future<http.Response> post(bool refresh) async {
      final String? idToken = await user.getIdToken(refresh);
      return http
          .post(
            Uri.parse(Constant.serverPushUrl.trim()),
            headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer ${idToken ?? ''}'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 15));
    }

    http.Response response = await post(false);
    if (response.statusCode == 401) response = await post(true);
    return response;
  }

  /// FCM says [badToken] is dead: clear it on the recipient's record when it
  /// is still the stored token (they may have refreshed it meanwhile).
  static Future<void> _clearDeadToken(String? recipientId, String badToken) async {
    if ((recipientId ?? '').trim().isEmpty) {
      debugPrint('push: the recipient token is no longer registered (no user id to clear it on)');
      return;
    }
    final bool cleared = await FireStoreUtils.clearUserFcmTokenIfEquals(recipientId!.trim(), badToken);
    debugPrint(cleared ? 'push: cleared the dead token of user $recipientId' : 'push: dead token of user $recipientId left as is');
  }
}
