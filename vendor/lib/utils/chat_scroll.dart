import 'package:flutter/material.dart';

/// Bring the newest message of a chat thread into view.
///
/// Every chat list in the app is a **reversed** list, so the newest message
/// sits at the minimum scroll extent, not the maximum.
///
/// The screens used to do this with a bare `Timer(500ms, () => jumpTo(...))`,
/// which throws if the thread was closed (or had not been laid out) before it
/// fired. The delay is still needed — the row only exists once Firestore
/// echoes the message back — but the controller is checked first and the move
/// is animated so the jump is not jarring.
void scrollChatToLatest(ScrollController controller, {Duration delay = const Duration(milliseconds: 300)}) {
  Future<void>.delayed(delay, () {
    if (!controller.hasClients) return;
    controller.animateTo(controller.position.minScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  });
}

/// Move a chat thread to its newest message right now, if it is not there
/// already. Returns the running animation, or null when nothing moved (no list
/// attached yet, more than one list on the controller, or already at the
/// newest message).
///
/// [reverse] is the list's own `reverse` flag: a reversed thread keeps its
/// newest message at the minimum scroll extent, a normal one at the maximum.
Future<void>? showChatLatest(ScrollController controller, {bool reverse = true}) {
  if (!controller.hasClients || controller.positions.length != 1) return null;
  final ScrollPosition position = controller.position;
  if (!position.hasContentDimensions) return null;
  final double target = reverse ? position.minScrollExtent : position.maxScrollExtent;
  if ((position.pixels - target).abs() < 1) return null;
  return controller.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
}
