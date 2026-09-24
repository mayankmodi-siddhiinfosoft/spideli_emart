import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:get/get.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String? otp;

  VerifyOtpScreen({Key? key, required this.otp}) : super(key: key);

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

    return DsScaffold(
      title: 'Verify OTP'.tr,
      onBack: () {
        Navigator.pop(context);
      },
      maxContentWidth: DsLayout.contentMax,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xxxl, l.gutter, DsSpace.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: DsFadeSlideIn.stagger([
            Center(
              child: DsIconWell(
                icon: Icons.password_rounded,
                tone: DsTone.brand,
                size: 72,
                circle: true,
              ),
            ),
            DsGap.xxl,
            Text(
              "Collect OTP from customer".tr,
              textAlign: TextAlign.center,
              style: t.headline,
            ),
            DsGap.sm,
            Text(
              'Ask the customer for the 6-digit code to confirm this booking.'.tr,
              textAlign: TextAlign.center,
              style: t.bodySecondary,
            ),
            DsGap.xxxl,
            OtpTextField(
              numberOfFields: 6,
              borderColor: c.border,
              enabledBorderColor: c.border,
              focusedBorderColor: c.brand,
              cursorColor: c.brand,
              borderWidth: 1.5,
              fieldWidth: 44,
              showFieldAsBox: true,
              textStyle: DsTypography.metric.copyWith(color: c.textPrimary, fontSize: 22),
              mainAxisAlignment: MainAxisAlignment.center,
              //runs when a code is typed in
              onSubmit: (String verificationCode) {
                setState(() {
                  otp = verificationCode;
                });
              }, // end onSubmit
            ),
          ]),
        ),
      ),
      bottomBar: DsStickyBar(
        child: DsButton.primary(
          label: "Verify OTP".tr,
          icon: Icons.check_rounded,
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
