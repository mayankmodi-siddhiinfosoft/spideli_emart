import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/chat_scroll.dart';

/// Shared pieces of the store's chat screens (order / admin chat and help &
/// support): the thread layout that keeps the composer above the keyboard, and
/// the two composers. Pure presentation — no controller access.

/// Body of a chat screen: the message list fills the space, the composer sits
/// directly under it.
///
/// Put this in the Scaffold's **body** (never the composer in
/// `bottomNavigationBar`): the Scaffold then lays the body out above the
/// keyboard (`resizeToAvoidBottomInset`), so the composer rides up with the
/// keyboard and the inset is applied exactly once, by the Scaffold. With the
/// keyboard closed the composer's own `SafeArea` keeps it clear of the home
/// indicator / gesture bar; with it open that padding is already zero.
///
/// It also keeps the newest message in view: when the keyboard opens and when
/// the user types, the thread is moved to its newest message (every scroll is
/// guarded with `hasClients`).
class ChatThreadLayout extends StatefulWidget {
  /// The message list (usually a reversed `FirestorePagination`).
  final Widget messages;

  /// The input row, usually a [ChatComposer].
  final Widget composer;

  /// The message list's controller, used to bring the newest message back
  /// into view.
  final ScrollController? scrollController;

  /// The composer's text controller: typing scrolls to the newest message.
  final TextEditingController? textController;

  /// Whether the message list is reversed (newest at `minScrollExtent`).
  final bool reverse;

  /// Constrain & center the message list on wide screens; the composer bar
  /// stays full width and centers its own content.
  final double? maxContentWidth;

  const ChatThreadLayout({super.key, required this.messages, required this.composer, this.scrollController, this.textController, this.reverse = true, this.maxContentWidth = DsLayout.contentMax});

  @override
  State<ChatThreadLayout> createState() => _ChatThreadLayoutState();
}

class _ChatThreadLayoutState extends State<ChatThreadLayout> with WidgetsBindingObserver {
  double _keyboard = 0;
  String _text = '';
  bool _pending = false;
  bool _scrolling = false;

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
    _keyboard = _keyboardInset();
  }

  @override
  void didUpdateWidget(covariant ChatThreadLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textController != widget.textController) {
      oldWidget.textController?.removeListener(_onText);
      _text = widget.textController?.text ?? '';
      widget.textController?.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.textController?.removeListener(_onText);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The keyboard height, read from the view: inside a Scaffold body the
  /// inset has already been consumed (it reads 0 there).
  double _keyboardInset() {
    final view = View.maybeOf(context);
    if (view == null) return 0;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final double inset = _keyboardInset();
    final bool opening = inset > _keyboard;
    _keyboard = inset;
    if (opening) _showLatest();
  }

  void _onText() {
    final String text = widget.textController?.text ?? '';
    if (text == _text) return; // selection / composing-only change
    _text = text;
    if (text.isNotEmpty) _showLatest();
  }

  /// After this frame's layout (the list has its new size by then). The
  /// keyboard reports a new inset on every frame while it slides in, so one
  /// call is batched per frame and a running scroll is never restarted.
  void _showLatest() {
    final ScrollController? controller = widget.scrollController;
    if (controller == null || _pending || _scrolling) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted) return;
      final Future<void>? scroll = showChatLatest(controller, reverse: widget.reverse);
      if (scroll == null) return;
      _scrolling = true;
      scroll.whenComplete(() => _scrolling = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget messages = widget.messages;
    if (widget.maxContentWidth != null) messages = DsResponsive(maxWidth: widget.maxContentWidth!, child: messages);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The composer below owns the bottom safe area.
        Expanded(
          child: MediaQuery.removePadding(context: context, removeBottom: true, child: messages),
        ),
        widget.composer,
      ],
    );
  }
}

/// Sticky message composer of the order / admin chat: attach button, pill
/// text field and send button (filled once there is text).
///
/// Place it with [ChatThreadLayout] (in the Scaffold body): it does not add
/// the keyboard inset itself, the Scaffold already lifts the body.
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  const ChatComposer({super.key, required this.controller, required this.onAttach, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final pill = OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: c.isDark ? c.border : c.surfaceAlt));
    return DsStickyBar(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DsIconButton(
            icon: Icons.add_photo_alternate_outlined,
            semanticLabel: 'Send Media'.tr,
            variant: DsIconButtonVariant.tonal,
            size: 44,
            onPressed: onAttach,
          ),
          const DsGap(DsSpace.sm),
          Expanded(
            child: TextField(
              textInputAction: TextInputAction.send,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              controller: controller,
              cursorColor: c.brand,
              style: t.bodyStrong.withColor(c.textPrimary),
              decoration: DsInputDecoration.of(
                context,
                hint: 'Type message here....'.tr,
                contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: DsSpace.md),
              ).copyWith(
                border: pill,
                enabledBorder: pill,
                focusedBorder: OutlineInputBorder(borderRadius: DsRadius.brPill, borderSide: BorderSide(color: c.brand, width: 1.6)),
              ),
              onSubmitted: (value) async {
                onSend();
              },
            ),
          ),
          const DsGap(DsSpace.sm),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.isNotEmpty;
              return AnimatedSwitcher(
                duration: DsMotion.of(context, DsMotion.fast),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: DsIconButton(
                  key: ValueKey(hasText),
                  icon: Icons.send_rounded,
                  semanticLabel: 'Send'.tr,
                  size: 44,
                  variant: hasText ? DsIconButtonVariant.filled : DsIconButtonVariant.tonal,
                  onPressed: onSend,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Composer of the Help & Support thread: attach button, pill text field and
/// an always-filled send button.
///
/// Place it with [ChatThreadLayout] (in the Scaffold body): it does not add
/// the keyboard inset itself, the Scaffold already lifts the body.
class HelpSupportComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final ValueChanged<String> onSubmitted;
  const HelpSupportComposer({super.key, required this.controller, required this.onAttach, required this.onSend, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsStickyBar(
      child: Row(
        children: [
          DsIconButton(
            icon: Icons.add_photo_alternate_outlined,
            semanticLabel: 'Send Media'.tr,
            variant: DsIconButtonVariant.tonal,
            size: 44,
            onPressed: onAttach,
          ),
          const DsGap(DsSpace.sm),
          Expanded(
            child: TextField(
              style: t.body.withColor(c.textPrimary),
              textInputAction: TextInputAction.send,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              controller: controller,
              cursorColor: c.brand,
              minLines: 1,
              maxLines: 1,
              decoration:
                  DsInputDecoration.of(
                    context,
                    hint: 'Start typing with admin...'.tr,
                    contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.xl, vertical: 14),
                  ).copyWith(
                    border: OutlineInputBorder(
                      borderRadius: DsRadius.brPill,
                      borderSide: BorderSide(color: c.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: DsRadius.brPill,
                      borderSide: BorderSide(color: c.isDark ? c.border : c.surfaceAlt),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: DsRadius.brPill,
                      borderSide: BorderSide(color: c.brand, width: 1.4),
                    ),
                  ),
              onSubmitted: onSubmitted,
            ),
          ),
          const DsGap(DsSpace.sm),
          DsIconButton(
            icon: Icons.send_rounded,
            semanticLabel: 'Send'.tr,
            variant: DsIconButtonVariant.filled,
            size: 44,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
