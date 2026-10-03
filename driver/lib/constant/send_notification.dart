import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:driver/constant/constant.dart';
import 'package:driver/models/notification_model.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vendor_model.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

export 'package:driver/services/push_message.dart' show PushRecipient;

/// Every push the driver app sends (to customers and stores).
///
/// Two paths, chosen by `settings/notification_setting.serverPushUrl`
/// (`.claude/SERVER-PUSH-CONTRACT.md`):
///  * an https URL -> the `sendPush` function, authenticated with the signed-in
///    driver's Firebase ID token. The service-account key is never
///    downloaded and there is no fallback to the legacy path.
///  * otherwise -> the legacy on-device FCM HTTP v1 call.
///
/// Both carry the same message: string-only data that always has `type`,
/// the recipient app's Android channel and sound, and the APNs priority /
/// sound that make an iPhone show and play it (`PushMessage`).
///
/// Every method returns true only when FCM (or the function) accepted the
/// message. Tokens and access tokens are never logged.
class SendNotification {
  SendNotification._();

  static const List<String> _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  static const Duration _timeout = Duration(seconds: 20);

  /// True when pushes go through the server function.
  static bool get useServerPush => PushMessage.isHttpsUrl(Constant.serverPushUrl);

  // ── Legacy credentials ────────────────────────────────────────────────────

  static CachedAccessToken? _accessToken;
  static String _accessTokenKeyUrl = '';
  static Future<CachedAccessToken>? _minting;

  /// Downloads the service-account key. Refused while [useServerPush] is on,
  /// so no code path can fetch the key once the switch is set.
  static Future<http.Response> getCharacters() {
    if (useServerPush) {
      throw StateError('Server push is on: the service-account key is not downloaded.');
    }
    return http.get(Uri.parse(Constant.jsonNotificationFileURL.toString())).timeout(_timeout);
  }

  /// An OAuth access token for FCM, minted once and reused until five minutes
  /// before it expires (it used to download the key and mint a new token for
  /// every single push). Refused while [useServerPush] is on.
  static Future<String> getAccessToken() async {
    if (useServerPush) {
      throw StateError('Server push is on: no access token is minted on the device.');
    }
    final CachedAccessToken? cached = _accessToken;
    if (cached != null && _accessTokenKeyUrl == Constant.jsonNotificationFileURL && cached.isFresh(DateTime.now())) {
      return cached.value;
    }
    _minting ??= _mintAccessToken().whenComplete(() => _minting = null);
    return (await _minting!).value;
  }

  static Future<CachedAccessToken> _mintAccessToken() async {
    final String keyUrl = Constant.jsonNotificationFileURL;
    if (keyUrl.trim().isEmpty) throw StateError('settings/notification_setting.serviceJson is empty.');
    final http.Response response = await getCharacters();
    if (response.statusCode != 200) {
      throw StateError('Service-account download failed: HTTP ${response.statusCode}');
    }
    final ServiceAccountCredentials credentials = ServiceAccountCredentials.fromJson(json.decode(response.body));
    final http.Client client = http.Client();
    try {
      final AccessCredentials minted = await obtainAccessCredentialsViaServiceAccount(credentials, _scopes, client).timeout(_timeout);
      final CachedAccessToken token = CachedAccessToken(minted.accessToken.data, minted.accessToken.expiry);
      _accessToken = token;
      _accessTokenKeyUrl = keyUrl;
      return token;
    } finally {
      client.close();
    }
  }

  /// `projects/<id>` for the v1 URL: the Firebase app's project id, not the
  /// project number stored in settings.
  static String _projectId() {
    String fromApp = '';
    try {
      fromApp = Firebase.app().options.projectId;
    } catch (_) {}
    return PushMessage.projectId(firebaseProjectId: fromApp, settingsSenderId: Constant.senderId);
  }

  // ── Recipient tokens ──────────────────────────────────────────────────────

