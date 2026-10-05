import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/pod_otp.dart';
import 'package:vendor/utils/pod_otp_service.dart';

/// Proof of delivery for an order the store completes itself
/// (`.claude/POD-OTP-CONTRACT.md`, "Store app"): one it delivers with its own
/// delivery man, and a takeaway the customer collects at the counter (the
/// customer's "pickup code", 5 Oct 2026).
///
/// [run] returns true only once the customer's delivery code is verified for
/// [OrderModel] — and then sets the order's `pod` — so the caller can run its
/// existing completion. An order verified earlier (its completion failed
/// afterwards) returns true at once: a retry never asks for a new code.
abstract final class DeliveryOtpFlow {
  /// Orders whose flow is open, so a double tap cannot start two.
  static final Set<String> _running = {};

  static Future<bool> run(OrderModel order) async {
    final String orderId = order.id ?? '';
    if (orderId.isEmpty || _running.contains(orderId)) return false;
    if (order.pod?.isVerified == true) return true;
    _running.add(orderId);
    try {
      ShowToastDialog.showLoader('Please wait...'.tr);
      final PodDeliveryMan? deliveredBy = await _deliveryMan(order);
      final String verifiedBy = FireStoreUtils.getCurrentUid();
      final PodStart start;
      try {
        start = await PodOtpService.start(order, verifiedBy: verifiedBy, deliveredBy: deliveredBy);
      } catch (e) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("${"Could not start the delivery code".tr}: $e");
        return false;
      }
      ShowToastDialog.closeLoader();
      if (start.offline) {
        ShowToastDialog.showToast(const PodCheckResult(PodCheck.offline).message);
        return false;
      }
      if (start.orderClosed) {
        ShowToastDialog.showToast(const PodCheckResult(PodCheck.orderClosed).message);
        return false;
      }
      if (start.alreadyVerified) {
        if (start.pod != null) order.pod = start.pod;
        return true;
      }
      final OrderPod? pod = await Get.bottomSheet<OrderPod>(
        DeliveryOtpSheet(order: order, initial: start.code, verifiedBy: verifiedBy, deliveredBy: deliveredBy),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
      if (pod == null || !pod.isVerified) return false;
      order.pod = pod;
      return true;
    } finally {
      _running.remove(orderId);
    }
  }

  /// The store's delivery man assigned to [order], as `pod.deliveredBy`.
  /// None for a takeaway: the customer collected it themselves.
  static Future<PodDeliveryMan?> _deliveryMan(OrderModel order) async {
    if (order.takeAway == true) return null;
    UserModel? driver = order.driver;
    final String driverId = order.driverID ?? '';
    if (driverId.isNotEmpty) {
      try {
        driver = await FireStoreUtils.getUserById(driverId) ?? driver;
      } catch (_) {
        // The copy on the order is good enough to name who delivered.
      }
    }
    if (driver == null && driverId.isEmpty) return null;
    final PodDeliveryMan man = PodDeliveryMan.of(
      id: driver?.id ?? driverId,
      firstName: driver?.firstName,
      lastName: driver?.lastName,
      countryCode: driver?.countryCode,
      phoneNumber: driver?.phoneNumber,
      photo: driver?.profilePictureURL,
    );
    return man.isEmpty ? null : man;
  }
}

/// The store types the 6-digit code the customer reads from their app.
/// Pops with the verified `pod`, or nothing when the store backs out (the
/// order is then left exactly as it was). Never shows the code.
class DeliveryOtpSheet extends StatefulWidget {
  final OrderModel order;
  final PodCode? initial;
  final String verifiedBy;
  final PodDeliveryMan? deliveredBy;

  const DeliveryOtpSheet({super.key, required this.order, required this.initial, required this.verifiedBy, required this.deliveredBy});

  @override
  State<DeliveryOtpSheet> createState() => _DeliveryOtpSheetState();
}

