import 'package:spideliworker/constant/show_toast_dialog.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:get/get.dart';

/// OTP handover (archetype M): a centred, width-capped column with a lock
/// icon well, the instruction, the boxed OTP field and "Verify OTP" pinned in
/// a sticky bar. The comparison, the toast and the `Navigator.pop(context,
/// true)` are unchanged.
class VerifyOtpScreen extends StatefulWidget {
  final String? otp;

  const VerifyOtpScreen({super.key, required this.otp});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  String otp = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final l = context.dsLayout;
    // The 6 boxes have to fit the narrowest phone.
    final double available = MediaQuery.sizeOf(context).width - l.gutter * 2;
    final double fieldWidth = ((available - 6 * 8) / 6).clamp(38.0, 56.0);

    return DsScaffold(
      appBar: DsAppBar(
        onBack: () {
          Navigator.pop(context);
        },
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: DsFadeSlideIn.stagger([
                Center(child: DsIconWell(icon: Icons.lock_outline, size: 72, circle: true, tone: DsTone.brand)),
                const DsGap(DsSpace.xxl),
                Semantics(
                  header: true,
                  child: Text("Collect OTP from customer".tr, textAlign: TextAlign.center, style: t.headline),
                ),
                const DsGap(DsSpace.sm),
                Text(
                  "Ask the customer for the 6-digit code shown in their booking.".tr,
                  textAlign: TextAlign.center,
                  style: t.bodySecondary,
                ),
                const DsGap(DsSpace.xxxl),
                Center(
                  child: OtpTextField(
                    numberOfFields: 6,
                    borderColor: c.border,
                    focusedBorderColor: c.brand,
                    enabledBorderColor: c.border,
                    fieldWidth: fieldWidth,
                    filled: true,
                    fillColor: c.surfaceAlt,
                    borderRadius: DsRadius.brMd,
                    textStyle: t.metric.copyWith(fontSize: 22).tabular,
                    //set to true to show as box or false to show as dash
                    showFieldAsBox: true,
                    //runs when a code is typed in
                    onSubmit: (String verificationCode) {
                      setState(() {
                        otp = verificationCode;
                      });
                    }, // end onSubmit
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      bottomBar: DsStickyBar(
        child: DsButton.primary(
          label: "Verify OTP".tr,
          icon: Icons.verified_outlined,
          size: DsButtonSize.lg,
          expand: true,
          onPressed: () async {
            if (otp == widget.otp) {
              Navigator.pop(context, true);
            } else {
              ShowToastDialog.showToast("OTP Invalid");
            }
          },
        ),
      ),
    );
  }
}
