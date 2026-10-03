import 'dart:convert';

/// Where a tapped push takes the customer (besides `delivery_otp`, which
/// `DeliveryCodePush` handles).
enum PushTapTarget { supportChat, storeInbox, driverInbox, providerInbox, workerInbox }

/// The pure parts of handling a received push: reading its payload and
/// deciding what to show or open. No Firebase, so it is unit tested.
abstract final class PushTap {
  /// The data map of a local notification's payload (`jsonEncode(message.data)`).
  /// Anything unreadable gives an empty map instead of throwing.
  static Map<String, dynamic> decodePayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return const {};
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map) return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      // Not JSON: nothing to route on.
    }
    return const {};
  }

  /// A string field of a push payload, '' when absent.
  static String field(Map<String, dynamic> data, String key) {
    final Object? value = data[key];
    if (value == null) return '';
    final String text = value.toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  /// The screen a tap opens, or null for "just open the app".
  static PushTapTarget? targetOf(Map<String, dynamic> data) {
    final String type = field(data, 'type');
    if (type == 'admin_chat') return PushTapTarget.supportChat;
    if (type == 'orderChat' || type == 'chat') {
      switch (field(data, 'chatType').toLowerCase()) {
        case 'vendor':
        case 'store':
        case 'restaurant':
          return PushTapTarget.storeInbox;
        case 'provider':
          return PushTapTarget.providerInbox;
        case 'worker':
          return PushTapTarget.workerInbox;
        default:
          return PushTapTarget.driverInbox;
      }
    }
    return null;
  }

  /// Title and body of a push the app shows itself (Android, foreground).
  /// Falls back to `title` / `body` data keys, and for a delivery-code push to
  /// the given texts. Null when there is nothing to show.
  static ({String? title, String? body})? displayText({
    String? title,
    String? body,
    Map<String, dynamic> data = const {},
    String deliveryCodeType = 'delivery_otp',
    String? deliveryCodeTitle,
    String? deliveryCodeBody,
  }) {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s;
    String? t = clean(title) ?? clean(field(data, 'title'));
    String? b = clean(body) ?? clean(field(data, 'body'));
    if (field(data, 'type') == deliveryCodeType) {
      t ??= clean(deliveryCodeTitle);
      b ??= clean(deliveryCodeBody);
    }
    if (t == null && b == null) return null;
    return (title: t, body: b);
  }

  /// A notification id per message, so a second push does not replace the
  /// first one in the shade (they all used id 0).
  static int notificationId(String? messageId, {DateTime? now}) {
    final String id = messageId?.trim() ?? '';
    if (id.isNotEmpty) return id.hashCode & 0x7fffffff;
    return ((now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000) & 0x7fffffff;
  }
}
