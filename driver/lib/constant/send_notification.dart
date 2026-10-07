import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:driver/constant/constant.dart';
import 'package:driver/models/notification_model.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/models/vendor_model.dart';
import 'package:driver/services/customer_notification.dart';
import 'package:driver/services/push_message.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
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
///
/// Customer Notification Center (`.claude/CUSTOMER-NOTIFICATIONS.md` §1):
/// a push to the customer app that names its `customerId` also writes
/// `users/{customerId}/notifications/{id}` with the same title and body, and
/// the push data carries `notificationId: <id>`. Best effort: a failed write
/// never blocks the push. The record is written even when the customer has
/// no usable token (the push is skipped, the Notification Center still shows
/// it).
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
  ///
  /// The copy is used only when the user record could not be read or does
  /// not exist. A record with an empty token means the customer signed out on
  /// that phone, so nothing is sent: the copied token may now belong to the
  /// next account signed in there.
  static Future<String> customerToken({String? customerId, String? embeddedToken}) async {
    final String id = (customerId ?? '').trim();
    if (id.isNotEmpty) {
      final UserModel? customer = await FireStoreUtils.getUserProfile(id);
      if (customer != null) {
        final String live = (customer.fcmToken ?? '').trim();
        return PushMessage.isUsableToken(live) ? live : '';
      }
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

  /// A templated push ([type]) to an order's customer, by their live token
  /// ([customerToken]), recorded in their Notification Center with [status]
  /// (the order's status after the event). Never throws.
  static Future<bool> notifyCustomer(
    String type, {
    required String? customerId,
    String? embeddedToken,
    Map<String, dynamic>? payload,
    String? status,
  }) async {
    try {
      final String token = await customerToken(customerId: customerId, embeddedToken: embeddedToken);
      return await sendFcmMessage(type, token, payload, customerId: customerId, status: status);
    } catch (e) {
      log("Push '$type' to the customer failed: $e");
      return false;
    }
  }

  /// `driver_accepted` for a delivery order, to its customer and its store.
  static Future<void> notifyOrderAccepted(OrderModel order) async {
    try {
      final Map<String, dynamic> payload = <String, dynamic>{'orderId': order.id};
      await notifyCustomer(Constant.driverAcceptedNotification,
          customerId: order.authorID ?? order.author?.id,
          embeddedToken: order.author?.fcmToken,
          payload: payload,
          // The order passed in was read before the accept, so its status
          // is the old one.
          status: Constant.driverAccepted);
      final String store = await storeToken(vendor: order.vendor, vendorId: order.vendorID);
      await sendFcmMessage(Constant.driverAcceptedNotification, store, payload, recipient: PushRecipient.store);
    } catch (e) {
      log("driver_accepted pushes failed: $e");
    }
  }

  // ── Public senders (signatures kept for the existing call sites) ─────────

  /// A templated push (`dynamic_notification` where `type` == [type]).
  /// [recipient] picks the receiving app's channel; the store gets
  /// [PushRecipient.store]. [customerId] (customer recipient only) records
  /// it in that customer's Notification Center with [status].
  /// Nothing is sent or recorded when the template is missing: the app has
  /// no notification text of its own.
  static Future<bool> sendFcmMessage(
    String type,
    String token,
    Map<String, dynamic>? payload, {
    PushRecipient recipient = PushRecipient.customer,
    String? customerId,
    String? status,
  }) async {
    final bool usable = PushMessage.isUsableToken(token);
    final bool mayRecord = recipient == PushRecipient.customer && (customerId ?? '').trim().isNotEmpty;
    if (!usable && !mayRecord) {
      log("Push '$type' skipped: the recipient has no FCM token.");
      return false;
    }
    try {
      final NotificationModel? template = await FireStoreUtils.getNotificationContent(type);
      if (template == null) {
        log("Push '$type' not sent: no dynamic_notification template for it.");
        return false;
      }
      final String title = template.subject ?? '';
      final String body = template.message ?? '';
      final Map<String, String> data = await _recordForCustomer(
        recipient: recipient,
        customerId: customerId,
        title: title,
        body: body,
        type: type,
        data: PushMessage.stringData(payload, type: type),
        status: status,
      );
      if (!usable) {
        log("Push '$type' skipped: the recipient has no FCM token.");
        return false;
      }
      return await _deliver(token: token, title: title, body: body, data: data, recipient: recipient, kind: type);
    } catch (e) {
      log("Push '$type' failed: $e");
      return false;
    }
  }

  /// A push with its own text. [customerId] (customer recipient only)
  /// records it in that customer's Notification Center with [status].
  static Future<bool> sendOneNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
    PushRecipient recipient = PushRecipient.customer,
    String? customerId,
    String? status,
  }) async {
    final Map<String, String> data = PushMessage.stringData(payload);
    final bool usable = PushMessage.isUsableToken(token);
    final bool mayRecord = recipient == PushRecipient.customer && (customerId ?? '').trim().isNotEmpty;
    if (!usable && !mayRecord) {
      log("Push '${data['type'] ?? ''}' skipped: the recipient has no FCM token.");
      return false;
    }
    try {
      final Map<String, String> sent = await _recordForCustomer(
        recipient: recipient,
        customerId: customerId,
        title: title,
        body: body,
        type: data['type'] ?? '',
        data: data,
        status: status,
      );
      if (!usable) {
        log("Push '${data['type'] ?? ''}' skipped: the recipient has no FCM token.");
        return false;
      }
      return await _deliver(token: token, title: title, body: body, data: sent, recipient: recipient);
    } catch (e) {
      log("Push '${data['type'] ?? ''}' failed: $e");
      return false;
    }
  }

  /// A chat message. Every driver chat is with a customer; [customerId]
  /// records it in that customer's Notification Center.
  static Future<bool> sendChatFcmMessage(
    String title,
    String message,
    String token,
    Map<String, dynamic>? payload, {
    PushRecipient recipient = PushRecipient.customer,
    String? customerId,
  }) async {
    final bool usable = PushMessage.isUsableToken(token);
    final bool mayRecord = recipient == PushRecipient.customer && (customerId ?? '').trim().isNotEmpty;
    if (!usable && !mayRecord) {
      log("Chat push skipped: the recipient has no FCM token.");
      return false;
    }
    try {
      final Map<String, String> data = await _recordForCustomer(
        recipient: recipient,
        customerId: customerId,
        title: title,
        body: message,
        type: '',
        data: PushMessage.stringData(payload, type: 'orderChat'),
      );
      if (!usable) {
        log("Chat push skipped: the recipient has no FCM token.");
        return false;
      }
      return await _deliver(token: token, title: title, body: message, data: data, recipient: recipient, kind: 'chat');
    } catch (e) {
      log("Chat push failed: $e");
      return false;
    }
  }

  // ── Customer Notification Center ──────────────────────────────────────────

  static const Duration _recordTimeout = Duration(seconds: 8);

  /// Writes `users/{customerId}/notifications/{id}` for a push to the
  /// customer app and returns [data] with `notificationId`. Returns [data]
  /// unchanged when there is nothing to record, and without the id when the
  /// write failed (the customer app then stores the notification itself).
  /// A slow write (offline) keeps the id: Firestore delivers it later.
  /// Known limit: if that pending write is refused once it reaches the server,
  /// the customer has a push carrying an id with no document and the customer
  /// app's fallback skips it, so that one entry is lost. Dropping the id on
  /// timeout would instead store it twice (`msg_<id>` + this record).
  static Future<Map<String, String>> _recordForCustomer({
    required PushRecipient recipient,
    required String? customerId,
    required String title,
    required String body,
    required String type,
    required Map<String, String> data,
    String? status,
  }) async {
    if (!CustomerNotification.shouldRecord(
        toCustomer: recipient == PushRecipient.customer, customerId: customerId, title: title, body: body)) {
      return data;
    }
    final String customer = customerId!.trim();
    Map<String, String> sent = data;
    try {
      final String id = FireStoreUtils.newCustomerNotificationId(customer);
      sent = CustomerNotification.withId(data, id);
      final Map<String, dynamic> document = CustomerNotification.document(
        id: id,
        title: title,
        body: body,
        type: type,
        data: sent,
        status: status,
        createdAt: FieldValue.serverTimestamp(),
      );
      await FireStoreUtils.setCustomerNotification(customer, id, document).timeout(_recordTimeout);
      return sent;
    } on TimeoutException {
      log("Notification record for '${sent['type'] ?? type}' still pending; push sent with its id.");
      return sent;
    } catch (e) {
      log("Notification record for '${data['type'] ?? type}' not written: $e");
      return CustomerNotification.withoutId(data);
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
