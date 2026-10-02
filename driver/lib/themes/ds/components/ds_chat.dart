import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';

import '../tokens/ds_tokens.dart';

/// Keeps the newest chat message in view while the keyboard is in use.
///
/// Wrap the message list of a chat screen with it. It scrolls the list to the
/// newest message when the keyboard appears (or grows) and when the user types
/// in [textController], so the conversation never hides behind the composer.
/// Chat lists are usually `reverse: true` – newest at the bottom – in which
/// case "newest" is `minScrollExtent`; set [reverse] to false for a list that
/// grows downwards.
///
/// The keyboard is read from the window itself, not from [MediaQuery]: a
/// chat that sits inside another Scaffold's body (a dashboard tab or drawer
/// page) gets a `MediaQuery` with the keyboard inset already removed, yet it
/// still has to react to the keyboard. Every scroll is guarded by
/// `hasClients`, so the list can be loading, empty or not built yet.
///
/// ```dart
/// body: DsChatAutoScroll(
///   controller: controller.scrollController.value,
///   textController: controller.messageController.value,
///   child: FirestorePagination(reverse: true, controller: controller.scrollController.value, ...),
/// ),
/// ```
class DsChatAutoScroll extends StatefulWidget {
  final ScrollController controller;
  final TextEditingController? textController;
  final bool reverse;
  final Widget child;

  const DsChatAutoScroll({super.key, required this.controller, this.textController, this.reverse = true, required this.child});

  @override
  State<DsChatAutoScroll> createState() => _DsChatAutoScrollState();
}

class _DsChatAutoScrollState extends State<DsChatAutoScroll> with WidgetsBindingObserver {
  FlutterView? _view;
  double _keyboard = 0;
  String _text = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text = widget.textController?.text ?? '';
    widget.textController?.addListener(_onText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final view = View.maybeOf(context);
    if (view != _view) {
      _view = view;
      _keyboard = _keyboardHeight();
    }
  }

  @override
  void didUpdateWidget(covariant DsChatAutoScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textController != widget.textController) {
      oldWidget.textController?.removeListener(_onText);
      _text = widget.textController?.text ?? '';
      widget.textController?.addListener(_onText);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.textController?.removeListener(_onText);
    super.dispose();
  }

  double _keyboardHeight() {
    final view = _view;
    if (view == null || view.devicePixelRatio == 0) return 0;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final keyboard = _keyboardHeight();
    final opening = keyboard > _keyboard;
    _keyboard = keyboard;
    // The viewport shrinks on the next layout; scroll once it has.
    if (opening) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNewest(animate: false));
  }

  void _onText() {
    final text = widget.textController?.text ?? '';
    // Ignore cursor / selection moves; only typing counts. A cleared field
    // (after send) is handled by the screen's own send logic.
    if (text == _text) return;
    _text = text;
    if (text.isEmpty) return;
    _scrollToNewest(animate: true);
  }

  void _scrollToNewest({required bool animate}) {
    if (!mounted || !widget.controller.hasClients) return;
    for (final position in widget.controller.positions) {
      if (!position.hasContentDimensions) continue;
      final target = widget.reverse ? position.minScrollExtent : position.maxScrollExtent;
      if ((position.pixels - target).abs() < 0.5) continue;
      final duration = DsMotion.of(context, DsMotion.fast);
      if (animate && duration > Duration.zero) {
        position.animateTo(target, duration: duration, curve: DsMotion.standard);
      } else {
        position.jumpTo(target);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
