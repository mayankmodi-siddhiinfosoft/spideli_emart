import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/section_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class AddDriverController extends GetxController {
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

  Rx<UserModel> userModel = UserModel().obs;
  Rx<UserModel> driverModel = UserModel().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;

  /// Sections the vendor is registered in (loaded from Firestore).
  RxList<SectionModel> vendorSections = <SectionModel>[].obs;

  // ── Helpers ────────────────────────────────────────────────────────────

  String serviceFlagLabel(String? flag) {
    switch (flag) {
      case 'cab-service':
        return 'Cab';
      case 'parcel_delivery':
        return 'Parcel';
      case 'rental-service':
        return 'Rental';
      default:
        return 'Delivery';
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Future<void> getArgument() async {
    try {
      // Load current user (vendor's user record).
      await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((model) {
        if (model != null) {
          userModel.value = model;
        }
      });

      // Load vendor model to get sectionId + zoneId.
      if (Constant.userModel?.vendorID != null) {
        await FireStoreUtils.getVendorById(Constant.userModel!.vendorID!).then((v) {
          if (v != null) vendorModel.value = v;
        });
      }

      // Load the vendor's section(s).
      await _loadVendorSections();

      // Edit mode: prefill from existing driver.
      dynamic argumentData = Get.arguments;
      if (argumentData != null) {
        driverModel.value = argumentData['driverModel'];
        if (driverModel.value.id != null) {
          firstNameEditingController.value.text = driverModel.value.firstName ?? '';
          lastNameEditingController.value.text = driverModel.value.lastName ?? '';
          emailEditingController.value.text = driverModel.value.email ?? '';
          phoneNUmberEditingController.value.text = driverModel.value.phoneNumber ?? '';
          countryCodeEditingController.value.text = driverModel.value.countryCode ?? '';
          countryISOCodeEditingController.value.text = driverModel.value.countryISOCode ?? '';
        }
      }
    } catch (e) {
      log("AddDriverController.getArgument error: $e");
    } finally {
      isLoading.value = false;
      update();
    }
  }

  Future<void> _loadVendorSections() async {
    final vendorSectionId = vendorModel.value.sectionId;
    if (vendorSectionId == null || vendorSectionId.isEmpty) return;

    // Load all active sections, filter to vendor's section(s).
    final allSections = await FireStoreUtils.getSection();
    vendorSections.value = allSections.where((s) => s.id == vendorSectionId).toList();
  }

  // ── Save ───────────────────────────────────────────────────────────────

  Future<void> signUpWithEmailAndPassword() async {
    signUp();
  }

  Future<void> signUp() async {
    ShowToastDialog.showLoader("Please wait".tr);

    try {
      if (driverModel.value.id != null && driverModel.value.id != '') {
        // ── Edit mode ──
        _applyCommonFields();
      } else {
        // ── Create mode ──
        FirebaseApp secondaryApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
        FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

        final credential = await secondaryAuth.createUserWithEmailAndPassword(email: emailEditingController.value.text.trim(), password: passwordEditingController.value.text.trim());

        if (credential.user != null) {
          driverModel.value.id = credential.user!.uid;
          _applyCommonFields();
          driverModel.value.fcmToken = '';
          driverModel.value.createdAt = Timestamp.now();
          driverModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
          driverModel.value.provider = 'email';
        } else {
          ShowToastDialog.showToast("Something went to wrong".tr);
          ShowToastDialog.closeLoader();
          return;
        }
        await secondaryApp.delete();
      }

      await FireStoreUtils.updateDriverUser(driverModel.value).then((value) async {
        if (value == true) {
          Get.back(result: true);
          ShowToastDialog.showToast("Delivery man details saved successfully!".tr);
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

  void _applyCommonFields() {
    driverModel.value.firstName = firstNameEditingController.value.text.trim();
    driverModel.value.lastName = lastNameEditingController.value.text.trim();
    driverModel.value.email = emailEditingController.value.text.trim().toLowerCase();
    driverModel.value.phoneNumber = phoneNUmberEditingController.value.text.trim();
    driverModel.value.countryCode = countryCodeEditingController.value.text.trim();
    driverModel.value.countryISOCode = countryISOCodeEditingController.value.text.trim();
    driverModel.value.role = Constant.userRoleDriver;
    driverModel.value.active = true;
    driverModel.value.isActive = false;
    driverModel.value.isDocumentVerify = true;
    driverModel.value.zoneId = vendorModel.value.zoneId;
    driverModel.value.vendorID = Constant.userModel?.vendorID;
    driverModel.value.isAutoVerify = Constant.userModel?.isAutoVerify;

    // Multi-section fields (driver app format).
    driverModel.value.sectionIds = vendorSections.map((s) => s.id).whereType<String>().toList();
    driverModel.value.sectionNames = {
      for (final s in vendorSections)
        if (s.id != null) s.id!: s.name ?? s.id!,
    };
    driverModel.value.serviceTypes = vendorSections.map((s) => s.serviceTypeFlag ?? 'delivery-service').toSet().toList();

    // Legacy singular fields (backwards compat).
    if (vendorSections.isNotEmpty) {
      driverModel.value.sectionId = vendorSections.first.id;
      driverModel.value.serviceType = vendorSections.first.serviceTypeFlag ?? 'delivery-service';
    }
  }
}
