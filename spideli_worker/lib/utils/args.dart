/// Reading `Get.arguments` without crashing the screen.
///
/// Bug #17 / #3 class: every caller builds the argument map out of Firestore
/// data, so any key can be absent or null — a chat opened from a push whose
/// payload is missing a field, a wallet top-up row that has no `orderId`.
/// Assigning that straight into a non-nullable `RxString` throws a `TypeError`
/// inside the controller's `onInit` future, which GetX swallows: the remaining
/// arguments stay unset and the screen builds an invalid Firestore path.
///
/// `Get.arguments` is also not always a `Map` — some screens are opened with a
/// bare model object — so indexing it has to be guarded too.
library;

/// One argument as a plain string, or `""` when there is nothing usable.
///
/// Values that merely *print* as missing (`"null"`, `"nil"`, `"undefined"`) are
/// treated as absent, because they reach us from records whose fields were
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

/// One argument typed as [T], or null when the key is absent or holds something
/// else, so the caller can keep its existing default instead of assigning null
/// into a non-nullable `Rx`.
T? argOf<T>(dynamic arguments, String key) {
  if (arguments is! Map) return null;
  final dynamic value = arguments[key];
  return value is T ? value : null;
}
