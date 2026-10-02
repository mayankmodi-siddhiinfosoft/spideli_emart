import 'dart:async';

import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/delivery_pod.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/services/delivery_pod_rules.dart';
import 'package:driver/services/delivery_pod_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

/// Proof of delivery by customer OTP (`.claude/POD-OTP-CONTRACT.md`): the
/// driver types the 6-digit code the customer reads from their app. The code
/// is never shown here.
///
/// Returns the order's verified `pod` record, or null when the driver backed
/// out — in which case nothing is completed.
Future<DeliveryPod?> showDeliveryOtpSheet(BuildContext context, {required bool isDark, required OrderModel order, required PodState initial}) {
  return showModalBottomSheet<DeliveryPod>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: DsColors.resolve(isDark).scrim,
    builder: (_) => _DeliveryOtpSheet(order: order, initial: initial),
  );
}

class _DeliveryOtpSheet extends StatefulWidget {
  final OrderModel order;
  final PodState initial;

  const _DeliveryOtpSheet({required this.order, required this.initial});

  @override
  State<_DeliveryOtpSheet> createState() => _DeliveryOtpSheetState();
}

class _DeliveryOtpSheetState extends State<_DeliveryOtpSheet> {
  final PinInputController _pin = PinInputController();
  late PodState _state;
  String? _error;
  bool _verifying = false;
  bool _requesting = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _state = widget.initial;
    _error = _messageForState(_state);
    // Drives the visible cooldown and expiry countdowns.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pin.dispose();
    super.dispose();
  }

  /// Why there is no live code to type, or null when there is one.
  String? _messageForState(PodState s) {
    final DateTime now = DateTime.now();
    if (s.refused?.kind == PodNewCodeKind.capReached) return DeliveryPodRules.capReachedMessage.tr;
    if (s.status == null) return DeliveryPodRules.noCodeMessage.tr;
    if (s.attempts >= DeliveryPodRules.maxAttempts) return DeliveryPodRules.tooManyAttemptsMessage.tr;
    if (!s.isLive(now)) return DeliveryPodRules.expiredMessage.tr;
    return null;
  }

  Future<void> _verify() async {
    final String entered = _pin.text.trim();
    if (entered.length != DeliveryPodRules.codeLength) {
      setState(() => _error = "Enter the 6-digit code from the customer's app.".tr);
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final PodVerifyOutcome outcome = await DeliveryPodService.verify(widget.order, entered);
      if (!mounted) return;
      if (outcome.check.isSuccess) {
        Navigator.of(context).pop(outcome.pod);
        return;
      }
      _pin.clear();
      _pin.triggerError();
      setState(() {
        _state = outcome.state;
        _error = outcome.check.result == PodCheckResult.wrong
            ? "${'Incorrect code.'.tr} ${outcome.check.attemptsLeft} ${'attempts left.'.tr}"
            : DeliveryPodRules.messageFor(outcome.check).tr;
      });
    } on PodOfflineException {
      if (mounted) setState(() => _error = DeliveryPodRules.offlineMessage.tr);
    } catch (e) {
      if (mounted) setState(() => _error = "The code could not be checked. Please try again.".tr);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _newCode() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final PodState s = await DeliveryPodService.requestCode(widget.order, forceNew: true);
      if (!mounted) return;
      if (s.isVerified) {
        Navigator.of(context).pop(DeliveryPod(method: 'otp', status: DeliveryPodRules.statusVerified, verifiedAt: s.verifiedAt));
        return;
      }
      _pin.clear();
      setState(() {
        _state = s;
        _error = s.refused?.kind == PodNewCodeKind.capReached ? DeliveryPodRules.capReachedMessage.tr : null;
      });
      if (s.created) ShowToastDialog.showToast("A new code was sent to the customer's app.".tr);
    } on PodOfflineException {
      if (mounted) setState(() => _error = DeliveryPodRules.offlineMessage.tr);
    } catch (e) {
      if (mounted) setState(() => _error = "A new code could not be created. Please try again.".tr);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  static String _mmss(Duration d) {
    final int s = d.inSeconds < 0 ? 0 : d.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final DateTime now = DateTime.now();
    final bool live = _state.isLive(now);
    final Duration cooldown = _state.status == null ? Duration.zero : DeliveryPodRules.cooldownRemaining(now: now, lastGeneratedAt: _state.lastGeneratedAt);
    final int codesLeft = _state.status == null ? DeliveryPodRules.maxRegenerations : DeliveryPodRules.regenerationsLeft(_state.regenerations);
    final bool capReached = _state.status != null && codesLeft <= 0;
    final bool canRequest = !_requesting && !_verifying && !capReached && cooldown == Duration.zero;
    final Duration expiresIn = _state.expiresAt == null ? Duration.zero : _state.expiresAt!.difference(now);

    return DsSheet(
      title: "Enter delivery code".tr,
      subtitle: "Ask the customer for the 6-digit code shown in their app.".tr,
      showClose: true,
      actions: DsButton.success(
        label: "Verify".tr,
        icon: Icons.verified_outlined,
        size: DsButtonSize.xl,
        expand: true,
        loading: _verifying,
        onPressed: _verifying || _requesting ? null : _verify,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MaterialPinField(
            length: DeliveryPodRules.codeLength,
            pinController: _pin,
            keyboardType: TextInputType.number,
            autoFocus: true,
            hintCharacter: "-",
            theme: MaterialPinTheme(
              cellSize: const Size(46, 56),
              shape: MaterialPinShape.outlined,
              borderRadius: DsRadius.brMd,
              textStyle: t.title.tabular,
              hintStyle: DsTypography.title.copyWith(color: c.textMuted),
              fillColor: c.surfaceAlt,
              borderColor: c.border,
              focusedBorderColor: c.brand,
              cursorColor: c.brand,
              errorColor: c.danger,
            ),
            onChanged: (_) {
              if (_error != null && live) setState(() => _error = null);
            },
            onCompleted: (_) {},
          ),
          const DsGap(DsSpace.md),
          if (live)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 16, color: c.textMuted),
                const DsGap(DsSpace.xs),
                Text("${'Code expires in'.tr} ${_mmss(expiresIn)}", style: t.caption.tabular),
              ],
            ),
          if (_error != null) ...[
            const DsGap(DsSpace.md),
            DsInlineAlert(tone: DsTone.danger, message: _error!),
          ],
          const DsGap(DsSpace.lg),
          DsButton.tonal(
            label: cooldown > Duration.zero ? "${'Get a new code'.tr} (${_mmss(cooldown)})" : "Get a new code".tr,
            icon: Icons.refresh_rounded,
            expand: true,
            loading: _requesting,
            onPressed: canRequest ? _newCode : null,
          ),
          const DsGap(DsSpace.sm),
          Text(
            capReached ? "No new codes left for this order.".tr : "${'New codes left:'.tr} $codesLeft / ${DeliveryPodRules.maxRegenerations}",
            textAlign: TextAlign.center,
            style: t.caption,
          ),
        ],
      ),
    );
  }
}