  /// The customer's live token: `users/{customerId}.fcmToken`, falling back
  /// to the copy embedded in the order. That copy is the token at order time:
  /// it goes stale when FCM rotates the token, and was '' for every iPhone
  /// that placed an order before its APNs token was in.
  static Future<String> customerToken({String? customerId, String? embeddedToken}) async {
    final String id = (customerId ?? '').trim();
    if (id.isNotEmpty) {
      final UserModel? customer = await FireStoreUtils.getUserProfile(id);
      final String live = (customer?.fcmToken ?? '').trim();
      if (PushMessage.isUsableToken(live)) return live;
    }
    final String embedded = (embeddedToken ?? '').trim();
    return PushMessage.isUsableToken(embedded) ? embedded : '';
  }

  /// The store's live token: its owner's `users/{vendor.author}.fcmToken`
  /// (where the store app saves it), then `vendors/{id}.fcmToken`, then the
  /// copy embedded in the order.
  static Future<String> storeToken({VendorModel? vendor, String? vendorId}) async {
    String ownerId = (vendor?.author ?? '').trim();
    final String id = (vendorId ?? vendor?.id ?? '').trim();
    VendorModel? live;
    if (ownerId.isEmpty && id.isNotEmpty) {
      live = await FireStoreUtils.getVendorById(id);
      ownerId = (live?.author ?? '').trim();
    }
    if (ownerId.isNotEmpty) {
      final UserModel? owner = await FireStoreUtils.getUserProfile(ownerId);
      final String ownerToken = (owner?.fcmToken ?? '').trim();
      if (PushMessage.isUsableToken(ownerToken)) return ownerToken;
    }
    if (id.isNotEmpty) {
      live ??= await FireStoreUtils.getVendorById(id);
      final String vendorToken = (live?.fcmToken ?? '').trim();
      if (PushMessage.isUsableToken(vendorToken)) return vendorToken;
    }
    final String embedded = (vendor?.fcmToken ?? '').trim();
    return PushMessage.isUsableToken(embedded) ? embedded : '';
  }

  /// `driver_accepted` for a delivery order, to its customer and its store.
  static Future<void> notifyOrderAccepted(OrderModel order) async {
    try {
      final Map<String, dynamic> payload = <String, dynamic>{'orderId': order.id};
      final String customer = await customerToken(customerId: order.authorID ?? order.author?.id, embeddedToken: order.author?.fcmToken);
      await sendFcmMessage(Constant.driverAcceptedNotification, customer, payload);
      final String store = await storeToken(vendor: order.vendor, vendorId: order.vendorID);
      await sendFcmMessage(Constant.driverAcceptedNotification, store, payload, recipient: PushRecipient.store);
    } catch (e) {
      log("driver_accepted pushes failed: $e");
    }
  }

  // ── Public senders (signatures kept for the existing call sites) ─────────

  /// A templated push (`dynamic_notification` where `type` == [type]).
  /// [recipient] picks the receiving app's channel; the store gets
  /// [PushRecipient.store].
  static Future<bool> sendFcmMessage(
    String type,
    String token,
    Map<String, dynamic>? payload, {
    PushRecipient recipient = PushRecipient.customer,
  }) async {
    if (!PushMessage.isUsableToken(token)) {
      log("Push '$type' skipped: the recipient has no FCM token.");
      return false;
    }
    try {
      final NotificationModel? template = await FireStoreUtils.getNotificationContent(type);
      return await _deliver(
        token: token,
        title: template?.subject ?? '',
        body: template?.message ?? '',
        data: PushMessage.stringData(payload, type: type),
        recipient: recipient,
        kind: type,
      );
    } catch (e) {
      log("Push '$type' failed: $e");
      return false;
    }
  }

