import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/screen_ui/multi_vendor_service/chat_screens/widgets/chat_widgets.dart';
import 'package:customer/service/finance_chat_service.dart';
import 'package:customer/service/finance_group_service.dart';
import 'package:customer/service/finance_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:customer/utils/finance_chat_rules.dart';
import 'package:customer/utils/finance_rules.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

DateTime? _at(dynamic v) => FinanceGroupService.toDate(v);

/// "14:30" today, "Yesterday", "05 Oct" this year, else "05 Oct 2025".
String _when(DateTime d, DateTime now) {
  final DateTime day = DateTime(d.year, d.month, d.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  if (day == today) return ltr(DateFormat('HH:mm').format(d));
  if (day == today.subtract(const Duration(days: 1))) return "Yesterday".tr;
  return ltr(DateFormat(d.year == now.year ? 'dd MMM' : 'dd MMM yyyy').format(d));
}

/// The day above the messages of that day: "Today", "Yesterday", "05 Oct 2026".
String _dayLabel(DateTime d, DateTime now) {
  final DateTime day = DateTime(d.year, d.month, d.day);
  final DateTime today = DateTime(now.year, now.month, now.day);
  if (day == today) return "Today".tr;
  if (day == today.subtract(const Duration(days: 1))) return "Yesterday".tr;
  return ltr(DateFormat('dd MMM yyyy').format(d));
}

/// The name of the Spideli account [uid], looked up once ([FinancePeople],
/// cached for the session); null while unknown.
class FinancePersonName extends StatelessWidget {
  final String uid;
  final Widget Function(BuildContext context, String? name) builder;

  const FinancePersonName({super.key, required this.uid, required this.builder});

  @override
  Widget build(BuildContext context) {
    final String? known = FinancePeople.cachedName(uid);
    if (known != null) return builder(context, known);
    return FutureBuilder<FinancePerson?>(future: FinancePeople.byId(uid), builder: (context, snap) => builder(context, snap.data?.name));
  }
}

/// Spideli Finance > Messages: the user's direct conversations and the group
/// conversation of each of their tontines, latest first, with the last
/// message, its time and an unread dot.
class FinanceChatsScreen extends StatefulWidget {
  const FinanceChatsScreen({super.key});

  @override
  State<FinanceChatsScreen> createState() => _FinanceChatsScreenState();
}

class _FinanceChatsScreenState extends State<FinanceChatsScreen> {
  late Stream<List<FinanceChatEntry>> _chats = FinanceChatService.myChats();

  @override
  Widget build(BuildContext context) {
    return FinScaffold(
      title: "Messages".tr,
      body: StreamBuilder<List<FinanceChatEntry>>(
        stream: _chats,
        builder: (context, snap) {
          if (snap.hasError) {
            return FinBody(children: [
              FinState.error("Could not load your conversations.".tr, onRetry: () => setState(() => _chats = FinanceChatService.myChats())),
            ]);
          }
          if (!snap.hasData) return FinBody(children: [FinState.loading(rows: 4)]);
          final entries = snap.data!;
          if (entries.isEmpty) {
            return FinBody(children: [
              FinState.empty(
                Icons.forum_outlined,
                "No conversation yet".tr,
                message: "Write to your tontine's group, or message a member of your tontines and savings goals from their member list.".tr,
              ),
            ]);
          }
          return FinBody(children: [
            FinSection(top: 0, divided: true, children: [for (final e in entries) _ChatRow(entry: e)]),
          ]);
        },
      ),
    );
  }
}

/// One conversation of the list.
class _ChatRow extends StatelessWidget {
  final FinanceChatEntry entry;

  const _ChatRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final String me = FinanceService.uid;
    final chat = entry.chat;
    final t = entry.tontine;
    if (t != null) return _row(context, title: t.name, group: true, open: () => Get.to(() => FinanceChatScreen(target: FinanceChatTarget.tontine(t))));
    final String other = chat?.otherOf(me) ?? '';
    return FinancePersonName(
      uid: other,
      builder: (context, name) => _row(
        context,
        title: name ?? "Member".tr,
        group: false,
        open: () => Get.to(() => FinanceChatScreen(target: FinanceChatTarget.direct(me, other, name ?? "Member".tr))),
      ),
    );
  }

  Widget _row(BuildContext context, {required String title, required bool group, required VoidCallback open}) {
    final c = DsColors.of(context);
    final chat = entry.chat;
    final String me = FinanceService.uid;
    final bool unread = chat?.unreadFor(me) ?? false;
    final DateTime? at = chat?.lastAt;
    Widget tile(String? subtitle) => FinListTile(
          icon: group ? Icons.groups_2_outlined : Icons.person_outline_rounded,
          iconTone: unread ? DsTone.brand : DsTone.neutral,
          title: title,
          subtitle: subtitle,
          onTap: open,
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (at != null) Text(_when(at, DateTime.now()), style: DsTypography.caption.copyWith(color: unread ? FinColors.brand(context) : c.textSecondary).tabular),
              if (unread) ...[
                const DsGap(DsSpace.xs),
                Semantics(
                  label: "Unread".tr,
                  child: Container(width: 10, height: 10, decoration: BoxDecoration(color: FinColors.brand(context), shape: BoxShape.circle)),
                ),
              ],
            ],
          ),
        );
    if (chat == null || !chat.hasMessages) return tile("No messages yet".tr);
    if (chat.lastSenderId == me) return tile('${"You".tr}: ${chat.lastText}');
    if (!group) return tile(chat.lastText);
    return FinancePersonName(uid: chat.lastSenderId, builder: (context, name) => tile(name == null || name.isEmpty ? chat.lastText : '$name: ${chat.lastText}'));
  }
}

