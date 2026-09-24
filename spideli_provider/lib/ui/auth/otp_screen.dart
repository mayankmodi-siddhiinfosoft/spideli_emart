import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/otp_controller.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/notification_service.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/auth/auth_layout.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/ui/login/login_screen.dart';
import 'package:spideliprovider/ui/signUp/signup_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/app_not_access_screen.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return GetX<OtpController>(
      init: OtpController(),
      builder: (controller) {
        final bool loading = controller.isLoading.value;
        return DsScaffold(
          backgroundColor: c.background,
          appBar: DsAppBar(backgroundColor: c.background),
          maxContentWidth: null,
          body: loading
              ? const _OtpSkeleton()
              : AuthShell(
                  children: [
                    // A "code sent" crest keeps this step distinct from the
                    // phone-number step that precedes it.
                    const DsIconWell(icon: Icons.mark_email_read_outlined, tone: DsTone.brand, size: 56),
                    const DsGap(DsSpace.xl),
                    Text("Verify Your Number 📱".tr, style: t.display),
                    const DsGap(DsSpace.xs),
                    Text(
                      "${'Enter the OTP sent to your mobile number.'.tr} ${controller.countryCode.value} ${maskingString(controller.phoneNumber.value, 3)}".tr,
                      textAlign: TextAlign.start,
                      style: t.bodyLg.withColor(c.textSecondary),
                    ),
                    const DsGap(DsSpace.huge),
                    MaterialPinField(
                      length: 6,
                      keyboardType: TextInputType.phone,
                      enableAutofill: true,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      hintCharacter: "-",
                      pinController: controller.otpController.value,
                      theme: MaterialPinTheme(
                        cellSize: const Size(52, 60),
                        shape: MaterialPinShape.outlined,
                        borderRadius: DsRadius.brMd,
                        textStyle: DsTypography.metric.copyWith(color: c.textPrimary, fontSize: 24),
                        fillColor: c.surfaceAlt,
                        borderColor: c.border,
                        focusedBorderColor: c.brand,
                        cursorColor: c.brand,
                        errorColor: c.danger,
                      ),
                      onChanged: (value) {},
                      onCompleted: (pin) async {
                        // OTP Completed
                      },
                    ),
                    const DsGap(DsSpace.xxxl),
                    Center(
                      child: Text.rich(
                        textAlign: TextAlign.center,
                        TextSpan(
                          text: "${'Did’t receive any code? '.tr} ",
                          style: t.bodyStrong.withColor(c.textSecondary),
                          children: <TextSpan>[
                            TextSpan(
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  controller.otpController.value.clear();
                                  controller.sendOTP();
                                },
                              text: 'Send Again'.tr,
                              style: t.label.withColor(c.brandStrong).copyWith(decoration: TextDecoration.underline, decorationColor: c.brandStrong),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          bottomBar: loading
              ? null
              : DsStickyBar(
                  child: DsButton.primary(
                    label: "Verify & Next".tr,
                    expand: true,
                    size: DsButtonSize.lg,
                    icon: Icons.verified_outlined,
                    onPressed: () async {
                      if (controller.otpController.value.text.length == 6) {
                        ShowToastDialog.showLoader("Verify otp".tr);

                        PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: controller.verificationId.value, smsCode: controller.otpController.value.text);
                        String fcmToken = await NotificationService.getToken();
                        await FirebaseAuth.instance
                            .signInWithCredential(credential)
                            .then((value) async {
                              if (value.additionalUserInfo!.isNewUser) {
                                User userModel = User();
                                userModel.id = value.user!.uid;
                                userModel.countryCode = controller.countryCode.value;
                                userModel.phoneNumber = controller.phoneNumber.value;
                                userModel.fcmToken = fcmToken;
                                userModel.provider = 'phone';

                                ShowToastDialog.closeLoader();
                                Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "mobileNumber"});
                              } else {
                                await FireStoreUtils.userExistOrNot(value.user!.uid).then((userExit) async {
                                  ShowToastDialog.closeLoader();
                                  if (userExit == true) {
                                    User? userModel = await FireStoreUtils.getUserProfile(value.user!.uid);
                                    if (userModel!.role == USER_ROLE_PROVIDER) {
                                      if (userModel.active == true) {
                                        userModel.fcmToken = await NotificationService.getToken();
                                        await FireStoreUtils.updateCurrentUser(userModel);
                                        bool isPlanExpire = false;
                                        if (userModel.subscriptionPlan?.id != null) {
                                          if (userModel.subscriptionExpiryDate == null) {
                                            if (userModel.subscriptionPlan?.expiryDay == '-1') {
                                              isPlanExpire = false;
                                            } else {
                                              isPlanExpire = true;
                                            }
                                          } else {
                                            DateTime expiryDate = userModel.subscriptionExpiryDate!.toDate();
                                            isPlanExpire = expiryDate.isBefore(DateTime.now());
                                          }
                                        } else {
                                          isPlanExpire = true;
                                        }
                                        if (userModel.subscriptionPlanId == null || isPlanExpire == true) {
                                          if (isSubscriptionModelApplied == false) {
                                            Get.offAll(const DashBoardScreen());
                                          } else {
                                            Get.offAll(const SubscriptionPlanScreen());
                                          }
                                        } else if (userModel.subscriptionPlan?.features?.ownerMobileApp == true) {
                                          Get.offAll(const DashBoardScreen());
                                        } else {
                                          Get.offAll(const AppNotAccessScreen());
                                        }
                                      } else {
                                        ShowToastDialog.showToast("This user is disable please contact to administrator".tr);
                                        await FirebaseAuth.instance.signOut();
                                        Get.offAll(const LoginScreen());
                                      }
                                    } else {
                                      await FirebaseAuth.instance.signOut();
                                      Get.offAll(const LoginScreen());
                                      ShowToastDialog.showToast("This user is not created in restaurant application.".tr);
                                    }
                                  } else {
                                    User userModel = User();
                                    userModel.id = value.user!.uid;
                                    userModel.countryCode = controller.countryCode.value;
                                    userModel.phoneNumber = controller.phoneNumber.value;
                                    userModel.fcmToken = fcmToken;
                                    userModel.provider = 'phone';

                                    Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "mobileNumber"});
                                  }
                                });
                              }
                            })
                            .catchError((error) {
                              ShowToastDialog.closeLoader();
                              ShowToastDialog.showToast("Invalid Code".tr);
                            });
                      } else {
                        ShowToastDialog.showToast("Enter Valid otp".tr);
                      }
                    },
                  ),
                ),
        );
      },
    );
  }
}

/// Keeps the OTP layout (crest, headings, six cells) while the screen waits
/// for the verification id, so nothing jumps when it arrives.
class _OtpSkeleton extends StatelessWidget {
  const _OtpSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: DsResponsive(
        maxWidth: DsLayout.contentMax,
        padded: true,
        child: DsShimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsSkeleton.box(width: 56, height: 56, radius: DsRadius.md),
              const DsGap(DsSpace.xl),
              DsSkeleton.line(width: 240, height: 26),
              const DsGap(DsSpace.md),
              DsSkeleton.line(width: double.infinity),
              const DsGap(DsSpace.sm),
              DsSkeleton.line(width: 200),
              const DsGap(DsSpace.huge),
              Row(
                children: [
                  for (int i = 0; i < 6; i++) ...[DsSkeleton.box(width: 44, height: 60, radius: DsRadius.md), if (i < 5) const DsGap(DsSpace.sm)],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
