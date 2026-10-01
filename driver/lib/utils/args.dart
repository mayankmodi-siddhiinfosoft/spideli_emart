/// Reading `Get.arguments` without crashing the screen.
///
/// Client point 6 (and the same class of fault behind several others): every
/// caller builds the argument map out of Firestore data, so any key can be
/// absent or null — a customer with no `fcmToken`, an order id that was never
/// passed, a wallet top-up row with no `orderId`. Assigning that straight into
/// a non-nullable `RxString` throws a `TypeError` inside the controller's
/// `onInit` future, which GetX swallows: the rest of the arguments stay unset,
/// the screen builds an invalid Firestore path and comes up blank.
///
/// `Get.arguments` is also not always a `Map` — several screens are opened with
/// a bare model object — so indexing it has to be guarded too.
library;

/// One argument as a plain string, or `""` when there is nothing usable.
///
/// Values that merely *print* as missing (`"null"`, `"nil"`, `"undefined"`)
/// are treated as absent, because they reach us from records whose fields were
/// stringified somewhere upstream.
String argString(dynamic arguments, String key) {
  final dynamic value = arguments is Map ? arguments[key] : null;
  if (value == null) return "";
  final String text = value.toString().trim();
  if (text.isEmpty) return "";
  switch (text.toLowerCase()) {
    case 'null':
    case 'nil':
    case 'undefined':
      return "";
    default:
      return text;
  }
}

/// One argument typed as [T], or null when the key is absent or holds
/// something else. Lets a caller keep its existing default instead of
/// assigning null into a non-nullable `Rx`.
T? argOf<T>(dynamic arguments, String key) {
  if (arguments is! Map) return null;
  final dynamic value = arguments[key];
  return value is T ? value : null;
}
