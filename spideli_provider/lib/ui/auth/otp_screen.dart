import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/otp_controller.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/notification_service.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/app_them_data.dart';
import 'package:spideliprovider/themes/round_button_fill.dart';
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
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<OtpController>(
        init: OtpController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: themeChange.getTheme() ? AppThemeData.surfaceDark : AppThemeData.surface,
            ),
            body: controller.isLoading.value
                ? loader()
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Verify Your Number 📱".tr,
                            style: TextStyle(color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900, fontSize: 22, fontFamily: AppThemeData.semiBold),
                          ),
                          Text(
                            "${'Enter the OTP sent to your mobile number.'.tr} ${controller.countryCode.value} ${maskingString(controller.phoneNumber.value, 3)}".tr,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: themeChange.getTheme() ? AppThemeData.grey200 : AppThemeData.grey700,
                              fontSize: 16,
                              fontFamily: AppThemeData.regular,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(
                            height: 60,
                          ),
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
                                textStyle: TextStyle(
                                  fontFamily: AppThemeData.regular,
                                  color: themeChange.getTheme() ? AppThemeData.grey50 : AppThemeData.grey900,
                                ),
                                fillColor: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey50,
                                borderColor: themeChange.getTheme() ? AppThemeData.grey900 : AppThemeData.grey50,
                                focusedBorderColor: AppThemeData.secondary300,
                                cursorColor: AppThemeData.secondary300,
                                errorColor: themeChange.getTheme() ? AppThemeData.grey600 : AppThemeData.grey300,
                              ),
                              onChanged: (value) {},
                              onCompleted: (pin) async {
                                // OTP Completed
                              },
                            ),
                          ),
                          const SizedBox(
                            height: 50,
                          ),
                          RoundedButtonFill(
                            title: "Verify & Next".tr,
                            color: AppColors.colorPrimary,
                            textColor: AppThemeData.grey50,
                            onPress: () async {
                              if (controller.otpController.value.text.length == 6) {
                                ShowToastDialog.showLoader("Verify otp".tr);

                                PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: controller.verificationId.value, smsCode: controller.otpController.value.text);
                                String fcmToken = await NotificationService.getToken();
                                await FirebaseAuth.instance.signInWithCredential(credential).then((value) async {
                                  if (value.additionalUserInfo!.isNewUser) {
                                    User userModel = User();
                                    userModel.id = value.user!.uid;
                                    userModel.countryCode = controller.countryCode.value;
                                    userModel.phoneNumber = controller.phoneNumber.value;
                                    userModel.fcmToken = fcmToken;
                                    userModel.provider = 'phone';

                                    ShowToastDialog.closeLoader();
                                    Get.off(const SignupScreen(), arguments: {
                                      "userModel": userModel,
                                      "type": "mobileNumber",
                                    });
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

                                        Get.off(const SignupScreen(), arguments: {
                                          "userModel": userModel,
                                          "type": "mobileNumber",
                                        });
                                      }
                                    });
                                  }
                                }).catchError((error) {
                                  ShowToastDialog.closeLoader();
                                  ShowToastDialog.showToast("Invalid Code".tr);
                                });
                              } else {
                                ShowToastDialog.showToast("Enter Valid otp".tr);
                              }
                            },
                          ),
                          const SizedBox(
                            height: 40,
                          ),
                          Text.rich(
                            textAlign: TextAlign.start,
                            TextSpan(
                              text: "${'Did’t receive any code? '.tr} ",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                fontFamily: AppThemeData.medium,
                                color: themeChange.getTheme() ? AppThemeData.grey100 : AppThemeData.grey800,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      controller.otpController.value.clear();
                                      controller.sendOTP();
                                    },
                                  text: 'Send Again'.tr,
                                  style: TextStyle(
                                      color: themeChange.getTheme() ? AppThemeData.secondary300 : AppThemeData.secondary300,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      fontFamily: AppThemeData.medium,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppThemeData.secondary300),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
          );
        });
  }
}
