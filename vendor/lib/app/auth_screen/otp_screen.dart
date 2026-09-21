import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/auth_screen/login_screen.dart';
import 'package:vendor/app/auth_screen/signup_screen.dart';
import 'package:vendor/app/dash_board_screens/app_not_access_screen.dart';
import 'package:vendor/app/dash_board_screens/dash_board_screen.dart';
import 'package:vendor/app/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/otp_controller.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/notification_service.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX<OtpController>(
      init: OtpController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface),
          body: controller.isLoading.value
              ? Constant.loader()
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Verify Your Number 📱".tr,
                          style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                        ),
                        Text(
                          "${'Enter the OTP sent to your mobile number.'.tr} ${controller.countryCode.value} ${Constant.maskingString(controller.phoneNumber.value, 3)}".tr,
                          textAlign: TextAlign.start,
                          style: TextStyle(color: isDark ? AppThemeData.grey200 : AppThemeData.grey700, fontSize: 16, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400),
                        ),
                        const SizedBox(height: 60),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: MaterialPinField(
                            length: 6,
                            keyboardType: TextInputType.phone,
                            enableAutofill: true,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            hintCharacter: "-",
                            pinController: controller.otpController.value,
                            theme: MaterialPinTheme(
                              cellSize: const Size(50, 50),
                              shape: MaterialPinShape.outlined,
                              borderRadius: BorderRadius.circular(10),
                              textStyle: TextStyle(fontFamily: AppThemeData.regular, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                              hintStyle: TextStyle(color: isDark ? AppThemeData.grey500 : AppThemeData.grey400, fontFamily: AppThemeData.regular),
                              fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              borderColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                              focusedBorderColor: AppThemeData.primary300,
                              cursorColor: AppThemeData.primary300,
                              errorColor: isDark ? AppThemeData.grey600 : AppThemeData.grey300,
                            ),
                            onChanged: (value) {},
                            onCompleted: (pin) async {
                              // OTP completed
                            },
                          ),
                        ),
                        const SizedBox(height: 50),
                        RoundedButtonFill(
                          title: "Verify & Next".tr,
                          color: AppThemeData.primary300,
                          textColor: AppThemeData.grey50,
                          onPress: () async {
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
                        const SizedBox(height: 40),
                        Text.rich(
                          textAlign: TextAlign.start,
                          TextSpan(
                            text: "${'Did’t receive any code? '.tr} ",
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, fontFamily: AppThemeData.medium, color: isDark ? AppThemeData.grey100 : AppThemeData.grey800),
                            children: <TextSpan>[
                              TextSpan(
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    controller.otpController.value.clear();
                                    controller.sendOTP();
                                  },
                                text: 'Send Again'.tr,
                                style: TextStyle(
                                  color: isDark ? AppThemeData.primary300 : AppThemeData.primary300,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  fontFamily: AppThemeData.medium,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppThemeData.primary300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
