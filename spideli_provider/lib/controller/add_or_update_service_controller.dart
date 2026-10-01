import 'dart:developer';

import 'package:geolocator/geolocator.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/utils/utils.dart';
import 'package:spideliprovider/widgets/osm_map/map_picker_page.dart';
import 'package:spideliprovider/widgets/osm_map/place_model.dart';
import 'package:spideliprovider/widgets/permission_dialog.dart';
import 'package:spideliprovider/widgets/place_picker/location_picker_screen.dart';
import 'package:spideliprovider/widgets/place_picker/selected_location_model.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/category_model.dart';
import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/model/sectionModel.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spideliprovider/utils/address_format.dart';

class AddOrUpdateServiceController extends GetxController {
  Rx<TextEditingController> serviceName = TextEditingController().obs;
  Rx<TextEditingController> description = TextEditingController().obs;
  Rx<TextEditingController> address = TextEditingController().obs;
  Rx<GlobalKey<FormState>> formKey = GlobalKey<FormState>().obs;
  Rx<TextEditingController> rprice = TextEditingController().obs;
  Rx<TextEditingController> disprice = TextEditingController().obs;
  AutovalidateMode validate = AutovalidateMode.disabled;
  final ImagePicker imagePicker = ImagePicker();
  RxList<dynamic> mediaFiles = <dynamic>[].obs;
  Rx<ProviderServiceModel> serviceModel = ProviderServiceModel().obs;

  RxList<CategoryModel> subCategoryList = <CategoryModel>[].obs;
  Rx<CategoryModel> selectedSubCategory = CategoryModel().obs;

  RxList<CategoryModel> categoryVal = <CategoryModel>[].obs;
  Rx<CategoryModel> selectedCategory = CategoryModel().obs;

  RxBool isDiscountedPriceOk = false.obs;

  /// Customers only ever see `publish == true` services (the on-demand lists
  /// query `where('publish', isEqualTo: true)`). This used to default to false,
  /// so every newly added service was saved hidden and could never be booked
  /// unless the provider happened to notice the toggle. The model's own default
  /// is true; match it.
  RxBool publish = true.obs;
  RxDouble latValue = 0.0.obs, longValue = 0.0.obs;

  RxString? startTime = ''.obs, endTime = ''.obs;
  RxString? priceUnit = "".obs;
  RxList<String> priceUnitList = <String>['Hourly', 'Fixed'].obs;
  RxList<String>? selectedDays = <String>[].obs;
  RxList<String>? selectedDaysList = <String>['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].obs;

  RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    getArgument();
  }

  /// True while the map picker is on screen, so repeated taps cannot push a
  /// second picker on top of the first.
  bool _picking = false;

  /// Picks the service address. Same flow as the worker form: neither picker
  /// needs a `Get.back()` from the caller (they pop themselves), a refused
  /// permission or an empty geocoder result reports instead of throwing, and
  /// the old fallback that silently wrote a hard-coded Mumbai address into the
  /// field on any error is gone.
  Future<void> pickLocation(BuildContext context) async {
    if (_picking) return;
    _picking = true;
    try {
      final bool granted = await ensureLocationPermission(context);
      if (!granted) return;

      ShowToastDialog.showLoader("Please wait".tr);
      try {
        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        log("Service location: current position unavailable: $e");
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
      log("Service location pick failed: $e", stackTrace: s);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Could not set the location, please try again".tr);
    } finally {
      _picking = false;
    }
  }

  void _applyLocation(double latitude, double longitude, String? label) {
    latValue.value = latitude;
    longValue.value = longitude;
    final String text = formatAddressText(label);
    address.value.text = text.isNotEmpty ? text : "${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}";
    update();
  }

  /// Asks for the location permission and says why when it is refused.
  Future<bool> ensureLocationPermission(BuildContext context) async {
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

  void getArgument() async {
    await getData();
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      serviceModel.value = argumentData['providerModel'];
      await getAttribute();
    }

    isLoading.value = false;
    update();
  }

  RxList<SectionModel> sectionList = <SectionModel>[].obs;
  Rx<SectionModel> selectedSection = SectionModel().obs;

  getData() async {
    if (MyAppState.currentUser?.sectionId != null && MyAppState.currentUser?.sectionId != '') {
      await FireStoreUtils.firestore.collection(sections).doc(MyAppState.currentUser?.sectionId).get().then((value) {
        SectionModel sectionModel = SectionModel.fromJson(value.data()!);
        if (sectionModel.isActive == true) {
          sectionList.add(sectionModel);
          selectedSection.value = sectionModel;
        }
      });
      await FireStoreUtils.getCategory(selectedSection.value.id.toString()).then((value) {
        categoryVal.value = value;
      });
    } else if ((MyAppState.currentUser?.sectionId == null || MyAppState.currentUser?.sectionId == '') || (isSubscriptionModelApplied == false && selectedSection.value.adminCommision == false)) {
      sectionList.clear();
      await FireStoreUtils.firestore.collection(sections).where("serviceTypeFlag", isEqualTo: "ondemand-service").where("isActive", isEqualTo: true).get().then((value) {
        value.docs.forEach((element) {
          SectionModel sectionModel = SectionModel.fromJson(element.data());
          sectionList.add(sectionModel);
        });
      });
    }
    update();
  }

  /// Strips the literal "null" an older `.toString()` on a missing field wrote
  /// into Firestore, so it is never re-displayed or re-saved. A "null"
  /// `priceUnit` also used to crash this screen: it matched no dropdown item
  /// and tripped the "exactly one item" assertion.
  String _clean(Object? value) {
    final String s = value?.toString().trim() ?? '';
    return (s.isEmpty || s.toLowerCase() == 'null') ? '' : s;
  }

  getAttribute() async {
    serviceName.value.text = _clean(serviceModel.value.title);
    rprice.value.text = _clean(serviceModel.value.price);
    description.value.text = _clean(serviceModel.value.description);
    disprice.value.text = _clean(serviceModel.value.disPrice);
    publish.value = serviceModel.value.publish ?? true;
    isDiscountedPriceOk.value = false;
    startTime!.value = _clean(serviceModel.value.startTime);
    endTime!.value = _clean(serviceModel.value.endTime);
    address.value.text = formatAddressText(serviceModel.value.address);
    final String unit = _clean(serviceModel.value.priceUnit);
    priceUnit!.value = priceUnitList.contains(unit) ? unit : '';
    latValue.value = serviceModel.value.latitude ?? 0.0;
    longValue.value = serviceModel.value.longitude ?? 0.0;
    mediaFiles.addAll(serviceModel.value.photos);
    for (var element in serviceModel.value.days) {
      selectedDays!.add(element);
    }

    sectionList.forEach((element) async {
      if (element.id == serviceModel.value.sectionId) {
        selectedSection.value = element;
      }

      await FireStoreUtils.getCategory(selectedSection.value.id.toString()).then((value) {
        categoryVal.value = value;
      });

      categoryVal.forEach((element) {
        if (element.id == serviceModel.value.categoryId) {
          selectedCategory.value = element;
        }
      });

      await FireStoreUtils.getSubCategory(selectedCategory.value.id.toString()).then((value) {
        subCategoryList.value = value;
        subCategoryList.forEach((element) {
          if (element.id == serviceModel.value.subCategoryId) {
            selectedSubCategory.value = element;
          }
        });
      });
    });

    update();
  }
}
