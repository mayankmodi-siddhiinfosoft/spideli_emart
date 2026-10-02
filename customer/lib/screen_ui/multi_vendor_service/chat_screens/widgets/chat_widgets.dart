import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/chat_scroll.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared presentation pieces for the chat archetype (**J**): message rows,
/// bubbles, the composer and inbox rows. Pure presentation — no controller
/// access and no observable reads, so they are safe inside `Obx` / `GetX`
/// builders and lazy list item builders.

/// One message row: bubble (or media) + optional avatar, then the meta line.
class ChatMessageRow extends StatelessWidget {
  final bool isMe;

  /// The bubble or media widget.
  final Widget bubble;

  /// Small avatar shown next to the bubble (help & support).
  final Widget? avatar;

  /// "Admin" style label above the meta line.
  final String? senderLabel;
  final String timeLabel;

  /// Delivery ticks for own messages (null → hidden).
  final bool? seen;

  const ChatMessageRow({super.key, required this.isMe, required this.bubble, required this.timeLabel, this.avatar, this.senderLabel, this.seen});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: EdgeInsets.only(left: isMe ? 64 : DsSpace.md, right: isMe ? DsSpace.md : 64, top: DsSpace.sm, bottom: DsSpace.sm),
      child: Align(
        alignment: isMe ? Alignment.topRight : Alignment.topLeft,
        child: Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar == null)
              bubble
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: isMe
                    ? [Flexible(child: bubble), const DsGap(DsSpace.sm), avatar!]
                    : [avatar!, const DsGap(DsSpace.sm), Flexible(child: bubble)],
              ),
            const DsGap(DsSpace.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (senderLabel != null) ...[
                  Text(senderLabel!, style: t.labelSm),
                  const DsGap(DsSpace.sm),
                ],
                Text(timeLabel, style: t.caption.tabular),
                if (seen != null) ...[
                  const DsGap(DsSpace.xs),
                  Icon(seen == true ? Icons.done_all_rounded : Icons.done_rounded, size: 14, color: seen == true ? c.brandStrong : c.textMuted),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Text bubble: brand fill for the customer, surface + hairline for the other
/// side, with one sharp corner on the sender's edge.
class ChatTextBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  final double maxWidthFactor;

  const ChatTextBubble({super.key, required this.isMe, required this.text, this.maxWidthFactor = 0.75});

  static BorderRadius radiusFor(bool isMe) => BorderRadius.only(
    topLeft: const Radius.circular(DsRadius.lg),
    topRight: const Radius.circular(DsRadius.lg),
    bottomLeft: Radius.circular(isMe ? DsRadius.lg : DsRadius.xs),
    bottomRight: Radius.circular(isMe ? DsRadius.xs : DsRadius.lg),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * maxWidthFactor),
      decoration: BoxDecoration(
        color: isMe ? c.brand : c.surface,
        borderRadius: radiusFor(isMe),
        border: isMe ? null : Border.all(color: c.border),
        boxShadow: isMe ? null : DsShadows.xs(context),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
      child: Text(
        text,
        softWrap: true,
        maxLines: null,
        style: DsTypography.body.copyWith(color: isMe ? c.onBrand : c.textPrimary, fontSize: 15),
      ),
    );
  }
}

/// Media bubble (image or video thumbnail) with the same corner language.
class ChatMediaBubble extends StatelessWidget {
  final bool isMe;
  final Widget child;
  final VoidCallback onTap;
  final bool isVideo;
  final double maxWidth;
  final String semanticLabel;

  const ChatMediaBubble({
    super.key,
    required this.isMe,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.isVideo = false,
    this.maxWidth = 220,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 80, maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: ChatTextBubble.radiusFor(isMe),
          child: Stack(
            alignment: Alignment.center,
            children: [
              child,
              if (isVideo)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: c.scrim, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, size: 30, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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

/// Pill composer used by the chat and support screens.
///
/// Place it with [ChatThreadLayout] (in the Scaffold body). It is a plain
/// [DsStickyBar]: it does not add the keyboard inset itself, because the
/// Scaffold already lays the body out above the keyboard.
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final ValueChanged<String> onSubmitted;

  /// Custom attach glyph (keeps the screen's original asset).
  final Widget? attachIcon;

  /// Custom send glyph.
  final Widget? sendIcon;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onAttach,
    required this.onSend,
    required this.onSubmitted,
    this.attachIcon,
    this.sendIcon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsStickyBar(
      // Lives in the Scaffold BODY (see ChatThreadLayout), which the Scaffold
      // already lays out above the keyboard — so no `avoidKeyboard` here: the
      // inset must be applied exactly once (bug #13 had it in the bottom bar).
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          DsIconButton(
            icon: attachIcon == null ? Icons.add_photo_alternate_outlined : null,
            semanticLabel: 'Send Media'.tr,
            variant: DsIconButtonVariant.tonal,
            size: 44,
            onPressed: onAttach,
            child: attachIcon,
          ),
          const DsGap(DsSpace.sm),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 132),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brXl, border: Border.all(color: c.border)),
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
              child: TextField(
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                controller: controller,
                minLines: 1,
                maxLines: 4,
                cursorColor: c.brand,
                style: DsTypography.body.copyWith(color: c.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: hint,
                  hintStyle: DsTypography.body.copyWith(color: c.textMuted),
                ),
                onSubmitted: onSubmitted,
              ),
            ),
          ),
          const DsGap(DsSpace.sm),
          DsIconButton(
            icon: sendIcon == null ? Icons.send_rounded : null,
            semanticLabel: 'Send'.tr,
            variant: DsIconButtonVariant.filled,
            size: 48,
            onPressed: onSend,
            child: sendIcon,
          ),
        ],
      ),
    );
  }
}

/// Inbox row: avatar, name, order id and the last-activity time.
class ChatInboxRow extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String time;
  final String subtitle;
  final VoidCallback onTap;

  const ChatInboxRow({super.key, required this.name, required this.time, required this.subtitle, required this.onTap, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      margin: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xs),
      padding: const EdgeInsets.all(DsSpace.md),
      onTap: onTap,
      semanticLabel: name,
      child: Row(
        children: [
          DsAvatar(imageUrl: imageUrl, name: name, size: 48),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm)),
                    const DsGap(DsSpace.sm),
                    Text(time, style: t.caption.tabular),
                  ],
                ),
                const DsGap(DsSpace.xxs),
                Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 14, color: c.textMuted),
                    const DsGap(DsSpace.xs),
                    Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySm)),
                    Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
