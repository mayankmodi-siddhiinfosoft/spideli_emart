import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:vendor/app/auth_screen/login_screen.dart';
import 'package:vendor/app/auth_screen/signup_screen.dart';
import 'package:vendor/app/auth_screen/widgets/auth_layout.dart';
import 'package:vendor/app/dash_board_screens/app_not_access_screen.dart';
import 'package:vendor/app/dash_board_screens/dash_board_screen.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/store_selector_controller.dart';
import 'package:vendor/controller/otp_controller.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/notification_service.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OtpController>(
      init: OtpController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        if (controller.isLoading.value) {
          return Scaffold(
            backgroundColor: c.background,
            appBar: const DsAppBar(),
            body: const DsResponsive(maxWidth: 480, child: DsSkeletonForm(fields: 1)),
          );
        }
        return AuthLayout(
          heroIcon: Icons.mark_email_unread_outlined,
          title: "Verify Your Number 📱".tr,
          subtitleWidget: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "${'Enter the OTP sent to your mobile number.'.tr} "),
                TextSpan(text: "${controller.countryCode.value} ${Constant.maskingString(controller.phoneNumber.value, 3)}".tr, style: t.bodyLg.w600.withColor(c.textPrimary)),
              ],
            ),
            style: t.bodyLg.withColor(c.textSecondary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsCard.tinted(
                tone: DsTone.brand,
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xl),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MaterialPinField(
                    length: 6,
                    keyboardType: TextInputType.phone,
                    enableAutofill: true,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    hintCharacter: "-",
                    pinController: controller.otpController.value,
                    theme: MaterialPinTheme(
                      cellSize: const Size(48, 56),
                      spacing: DsSpace.sm,
                      shape: MaterialPinShape.outlined,
                      borderRadius: DsRadius.brMd,
                      textStyle: t.headline.withColor(c.textPrimary),
                      hintStyle: t.title.withColor(c.textMuted),
                      fillColor: c.surface,
                      borderColor: c.border,
                      filledBorderColor: c.brandMuted,
                      focusedBorderColor: c.brand,
                      cursorColor: c.brand,
                      errorColor: c.danger,
                    ),
                    onChanged: (value) {},
                    onCompleted: (pin) async {
                      // OTP completed
                    },
                  ),
                ),
              ),
              const DsGap(DsSpace.xxl),
              DsButton.primary(
                label: "Verify & Next".tr,
                size: DsButtonSize.lg,
                expand: true,
                icon: Icons.verified_user_outlined,
                onPressed: () async {
                  if (controller.otpController.value.text.length == 6) {
                    ShowToastDialog.showLoader("Verify otp".tr);

                    PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: controller.verificationId.value, smsCode: controller.otpController.value.text);
                    String fcmToken = await NotificationService.getToken();
                    await FirebaseAuth.instance
                        .signInWithCredential(credential)
                        .then((value) async {
                          if (value.additionalUserInfo!.isNewUser) {
                            UserModel userModel = UserModel();
                            userModel.id = value.user!.uid;
                            userModel.countryCode = controller.countryCode.value;
                            userModel.countryISOCode = controller.countryISOCode.value;
                            userModel.phoneNumber = controller.phoneNumber.value;
                            userModel.fcmToken = fcmToken;
                            userModel.provider = 'phone';

                            ShowToastDialog.closeLoader();
                            Get.off(const SignupScreen(), arguments: {"userModel": userModel, "type": "mobileNumber"});
                          } else {
                            await FireStoreUtils.userExistOrNot(value.user!.uid).then((userExit) async {
                              ShowToastDialog.closeLoader();
                              if (userExit == true) {
                                UserModel? userModel = await FireStoreUtils.getUserProfile(value.user!.uid);
                                if (userModel!.role == Constant.userRoleVendor) {
                                  if (userModel.active == true) {
                                    userModel.fcmToken = await NotificationService.getToken();
                                    await FireStoreUtils.updateUser(userModel);
                                    // Owners with several stores pick one first (spec: Login > Store selector > Dashboard).
                                    if (await StoreSelectorController.openIfNeeded(userModel)) {
                                      ShowToastDialog.closeLoader();
                                      return;
                                    }
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
                                    if (userModel.sectionId != null) {
                                      await FireStoreUtils.getSectionById(userModel.sectionId.toString()).then((value) {
                                        if (value != null) {
                                          Constant.selectedSection = value;
                                        }
                                      });
                                    }

                                    if (userModel.subscriptionPlanId == null || isPlanExpire == true) {
                                      if (userModel.sectionId!.isEmpty && Constant.isSubscriptionModelApplied == false) {
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
                                  ShowToastDialog.showToast("This user is not created in Store application.".tr);
                                }
                              } else {
                                UserModel userModel = UserModel();
                                userModel.id = value.user!.uid;
                                userModel.countryCode = controller.countryCode.value;
                                userModel.countryISOCode = controller.countryISOCode.value;
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
              const DsGap(DsSpace.xl),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Did’t receive any code? '.tr, style: t.body.withColor(c.textSecondary)),
                  DsButton.ghost(
                    label: 'Send Again'.tr,
                    size: DsButtonSize.sm,
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      controller.otpController.value.clear();
                      controller.sendOTP();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
