import 'package:customer/themes/ds/ds.dart';
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

/// Pill composer used by the chat and support screens.
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