/// A conversation: the messages live (newest at the bottom, the day above
/// each day's first message, the sender's name in a group) and the send box.
/// Text only, at most [FinanceChatRules.maxLength] characters.
class FinanceChatScreen extends StatefulWidget {
  final FinanceChatTarget target;

  const FinanceChatScreen({super.key, required this.target});

  @override
  State<FinanceChatScreen> createState() => _FinanceChatScreenState();
}

class _FinanceChatScreenState extends State<FinanceChatScreen> {
  late Stream<FinanceChat?> _chat = FinanceChatService.chat(widget.target.chatId);
  Stream<List<Map<String, dynamic>>>? _messages;
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// A read receipt is being written (one at a time).
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  @override
  void dispose() {
    _text.removeListener(_changed);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Marks the conversation read while it is open and has news.
  void _read(FinanceChat chat) {
    if (_marking || !chat.unreadFor(FinanceService.uid)) return;
    _marking = true;
    FinanceChatService.markRead(chat.id).whenComplete(() => _marking = false);
  }

  Future<void> _send({required bool known}) async {
    final String text = _text.text;
    if (FinanceChatRules.clean(text) == null) return;
    // The message shows at once (the local copy); the box is free for the next one.
    _text.clear();
    try {
      await FinanceChatService.send(widget.target, text);
      // The first message created the conversation: read it from now on.
      if (!known && mounted) setState(() => _chat = FinanceChatService.chat(widget.target.chatId));
    } on FinanceException catch (e) {
      if (_text.text.isEmpty) _text.text = text;
      ShowToastDialog.showToast((e.reason == 'permission_denied' ? "You cannot write in this conversation." : "Your message was not sent. Please try again.").tr);
    } catch (_) {
      if (_text.text.isEmpty) _text.text = text;
      ShowToastDialog.showToast("Your message was not sent. Please try again.".tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    return FinScaffold(
      title: target.title,
      subtitle: target.isGroup ? "Tontine group".tr : null,
      body: StreamBuilder<FinanceChat?>(
        stream: _chat,
        builder: (context, snap) {
          if (snap.hasError) {
            return FinBody(children: [
              FinState.error("Could not load this conversation.".tr, onRetry: () => setState(() => _chat = FinanceChatService.chat(target.chatId))),
            ]);
          }
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) return FinBody(children: [FinState.loading(rows: 4)]);
          final chat = snap.data;
          if (chat != null) {
            _messages ??= FinanceChatService.messages(target.chatId);
            WidgetsBinding.instance.addPostFrameCallback((_) => _read(chat));
          }
          return ChatThreadLayout(
            scrollController: _scroll,
            textController: _text,
            messages: chat == null ? _empty(context) : _list(context),
            composer: _composer(context, known: chat != null),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.xl),
          child: FinState.empty(
            Icons.chat_bubble_outline_rounded,
            "No messages yet".tr,
            message: (widget.target.isGroup ? "Write the first message to the members of this tontine." : "Write the first message.").tr,
          ),
        ),
      );

  Widget _list(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messages,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: FinState.error("Could not load the messages.".tr, onRetry: () => setState(() => _messages = FinanceChatService.messages(widget.target.chatId))),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) return _empty(context);
        final now = DateTime.now();
        final String me = FinanceService.uid;
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final m = list[i];
            // A message being sent has no server time yet: it is now.
            final DateTime at = _at(m['createdAt']) ?? now;
            final DateTime? older = i + 1 < list.length ? (_at(list[i + 1]['createdAt']) ?? now) : null;
            final bool mine = m['senderId'] == me;
            final String name = (m['senderName'] ?? '').toString().trim();
            final bool sending = m['createdAt'] == null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (FinanceChatRules.newDay(older, at)) _DaySeparator(label: _dayLabel(at, now)),
                ChatMessageRow(
                  isMe: mine,
                  bubble: ChatTextBubble(isMe: mine, text: (m['text'] ?? '').toString()),
                  senderLabel: widget.target.isGroup && !mine ? (name.isEmpty ? "Member".tr : name) : null,
                  timeLabel: sending ? "Sending…".tr : ltr(DateFormat('HH:mm').format(at)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _composer(BuildContext context, {required bool known}) {
    final c = DsColors.of(context);
    final int length = _text.text.trim().length;
    final bool tooLong = length > FinanceChatRules.maxLength;
    final bool ready = length > 0 && !tooLong;
    return DsStickyBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (length > FinanceChatRules.maxLength - 100)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.xs),
              child: Text(
                "@count of at most @max characters".trParams({'count': '$length', 'max': '${FinanceChatRules.maxLength}'}),
                style: DsTypography.caption.copyWith(color: tooLong ? c.danger : c.textSecondary).tabular,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48, maxHeight: 132),
                  decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brXl, border: Border.all(color: tooLong ? c.danger : c.border)),
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    cursorColor: FinColors.brand(context),
                    style: DsTypography.body.copyWith(color: c.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: "Write a message".tr,
                      hintStyle: DsTypography.body.copyWith(color: c.textMuted),
                    ),
                  ),
                ),
              ),
              const DsGap(DsSpace.sm),
              DsIconButton(
                icon: Icons.send_rounded,
                semanticLabel: "Send".tr,
                variant: DsIconButtonVariant.filled,
                size: 48,
                onPressed: ready ? () => _send(known: known) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final String label;

  const _DaySeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
      child: Center(
        child: Semantics(
          header: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xxs),
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brPill),
            child: Text(label, style: DsTypography.caption.copyWith(color: c.textSecondary)),
          ),
        ),
      ),
    );
  }
}

/// The Messages entry: an icon button to [FinanceChatsScreen] with a dot
/// while a conversation has unread messages (for app bars and lists).
class FinanceChatsButton extends StatefulWidget {
  const FinanceChatsButton({super.key});

  @override
  State<FinanceChatsButton> createState() => _FinanceChatsButtonState();
}

class _FinanceChatsButtonState extends State<FinanceChatsButton> {
  late final Stream<List<FinanceChatEntry>> _chats = FinanceChatService.myChats();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FinanceChatEntry>>(
      stream: _chats,
      builder: (context, snap) {
        final String me = FinanceService.uid;
        final bool unread = (snap.data ?? const []).any((e) => e.chat?.unreadFor(me) ?? false);
        return DsIconButton(
          icon: Icons.forum_outlined,
          semanticLabel: (unread ? "Messages, unread" : "Messages").tr,
          showDot: unread,
          onPressed: () => Get.to(() => const FinanceChatsScreen()),
        );
      },
    );
  }
}
