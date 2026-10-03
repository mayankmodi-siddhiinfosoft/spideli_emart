
import 'package:driver/app/auth_screen/login_screen.dart';
import 'package:driver/app/auth_screen/signup_screen.dart';
import 'package:driver/app/auth_screen/widgets/auth_shell.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controllers/otp_controller.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/driver_sign_in.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

/// Archetype H – OTP: the code boxes are the hero of the screen, with the
/// resend action right under them and a single primary action at the bottom.
class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OtpController>(
        init: OtpController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          return DsScaffold(
            appBar: const DsAppBar(),
            body: controller.isLoading.value
                ? Constant.loader()
                : AuthShell(
                    icon: Icons.sms_outlined,
                    title: "Verify Your Mobile Number".tr,
                    subtitle: "Enter the OTP sent to your mobile number to verify and secure your account.".tr,
                    highlights: [
                      "A 6-digit code keeps your account safe".tr,
                    ],
                    children: [
                      DsCard(
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xl),
                        child: Column(
                          children: [
                            MaterialPinField(
                              length: 6,
                              keyboardType: TextInputType.phone,
                              enableAutofill: true,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              hintCharacter: "-",
                              pinController: controller.otpController.value,
                              theme: MaterialPinTheme(
                                cellSize: const Size(48, 56),
                                shape: MaterialPinShape.outlined,
                                borderRadius: DsRadius.brMd,
                                textStyle: t.title,
                                fillColor: c.surfaceAlt,
                                borderColor: c.border,
                                focusedBorderColor: c.brand,
                                cursorColor: c.brand,
                                errorColor: c.danger,
                              ),
                              onChanged: (value) {},
                              onCompleted: (pin) async {
                                // OTP completed
                              },
                            ),
                            const DsGap(DsSpace.xl),
                            Text.rich(
                              textAlign: TextAlign.center,
                              TextSpan(
                                text: "${'Did’t receive any code? '.tr} ",
                                style: t.bodyStrong,
                                children: <TextSpan>[
                                  TextSpan(
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        controller.otpController.value.clear();
                                        controller.sendOTP();
                                      },
                                    text: 'Send Again'.tr,
                                    style: t.link,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.xl),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Already Have an account?'.tr, style: t.bodyStrong),
                              const WidgetSpan(child: SizedBox(width: 6)),
                              TextSpan(
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Get.offAll(const LoginScreen());
                                  },
                                text: 'Log in'.tr,
                                style: t.link,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: "Verify Code".tr,
                icon: Icons.verified_outlined,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () async {
                  if (controller.otpController.value.text.length == 6) {
                    ShowToastDialog.showLoader("Verify otp".tr);

                    PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: controller.verificationId.value, smsCode: controller.otpController.value.text);
                    // The token warmed at start-up, without waiting: on iOS a
                    // fresh fetch can wait for the APNs token. Sign-up saves the
                    // live one again once the account exists.
                    final String fcmToken = NotificationService.cachedToken;
                    await FirebaseAuth.instance.signInWithCredential(credential).then((value) async {
                      if (value.additionalUserInfo!.isNewUser) {
                        UserModel userModel = UserModel();
                        userModel.id = value.user!.uid;
                        userModel.countryCode = controller.countryCode.value;
                        userModel.countryISOCode = controller.countryISOCode.value;
                        userModel.phoneNumber = controller.phoneNumber.value;
                        if (fcmToken.isNotEmpty) userModel.fcmToken = fcmToken;
                        userModel.provider = 'phone';

                        ShowToastDialog.closeLoader();
                        Get.off(const SignupScreen(), arguments: {
                          "userModel": userModel,
                          "type": "mobileNumber",
                        });
                      } else {
                        // Shared with email / Google / Apple sign-in: never
                        // throws, opens the right dashboard, signs out again
                        // on every refusal.
                        final AccountResult result = await DriverSignIn.open(value.user!.uid);
                        ShowToastDialog.closeLoader();
                        switch (result.outcome) {
                          case AccountOutcome.opened:
                            break;
                          case AccountOutcome.missing:
                            UserModel userModel = UserModel();
                            userModel.id = value.user!.uid;
                            userModel.countryCode = controller.countryCode.value;
                            userModel.countryISOCode = controller.countryISOCode.value;
                            userModel.phoneNumber = controller.phoneNumber.value;
                            if (fcmToken.isNotEmpty) userModel.fcmToken = fcmToken;
                            userModel.provider = 'phone';

                            Get.off(const SignupScreen(), arguments: {
                              "userModel": userModel,
                              "type": "mobileNumber",
                            });
                            break;
                          case AccountOutcome.notDriver:
                            Get.offAll(const LoginScreen());
                            ShowToastDialog.showToast("Account already created in other application. You are not able login this application.".tr);
                            break;
                          case AccountOutcome.inactive:
                          case AccountOutcome.failed:
                            Get.offAll(const LoginScreen());
                            ShowToastDialog.showToast((result.message ?? "Something went wrong. Please try again.").tr);
                            break;
                        }
                      }
                    }).catchError((error) {
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast(
                        (error is FirebaseAuthException && error.code != 'invalid-verification-code' && error.code != 'invalid-verification-id' && error.code != 'session-expired'
                                ? DriverSignIn.authErrorMessage(error)
                                : "Invalid Code")
                            .tr,
                      );
                    });
                  } else {
                    ShowToastDialog.showToast("Enter Valid otp".tr);
                  }
                },
              ),
            ),
          );
        });
  }
}