  /// A push with its own text (the delivery-code push).
  static Future<bool> sendOneNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
    PushRecipient recipient = PushRecipient.customer,
  }) async {
    final Map<String, String> data = PushMessage.stringData(payload);
    if (!PushMessage.isUsableToken(token)) {
      log("Push '${data['type'] ?? ''}' skipped: the recipient has no FCM token.");
      return false;
    }
    try {
      return await _deliver(token: token, title: title, body: body, data: data, recipient: recipient);
    } catch (e) {
      log("Push '${data['type'] ?? ''}' failed: $e");
      return false;
    }
  }

  /// A chat message. Every driver chat is with a customer.
  static Future<bool> sendChatFcmMessage(
    String title,
    String message,
    String token,
    Map<String, dynamic>? payload, {
    PushRecipient recipient = PushRecipient.customer,
  }) async {
    if (!PushMessage.isUsableToken(token)) {
      log("Chat push skipped: the recipient has no FCM token.");
      return false;
    }
    try {
      return await _deliver(
        token: token,
        title: title,
        body: message,
        data: PushMessage.stringData(payload, type: 'orderChat'),
        recipient: recipient,
        kind: 'chat',
      );
    } catch (e) {
      log("Chat push failed: $e");
      return false;
    }
  }

  // ── Delivery ──────────────────────────────────────────────────────────────

  static Future<bool> _deliver({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
    required PushRecipient recipient,
    String? kind,
  }) {
    final String label = kind ?? data['type'] ?? '';
    if (useServerPush) {
      return _sendViaServer(
        PushMessage.serverRequest(token: token, title: title, body: body, data: data, recipient: recipient, kind: kind),
        label,
      );
    }
    return _sendLegacy(
      PushMessage.v1Message(token: token, title: title, body: body, data: data, recipient: recipient),
      label,
    );
  }

  static Future<bool> _sendLegacy(Map<String, dynamic> message, String label) async {
    final String projectId = _projectId();
    if (projectId.isEmpty) {
      log("Push '$label' not sent: no Firebase project id.");
      return false;
    }
    final Uri uri = PushMessage.fcmSendUri(projectId);

    Future<http.Response> post(String accessToken) => http
        .post(
          uri,
          headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer $accessToken'},
          body: jsonEncode(message),
        )
        .timeout(_timeout);

    http.Response response = await post(await getAccessToken());
    if (response.statusCode == 401) {
      // Revoked or expired early: mint a fresh token and try once more.
      _accessToken = null;
      response = await post(await getAccessToken());
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      log("Push '$label' sent (HTTP ${response.statusCode}).");
      return true;
    }
    final FcmFailure failure = PushMessage.parseFcmError(response.statusCode, response.body);
    if (PushMessage.isDeadTokenError(fcmCode: failure.code, fcmMessage: failure.message)) {
      // The recipient's token is dead. Its owner's app replaces it on its next
      // start (field-level write); this app never writes another user's
      // document for it.
      log("Push '$label' not delivered: the recipient's FCM token is no longer valid ($failure).");
    } else {
      log("Push '$label' rejected: $failure");
    }
    return false;
  }

  static Future<bool> _sendViaServer(Map<String, dynamic> request, String label) async {
    final auth.User? user = auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      log("Push '$label' not sent: no signed-in user for the server push.");
      return false;
    }

    Future<http.Response> post(bool refresh) async {
      final String? idToken = await user.getIdToken(refresh);
      return http
          .post(
            Uri.parse(Constant.serverPushUrl.trim()),
            headers: <String, String>{'Content-Type': 'application/json', 'Authorization': 'Bearer ${idToken ?? ''}'},
            body: jsonEncode(request),
          )
          .timeout(_timeout);
    }

    try {
      http.Response response = await post(false);
      if (response.statusCode == 401) response = await post(true);
      if (response.statusCode == 200) {
        log("Push '$label' sent via server.");
        return true;
      }
      final String code = PushMessage.parseServerError(response.body);
      if (PushMessage.isDeadTokenError(serverCode: code)) {
        log("Push '$label' not delivered: the recipient's FCM token is no longer valid (HTTP ${response.statusCode} $code).");
      } else {
        log("Push '$label' rejected by server: HTTP ${response.statusCode} ${code.isEmpty ? '-' : code}");
      }
      return false;
    } catch (e) {
      log("Push '$label' server call failed: $e");
      return false;
    }
  }
}
