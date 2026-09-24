import 'package:customer/screen_ui/auth_screens/sign_up_screen.dart';
import 'package:customer/screen_ui/auth_screens/widgets/auth_shell.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../controllers/otp_verification_controller.dart';

class OtpVerificationScreen extends StatelessWidget {
  const OtpVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OtpVerifyController>(
      init: OtpVerifyController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final phone = "${controller.countryCode} ${controller.maskPhoneNumber(controller.phoneNumber.value)}";

        return AuthScaffold(
          eyebrow: "Verification",
          title: "${"Enter the OTP sent to your mobile".tr} $phone",
          icon: Icons.sms_outlined,
          leading: DsBackButton(
            onPressed: () {
              Get.back();
            },
          ),
          actions: [
            AuthSkipButton(
              onPressed: () {
                // Handle skip action
              },
            ),
          ],
          footer: AuthFooterLink(
            text: "Didn't have an account? ".tr,
            linkText: "Sign up".tr,
            recognizer: TapGestureRecognizer()..onTap = () => Get.offAll(() => const SignUpScreen()),
          ),
          children: [
            DsCard(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
              child: Column(
                children: [
                  /// OTP Field
                  Center(
                    child: MaterialPinField(
                      length: 6,
                      pinController: controller.otpController.value,
                      keyboardType: TextInputType.number,
                      enableAutofill: true,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      hintCharacter: "-",
                      theme: MaterialPinTheme(
                        cellSize: const Size(48, 56),
                        shape: MaterialPinShape.outlined,
                        borderRadius: DsRadius.brMd,
                        borderWidth: 1,
                        textStyle: DsTypography.titleSm.copyWith(color: c.textPrimary, fontSize: 20),
                        fillColor: c.surfaceAlt,
                        borderColor: c.border,
                        focusedBorderColor: c.brand,
                        cursorColor: c.brand,
                        errorColor: c.danger,
                        filledFillColor: c.brandSoft,
                        focusedFillColor: c.surfaceAlt,
                      ),
                      onChanged: (value) {},
                      onCompleted: (pin) {
                        // OTP completed
                      },
                    ),
                  ),
                  const DsGap(DsSpace.md),

                  /// Resend OTP
                  TextButton.icon(
                    onPressed: () {
                      controller.otpController.value.clear();
                      controller.sendOTP();
                    },
                    icon: Icon(Icons.refresh_rounded, size: 20, color: c.brandStrong),
                    label: Text("Resend OTP".tr, style: t.label.withColor(c.brandStrong)),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: c.brandStrong),
                  ),
                ],
              ),
            ),
            const DsGap(DsSpace.xxl),

            /// Verify Button
            DsButton.primary(label: "Verify".tr, size: DsButtonSize.lg, expand: true, icon: Icons.check_rounded, onPressed: controller.verifyOtp),
          ],
        );
      },
    );
  }
}
