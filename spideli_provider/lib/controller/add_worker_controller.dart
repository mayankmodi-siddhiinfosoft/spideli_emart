import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/utils/args.dart';
import 'package:spideliprovider/utils/utils.dart';
import 'package:spideliprovider/widgets/osm_map/map_picker_page.dart';
import 'package:spideliprovider/widgets/osm_map/place_model.dart';
import 'package:spideliprovider/widgets/permission_dialog.dart';
import 'package:spideliprovider/widgets/place_picker/location_picker_screen.dart';
import 'package:spideliprovider/widgets/place_picker/selected_location_model.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:spideliprovider/utils/address_format.dart';

class AddOrUpdateWorkerController extends GetxController {
  Rx<GlobalKey<FormState>> formKey = GlobalKey<FormState>().obs;
  AutovalidateMode validate = AutovalidateMode.disabled;
  Rx<TextEditingController> firstName = TextEditingController().obs;
  Rx<TextEditingController> lastName = TextEditingController().obs;
  Rx<TextEditingController> email = TextEditingController().obs;
  Rx<TextEditingController> mobile = TextEditingController().obs;
  Rx<TextEditingController> address = TextEditingController().obs;
  Rx<TextEditingController> salary = TextEditingController().obs;
  Rx<TextEditingController> password = TextEditingController().obs;
  RxDouble latValue = 0.0.obs, longValue = 0.0.obs;
  Rx<User> user = User().obs;
  RxBool isActive = true.obs;

  @override
  void onInit() {
    super.onInit();
    getArgument();
  }

  void getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      // Edit mode only. A non-map argument, or a missing key, used to throw
      // into this async callback and left the form half-populated.
      final User? passed = argOf<User>(argumentData, 'User');
      if (passed != null) {
        user.value = passed;
        await getAttribute();
      }
    }
    update();
  }

  getAttribute() async {
    firstName.value.text = user.value.firstName;
    lastName.value.text = user.value.lastName;
    email.value.text = user.value.email;
    mobile.value.text = user.value.phoneNumber;
    // `.toString()` on the nullable fields put the literal word "null" into the
    // form whenever the worker had no address or salary on file (bug #17).
    address.value.text = formatAddressText(user.value.address);
    salary.value.text = user.value.salary ?? '';
    latValue.value = user.value.latitude;
    longValue.value = user.value.longitude;
    isActive.value = user.value.active;
  }

  /// True while the map picker is on screen, so repeated taps on the address
  /// field cannot push a second picker on top of the first.
  bool _picking = false;

  /// Picks the worker's location.
  ///
  /// Both pickers pop themselves with their result, so the caller must not pop
  /// again — the extra `Get.back()` that used to run here popped the Add Worker
  /// screen itself, which is what the client saw as "setting the location
  /// closes the screen" (bug #26).
  ///
  /// Everything that can refuse — permission, location services, a geocoder
  /// that returns no placemark — now reports instead of throwing out of the
  /// callback, and the loader is always closed.
  Future<void> pickLocation(BuildContext context) async {
    if (_picking) return;
    _picking = true;
    try {
      final bool granted = await _ensureLocationPermission(context);
      if (!granted) return;

      ShowToastDialog.showLoader("Please wait".tr);
      try {
        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        // A fix is not required to pick a point on the map; the picker falls
        // back to its own default centre.
        log("Worker location: current position unavailable: $e");
      } finally {
        ShowToastDialog.closeLoader();
      }

      if (selectedMapType == 'osm') {
        final dynamic result = await Get.to(() => MapPickerPage());
        if (result == null) return;
        if (result is! PlaceModel) {
          ShowToastDialog.showToast("Could not read the selected location".tr);
          return;
        }
        _applyLocation(result.coordinates.latitude, result.coordinates.longitude, result.address);
      } else {
        final dynamic result = await Get.to(() => const LocationPickerScreen());
        if (result == null) return;
        if (result is! SelectedLocationModel || result.latLng == null) {
          ShowToastDialog.showToast("Could not read the selected location".tr);
          return;
        }
        _applyLocation(result.latLng!.latitude, result.latLng!.longitude, Utils.formatAddress(selectedLocation: result));
      }
    } catch (e, s) {
      log("Worker location pick failed: $e", stackTrace: s);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not set the location, please try again".tr);
    } finally {
      _picking = false;
    }
  }

  /// Keeps the coordinates even when reverse geocoding gave no text back, so a
  /// worker can still be saved against the picked point.
  void _applyLocation(double latitude, double longitude, String? label) {
    latValue.value = latitude;
    longValue.value = longitude;
    final String text = formatAddressText(label);
    address.value.text = text.isNotEmpty ? text : "${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}";
    update();
  }

  /// Asks for the location permission and says why when it is refused, rather
  /// than letting the flow continue into a picker that can never centre.
  Future<bool> _ensureLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        await showDialog(context: context, builder: (_) => PermissionDialog());
      }
      return false;
    }
    if (permission == LocationPermission.denied) {
      ShowToastDialog.showToast('You have to allow location permission to use your location'.tr);
      return false;
    }
    return true;
  }

  signUpWithWorkerEmailAndPassword(workModel, password, BuildContext context) async {
    if (formKey.value.currentState?.validate() ?? false) {
      formKey.value.currentState!.save();
      ShowToastDialog.showLoader('Creating new account worker, Please wait...'.tr);
      try {
        // `Firebase.initializeApp` throws `duplicate-app` the second time a
        // worker is created in the same session; reuse the app when it exists.
        FirebaseApp secondaryApp;
        try {
          secondaryApp = Firebase.app("SecondaryApp");
        } catch (_) {
          secondaryApp = await Firebase.initializeApp(name: "SecondaryApp", options: Firebase.app().options);
        }

        final credential = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(
          email: workModel.email.toString(),
          password: password,
        );

        User worker = User(
            id: credential.user?.uid ?? '',
            firstName: workModel.firstName,
            lastName: workModel.lastName,
            email: workModel.email,
            phoneNumber: workModel.phoneNumber,
            address: workModel.address,
            salary: workModel.salary,
            latitude: workModel.latitude,
            longitude: workModel.longitude,
            geoFireData: workModel.geoFireData,
            providerId: MyAppState.currentUser!.id,
            createdAt: Timestamp.now(),
            active: true);

        await FireStoreUtils.firebaseCreateNewWorker(worker);
        ShowToastDialog.closeLoader();
        Get.back(result: true);
      } on FirebaseAuthException catch (e) {
        // Every branch has to close the loader, otherwise the screen is left
        // behind a spinner that never goes away.
        ShowToastDialog.closeLoader();
        if (e.code == 'weak-password') {
          ShowToastDialog.showToast("The password provided is too weak.".tr);
        } else if (e.code == 'email-already-in-use') {
          ShowToastDialog.showToast("The account already exists for that email.".tr);
        } else {
          ShowToastDialog.showToast(e.message ?? "Could not create the worker account".tr);
        }
      } catch (e, s) {
        ShowToastDialog.closeLoader();
        log("Worker account creation failed: $e", stackTrace: s);
        ShowToastDialog.showToast("Could not create the worker account".tr);
      }
    } else {
      ShowToastDialog.closeLoader();
      validate = AutovalidateMode.onUserInteraction;
      update();
    }
  }
}
