import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/employee_role_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class AddEmployeeController extends GetxController {
  RxBool isLoading = true.obs;
  Rx<TextEditingController> firstNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> lastNameEditingController = TextEditingController().obs;
  Rx<TextEditingController> emailEditingController = TextEditingController().obs;
  Rx<TextEditingController> phoneNUmberEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> countryISOCodeEditingController = TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> passwordEditingController = TextEditingController().obs;
  RxBool passwordVisible = true.obs;
  Rx<TextEditingController> conformPasswordEditingController = TextEditingController().obs;
  RxBool conformPasswordVisible = true.obs;

  //

  @override
  void onInit() {
    getAllEmployeeRoles();
    super.onInit();
  }

  RxList<EmployeeRoleModel> employeeRolelList = <EmployeeRoleModel>[].obs;
  Rx<EmployeeRoleModel> selectEmployeeRole = EmployeeRoleModel().obs;

  Future<void> getAllEmployeeRoles() async {
    await FireStoreUtils.getAllEmployeeRoles(isActive: true).then((value) {
      employeeRolelList.value = value;
    });
    getArgument();
    isLoading.value = false;
  }

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      employeeModel.value = argumentData['employeemodel'];
      if (employeeModel.value.id != null) {
        firstNameEditingController.value.text = employeeModel.value.firstName ?? '';
        lastNameEditingController.value.text = employeeModel.value.lastName ?? '';
        emailEditingController.value.text = employeeModel.value.email ?? '';
        phoneNUmberEditingController.value.text = employeeModel.value.phoneNumber ?? '';
        countryCodeEditingController.value.text = employeeModel.value.countryCode ?? '';
        countryISOCodeEditingController.value.text = employeeModel.value.countryISOCode ?? '';
        selectEmployeeRole.value = employeeRolelList.firstWhere((role) => role.id == employeeModel.value.employeePermissionId, orElse: () => EmployeeRoleModel());
      }
    }
    isLoading.value = false;
  }

  Future<void> signUpWithEmailAndPassword() async {
    signUp();
  }

  Rx<UserModel> employeeModel = UserModel().obs;
  Future<Null> signUp() async {
    ShowToastDialog.showLoader("Please wait".tr);

    try {
      if (employeeModel.value.id != null && employeeModel.value.id != '') {
        employeeModel.value.firstName = firstNameEditingController.value.text.trim();
        employeeModel.value.lastName = lastNameEditingController.value.text.trim();
        employeeModel.value.employeePermissionId = selectEmployeeRole.value.id;
        employeeModel.value.email = emailEditingController.value.text.trim();
        employeeModel.value.phoneNumber = phoneNUmberEditingController.value.text.trim();
        employeeModel.value.countryCode = countryCodeEditingController.value.text.trim();
        employeeModel.value.countryISOCode = countryISOCodeEditingController.value.text.trim();
        employeeModel.value.sectionId = Constant.userModel?.sectionId;
      } else {
        FirebaseApp secondaryApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);

        FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

        final credential = await secondaryAuth.createUserWithEmailAndPassword(email: emailEditingController.value.text.trim(), password: passwordEditingController.value.text.trim());

        if (credential.user != null) {
          employeeModel.value.firstName = firstNameEditingController.value.text.trim();
          employeeModel.value.lastName = lastNameEditingController.value.text.trim();
          employeeModel.value.employeePermissionId = selectEmployeeRole.value.id;
          employeeModel.value.email = emailEditingController.value.text.trim().toLowerCase();
          employeeModel.value.phoneNumber = phoneNUmberEditingController.value.text.trim();
          employeeModel.value.role = Constant.userRoleEmployee;
          employeeModel.value.fcmToken = '';
          employeeModel.value.active = true;
          employeeModel.value.isDocumentVerify = Constant.userModel?.isAutoVerify == true
              ? true
              : Constant.userModel?.isDocumentVerify == true
              ? true
              : false;
          employeeModel.value.countryCode = countryCodeEditingController.value.text.trim();
          employeeModel.value.countryISOCode = countryISOCodeEditingController.value.text.trim();
          employeeModel.value.createdAt = Timestamp.now();
          employeeModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
          employeeModel.value.provider = 'email';
          employeeModel.value.vendorID = Constant.userModel?.vendorID;
          employeeModel.value.id = credential.user?.uid;
          employeeModel.value.sectionId = Constant.userModel?.sectionId;
        } else {
          ShowToastDialog.showToast("Something went to wrong".tr);
          return null;
        }
        await secondaryApp.delete();
      }
      await FireStoreUtils.updateUser(employeeModel.value).then((value) async {
        if (value == true) {
          Get.back(result: true);
          ShowToastDialog.showToast("Employee details saved successfully!".tr);
        } else {
          ShowToastDialog.showToast("Something went to wrong".tr);
        }
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        ShowToastDialog.showToast("The password provided is too weak.".tr);
      } else if (e.code == 'email-already-in-use') {
        ShowToastDialog.showToast("The account already exists for that email.".tr);
      } else if (e.code == 'invalid-email') {
        ShowToastDialog.showToast("Enter email is Invalid".tr);
      }
    } catch (e) {
      ShowToastDialog.showToast(e.toString());
    }

    ShowToastDialog.closeLoader();
  }
}