class _DeliveryOtpSheetState extends State<DeliveryOtpSheet> {
  final TextEditingController _entry = TextEditingController();
  late PodCode? _code = widget.initial;
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  /// The order was cancelled meanwhile: nothing can be verified any more.
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // Drives the expiry countdown and the "Get a new code" cooldown.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _entry.dispose();
    super.dispose();
  }

  bool get _busy => _verifying || _resending;

  Future<void> _verify() async {
    if (_busy) return;
    final String entered = _entry.text.trim();
    if (!PodOtp.isWellFormed(entered)) {
      setState(() => _error = const PodCheckResult(PodCheck.invalidFormat).message);
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });
    try {
      final PodVerification v = await PodOtpService.verify(widget.order, entered, verifiedBy: widget.verifiedBy, deliveredBy: widget.deliveredBy);
      if (!mounted) return;
      if (v.result.isVerified && v.pod != null) {
        Navigator.of(context).pop(v.pod);
        return;
      }
      setState(() {
        _verifying = false;
        if (v.code != null) _code = v.code;
        if (v.result.outcome == PodCheck.orderClosed) _closed = true;
        _error = v.result.message;
        if (v.result.outcome == PodCheck.wrongCode) _entry.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = "${"Could not verify the code".tr}: $e";
      });
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final PodRegeneration r = await PodOtpService.regenerate(widget.order);
      if (!mounted) return;
      if (r.result == PodResend.alreadyVerified) {
        // Verified meanwhile (e.g. by the delivery man in the Driver app):
        // pick up the recorded proof and finish, no new code.
        final PodStart start = await PodOtpService.start(widget.order, verifiedBy: widget.verifiedBy, deliveredBy: widget.deliveredBy);
        if (!mounted) return;
        if (start.alreadyVerified && start.pod != null) {
          Navigator.of(context).pop(start.pod);
          return;
        }
      }
      setState(() {
        _resending = false;
        if (r.code != null) _code = r.code;
        _now = DateTime.now();
        if (r.result == PodResend.orderClosed) _closed = true;
        if (r.result == PodResend.allowed) {
          _entry.clear();
          _info = PodOtp.resendMessage(r.result);
        } else {
          _error = PodOtp.resendMessage(r.result, wait: r.wait);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _error = "${"Could not generate a new code".tr}: $e";
      });
    }
  }

  /// Whole seconds, rounded up: a disabled button never reads "0s".
  static int _ceilSeconds(Duration d) => d.isNegative ? 0 : (d.inMilliseconds + 999) ~/ 1000;

  static String _mmss(Duration d) {
    final int s = _ceilSeconds(d);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final PodCode? code = _code;
    final bool spent = _closed || code == null || code.isExpiredAt(_now);
    final PodResend resend = _closed ? PodResend.orderClosed : PodOtp.canResend(code, _now);
    final Duration wait = PodOtp.cooldownLeft(code, _now);

    final String resendLabel = switch (resend) {
      PodResend.coolingDown => "${"Get a new code".tr} (${_ceilSeconds(wait)}s)",
      PodResend.limitReached => "No new codes left".tr,
      _ => "Get a new code".tr,
    };

    // Why the current code cannot be used, when it cannot.
    final String? spentMessage = _closed
        ? const PodCheckResult(PodCheck.orderClosed).message
        : code == null
        ? const PodCheckResult(PodCheck.noCode).message
        : !spent
        ? null
        : code.isLockedByAttempts
        ? const PodCheckResult(PodCheck.tooManyAttempts).message
        : const PodCheckResult(PodCheck.expired).message;

    final bool pickup = widget.order.takeAway == true;
    return DsSheet(
      title: pickup ? "Enter the pickup code".tr : "Enter the delivery code".tr,
      subtitle: "Ask the customer for the 6-digit code shown in their app.".tr,
      showClose: true,
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsButton.primary(label: "Verify".tr, icon: Icons.verified_rounded, expand: true, loading: _verifying, onPressed: spent || _busy ? null : _verify),
          DsGap.sm,
          DsButton.ghost(
            label: resendLabel,
            icon: Icons.refresh_rounded,
            expand: true,
            loading: _resending,
            onPressed: resend == PodResend.allowed && !_busy ? _resend : null,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsTextField(
            label: pickup ? "Pickup code".tr : "Delivery code".tr,
            hint: "6-digit code".tr,
            controller: _entry,
            enabled: !spent,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(PodRules.codeLength)],
            autofillHints: const [AutofillHints.oneTimeCode],
            prefixIcon: Icons.pin_outlined,
            errorText: _error,
            onSubmitted: (_) => _verify(),
            bottomSpacing: DsSpace.sm,
          ),
          if (spentMessage != null)
            DsInlineAlert(tone: DsTone.warning, message: spentMessage)
          else if (code?.deadline != null)
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: c.textMuted),
                DsGap.xs,
                Expanded(
                  child: Text(
                    "Code expires in @time".trParams({'time': _mmss((code!.deadline ?? _now).difference(_now))}),
                    style: t.bodySm,
                  ),
                ),
              ],
            ),
          if (_info != null) ...[DsGap.sm, DsInlineAlert(tone: DsTone.success, message: _info!)],
          if (resend == PodResend.limitReached)
            ...[DsGap.sm, Text(PodOtp.resendMessage(PodResend.limitReached), style: t.caption)]
          else if (code != null && !_closed)
            ...[
              DsGap.sm,
              Text(
                "New codes left: @n / @max".trParams({'n': '${code.regenerationsLeft}', 'max': '${PodRules.maxRegenerations}'}),
                textAlign: TextAlign.center,
                style: t.caption,
              ),
            ],
        ],
      ),
    );
  }
}
