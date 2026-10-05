import 'dart:async';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/cancellation_fields.dart';
import 'package:customer/models/order_model.dart';
import 'package:customer/models/order_pod.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The customer's delivery code (POD-OTP-CONTRACT), shown on the order
/// screens of an active multivendor / e-commerce order — a delivery, or a
/// takeaway ([takeAway], 5 Oct 2026: the store asks for it at the counter and
/// the card reads "Your pickup code"):
///
/// * `pending` and before `expiresAt` → "Your delivery code", the 6 digits
///   large and spaced, the share warning and a live countdown;
/// * `expired`, or `pending` past `expiresAt` → "Code expired — ask your
///   delivery partner for a new one";
/// * `verified`, missing, or anything else → nothing.
///
/// Pure: it renders the [code] it is given, so a replacement code shows the
/// moment the parent passes it. [now] is the clock (tests inject one).
class DeliveryCodeCard extends StatefulWidget {
  final OrderPodCode? code;
  final DateTime Function() now;

  /// A takeaway: pickup wording, the store asks for the code.
  final bool takeAway;

  /// Applied only while something is shown.
  final EdgeInsetsGeometry padding;

  const DeliveryCodeCard({super.key, required this.code, this.now = DateTime.now, this.takeAway = false, this.padding = EdgeInsets.zero});

  /// "Your delivery code" / "Your pickup code".
  static String titleFor({required bool takeAway}) => takeAway ? 'Your pickup code'.tr : 'Your delivery code'.tr;

  /// Who to ask for a new code once it expired.
  static String expiredFor({required bool takeAway}) => takeAway ? 'Code expired — ask the store for a new one'.tr : 'Code expired — ask your delivery partner for a new one'.tr;

  /// Who to share it with, and when.
  static String shareHintFor({required bool takeAway}) =>
      takeAway ? 'Share this code with the store only when you collect your order'.tr : 'Share this code with your delivery partner only when you receive your order'.tr;

  @override
  State<DeliveryCodeCard> createState() => _DeliveryCodeCardState();
}

class _DeliveryCodeCardState extends State<DeliveryCodeCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant DeliveryCodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Ticks once a second only while a live code is on screen.
  void _syncTicker() {
    final bool live = widget.code?.isLive(widget.now()) == true;
    if (live && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (widget.code?.isLive(widget.now()) != true) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else if (!live) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  static String _mmss(Duration d) {
    final int secs = d.inSeconds;
    final String m = (secs ~/ 60).toString().padLeft(2, '0');
    final String s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final OrderPodCode? code = widget.code;
    if (code == null) return const SizedBox.shrink();
    final DateTime now = widget.now();

    if (code.isLive(now)) {
      return Padding(padding: widget.padding, child: _LiveCode(code: code.code!, countdown: _mmss(code.remaining(now)), takeAway: widget.takeAway));
    }
    if (code.isExpired(now)) {
      return Padding(
        padding: widget.padding,
        child: DsInlineAlert(
          tone: DsTone.warning,
          icon: Icons.timer_off_outlined,
          title: DeliveryCodeCard.titleFor(takeAway: widget.takeAway),
          message: DeliveryCodeCard.expiredFor(takeAway: widget.takeAway),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _LiveCode extends StatelessWidget {
  final String code;
  final String countdown;
  final bool takeAway;

  const _LiveCode({required this.code, required this.countdown, required this.takeAway});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final List<String> digits = code.split('');
    final String title = DeliveryCodeCard.titleFor(takeAway: takeAway);

    return DsCard.tinted(
      tone: DsTone.brand,
      borderColor: c.brand.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DsIconWell(icon: Icons.lock_outline_rounded, tone: DsTone.brand, size: 36),
              const DsGap(DsSpace.sm),
              Expanded(child: Text(title, style: t.titleSm)),
              DsBadge(
                key: const ValueKey('delivery-code-countdown'),
                icon: Icons.timer_outlined,
                tone: DsTone.warning,
                label: 'Expires in @time'.trParams({'time': countdown}),
              ),
            ],
          ),
          const DsGap(DsSpace.lg),
          Semantics(
            label: '$title ${digits.join(' ')}',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < digits.length; i++) ...[
                    if (i > 0) const DsGap(DsSpace.sm),
                    Container(
                      width: 44,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brMd, border: Border.all(color: c.brand.withValues(alpha: 0.45), width: 1.4)),
                      child: Text(digits[i], style: t.metricLg.withColor(c.brandStrong)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const DsGap(DsSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.info_outline_rounded, size: 16, color: c.textSecondary)),
              const DsGap(DsSpace.xs),
              Expanded(child: Text(DeliveryCodeCard.shareHintFor(takeAway: takeAway), style: t.bodySm)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Listens to `order_pod/{orderId}` for [order] and shows [DeliveryCodeCard].
///
/// Subscribes only for an active delivery order of the signed-in customer
/// whose `pod` is not verified yet ([shouldWatch]), and drops any document
/// that does not name this order and this customer, so a code is never shown
/// for someone else's order or after verification. Read-only.
class DeliveryCodeWatcher extends StatefulWidget {
  final OrderModel order;
  final EdgeInsetsGeometry padding;

  const DeliveryCodeWatcher({super.key, required this.order, this.padding = EdgeInsets.zero});

  /// An active (not finished) order of [uid] with no verified proof of
  /// delivery yet — a delivery or, since 5 Oct 2026, a takeaway (the store
  /// asks for the pickup code at the counter).
  static bool shouldWatch(OrderModel order, String? uid) {
    final String id = (order.id ?? '').trim();
    if (uid == null || uid.isEmpty || id.isEmpty) return false;
    if (order.authorID != uid) return false;
    if (order.pod?.isVerified == true) return false;
    final String? status = order.status;
    if (status == Constant.orderCompleted || CancellationSummary.isFinalStatus(status)) return false;
    return true;
  }

  @override
  State<DeliveryCodeWatcher> createState() => _DeliveryCodeWatcherState();
}

class _DeliveryCodeWatcherState extends State<DeliveryCodeWatcher> {
  StreamSubscription? _sub;

  /// The order id currently subscribed to (null when not watching).
  String? _watching;
  OrderPodCode? _code;

  String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DeliveryCodeWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _sync() {
    final String? uid = _uid;
    final String? target = DeliveryCodeWatcher.shouldWatch(widget.order, uid) ? widget.order.id!.trim() : null;
    if (target == _watching) return;
    _sub?.cancel();
    _sub = null;
    _watching = target;
    _code = null;
    if (target == null) return;
    _sub = FireStoreUtils.fireStore
        .collection(CollectionName.orderPod)
        .doc(target)
        .snapshots()
        .listen(
          (snap) {
            final data = snap.data();
            OrderPodCode? next;
            if (data != null) {
              final parsed = OrderPodCode.fromJson(data);
              if (parsed.belongsTo(orderId: target, uid: uid!)) next = parsed;
            }
            if (mounted && _watching == target) setState(() => _code = next);
          },
          // Denied by rules / offline: show nothing rather than a stale code.
          onError: (_) {
            if (mounted && _watching == target) setState(() => _code = null);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_watching == null) return const SizedBox.shrink();
    return DeliveryCodeCard(code: _code, takeAway: widget.order.takeAway == true, padding: widget.padding);
  }
}
