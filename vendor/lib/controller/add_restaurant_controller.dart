import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/region_model.dart';
import 'package:vendor/models/section_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_category_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/models/zone_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/region_service.dart';
import 'package:vendor/widget/geoflutterfire/src/geoflutterfire.dart';

class AddRestaurantController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool isAddressEnable = false.obs;
  RxBool isEnableDeliverySettings = true.obs;
  final myKey1 = GlobalKey<DropdownSearchState<VendorCategoryModel>>();

  Rx<TextEditingController> restaurantNameController = TextEditingController().obs;
  Rx<TextEditingController> restaurantDescriptionController = TextEditingController().obs;
  Rx<TextEditingController> mobileNumberController = TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController = TextEditingController().obs;
  Rx<TextEditingController> countryISOCodeEditingController = TextEditingController().obs;
  Rx<TextEditingController> addressController = TextEditingController().obs;

  Rx<TextEditingController> chargePerKmController = TextEditingController().obs;
  Rx<TextEditingController> minDeliveryChargesController = TextEditingController().obs;
  Rx<TextEditingController> minDeliveryChargesWithinKMController = TextEditingController().obs;

  Rx<TextEditingController> packagingChargeAmountController = TextEditingController().obs;

  LatLng? selectedLocation;

  RxList images = <dynamic>[].obs;

  RxList<VendorCategoryModel> vendorCategoryList = <VendorCategoryModel>[].obs;
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;

  /// Every published zone; [zoneList] is the subset shown for [selectedRegion].
  RxList<ZoneModel> allZoneList = <ZoneModel>[].obs;
  RxList<RegionModel> regionList = <RegionModel>[].obs;
  Rx<RegionModel> selectedRegion = RegionModel().obs;

  // Rx<VendorCategoryModel> selectedCategory = VendorCategoryModel().obs;
  RxList selectedService = [].obs;

  RxList<VendorCategoryModel> selectedCategories = <VendorCategoryModel>[].obs;

  RxBool canShowQRCodeButton = false.obs;

  /// Opened from My Stores to add another store to this account: the form
  /// starts empty and saving creates a new store instead of editing the
  /// current one.
  final bool isNewStore = Get.arguments is Map && (Get.arguments as Map)['newStore'] == true;

  @override
  void onInit() {
    // TODO: implement onInit
    getRestaurant();
    super.onInit();
    Future.delayed(const Duration(seconds: 3), () {
      if (userModel.value.subscriptionPlan?.features?.qrCodeGenerate == true) {
        canShowQRCodeButton.value = true;
      }
    });
  }

  Rx<UserModel> userModel = UserModel().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  Rx<DeliveryCharge> deliveryChargeModel = DeliveryCharge().obs;
  RxBool isSelfDelivery = false.obs;
  RxList<SectionModel> sectionsList = <SectionModel>[].obs;
  Rx<SectionModel> selectedSectionModel = SectionModel().obs;

  Future<void> getRestaurant() async {
    try {
      await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((model) {
        if (model != null) {
          userModel.value = model;
        }
      });
      await RegionService.ensureLoaded();
      regionList.value = RegionService.regions;

      await FireStoreUtils.getSection().then((value) async {
        sectionsList.value = value.where((element) => element.serviceTypeFlag == "ecommerce-service" || element.serviceTypeFlag == "delivery-service").toList();
      });

      if (userModel.value.sectionId != null || userModel.value.sectionId!.isNotEmpty) {
        selectedSectionModel.value = sectionsList.firstWhere((element) => element.id == userModel.value.sectionId);
        vendorCategoryList.value = await FireStoreUtils.getVendorCategoryById(selectedSectionModel.value.id.toString());
        if (vendorCategoryList.isEmpty) {
          ShowToastDialog.showToast("No category for this section".tr);
        }

        await FireStoreUtils.getZone(userModel.value.sectionId.toString()).then((value) {
          if (value != null) {
            allZoneList.value = value;
            zoneList.value = value;
          }
        });
      }

      if (!isNewStore && Constant.userModel?.vendorID != null && Constant.userModel?.vendorID?.isNotEmpty == true) {
        await FireStoreUtils.getVendorById(Constant.userModel!.vendorID.toString()).then((value) {
          if (value != null) {
            vendorModel.value = value;

            restaurantNameController.value.text = vendorModel.value.title.toString();
            restaurantDescriptionController.value.text = vendorModel.value.description.toString();
            mobileNumberController.value.text = vendorModel.value.phonenumber.toString();
            addressController.value.text = vendorModel.value.location.toString();
            isSelfDelivery.value = vendorModel.value.isSelfDelivery ?? false;

            packagingChargeAmountController.value.text = vendorModel.value.packagingCharge != null ? vendorModel.value.packagingCharge.toString() : '0';

            if (addressController.value.text.isNotEmpty) {
              isAddressEnable.value = true;
            }
            selectedLocation = LatLng(vendorModel.value.latitude!, vendorModel.value.longitude!);
            for (var element in vendorModel.value.photos!) {
              images.add(element);
            }

            for (var element in zoneList) {
              if (element.id == vendorModel.value.zoneId) {
                selectedZone.value = element;
              }
            }

            if (vendorModel.value.categoryID!.isNotEmpty) {
              selectedCategories.value = vendorCategoryList.where((category) => vendorModel.value.categoryID!.contains(category.id)).toList();
            }

            vendorModel.value.filters!.toJson().forEach((key, value) {
              if (value.contains("Yes")) {
                selectedService.add(key);
              }
            });
          }
        });
      }

      await _initRegion();

      // settings/DeliveryCharge: the store region's figures when the admin set
      // them (`regions[regionId]`), else the global ones.
      await RegionService.getDeliveryCharge(selectedRegion.value.id).then((value) {
        if (value != null) {
          _applyDeliveryCharge(value);
        }
      });
    } catch (e) {
      print(e);
    }

    isLoading.value = false;
  }

  void _applyDeliveryCharge(DeliveryCharge value) {
    deliveryChargeModel.value = value;
    isEnableDeliverySettings.value = deliveryChargeModel.value.vendorCanModify ?? false;
    if (value.vendorCanModify == true) {
      if (vendorModel.value.deliveryCharge != null) {
        chargePerKmController.value.text = vendorModel.value.deliveryCharge!.deliveryChargesPerKm.toString();
        minDeliveryChargesController.value.text = vendorModel.value.deliveryCharge!.minimumDeliveryCharges.toString();
        minDeliveryChargesWithinKMController.value.text = vendorModel.value.deliveryCharge!.minimumDeliveryChargesWithinKm.toString();
      } else {
        // A store with no charges of its own yet (e.g. one being added) starts
        // from the region's / platform's figures.
        chargePerKmController.value.text = (value.deliveryChargesPerKm ?? 0).toString();
        minDeliveryChargesController.value.text = (value.minimumDeliveryCharges ?? 0).toString();
        minDeliveryChargesWithinKMController.value.text = (value.minimumDeliveryChargesWithinKm ?? 0).toString();
      }
    } else {
      chargePerKmController.value.text = deliveryChargeModel.value.deliveryChargesPerKm.toString();
      minDeliveryChargesController.value.text = deliveryChargeModel.value.minimumDeliveryCharges.toString();
      minDeliveryChargesWithinKMController.value.text = deliveryChargeModel.value.minimumDeliveryChargesWithinKm.toString();
    }
  }

  /// Preselects the store's region: `vendors.regionId`, else its zone's
  /// `regionId` (existing stores saved before regions existed).
  Future<void> _initRegion() async {
    String? regionId = vendorModel.value.regionId;
    final String? zoneId = vendorModel.value.zoneId;
    if ((regionId == null || regionId.isEmpty) && zoneId != null && zoneId.isNotEmpty) {
      regionId = allZoneList.where((zone) => zone.id == zoneId).firstOrNull?.regionId ?? await RegionService.regionIdForZone(zoneId);
    }
    selectedRegion.value = regionList.where((region) => region.id == regionId).firstOrNull ?? RegionModel();
    _filterZones();
  }

  /// Zones that serve the selected region. No region selected (or no regions
  /// at all) = every zone, as before.
  void _filterZones() {
    final String? regionId = selectedRegion.value.id;
    if (regionId == null) {
      zoneList.value = allZoneList.toList();
    } else {
      // A zone may serve several regions (`regionIds`); zones with no region
      // data serve all of them.
      zoneList.value = allZoneList.where((zone) => zone.belongsToRegion(regionId)).toList();
    }
    // Drop a zone selection that doesn't belong to the region.
    if (selectedZone.value.id != null && !zoneList.any((zone) => zone.id == selectedZone.value.id)) {
      selectedZone.value = ZoneModel();
    }
  }

  void onRegionChanged(RegionModel region) {
    selectedRegion.value = region;
    _filterZones();
    final DeliveryCharge? charge = RegionService.deliveryChargeForRegion(region.id);
    if (charge != null) {
      _applyDeliveryCharge(charge);
    }
    update();
  }

  Future<void> saveDetails() async {
    if (restaurantNameController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter store name".tr);
    } else if (restaurantDescriptionController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter Description".tr);
    } else if (mobileNumberController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter phone number".tr);
    } else if (addressController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter address".tr);
    } else if (regionList.isNotEmpty && selectedRegion.value.id == null) {
      ShowToastDialog.showToast("Please select region".tr);
    } else if (selectedZone.value.id == null) {
      ShowToastDialog.showToast("Please select zone".tr);
    } else if (selectedCategories.isEmpty) {
      ShowToastDialog.showToast("Please select category".tr);
    } else {
      if (Constant.isPointInPolygon(selectedLocation!, selectedZone.value.area!)) {
        ShowToastDialog.showLoader("Please wait...".tr);
        filter();
        DeliveryCharge deliveryChargeModel = DeliveryCharge(
          vendorCanModify: true,
          deliveryChargesPerKm: num.tryParse(chargePerKmController.value.text) ?? 0,
          minimumDeliveryCharges: num.tryParse(minDeliveryChargesController.value.text) ?? 0,
          minimumDeliveryChargesWithinKm: num.tryParse(minDeliveryChargesWithinKMController.value.text) ?? 0,
        );

        if (vendorModel.value.id == null) {
          vendorModel.value = VendorModel();
          vendorModel.value.createdAt = Timestamp.now();
        }
        for (int i = 0; i < images.length; i++) {
          if (images[i].runtimeType == XFile) {
            String url = await Constant.uploadUserImageToFireStorage(File(images[i].path), "profileImage/${FireStoreUtils.getCurrentUid()}", File(images[i].path).path.split('/').last);
            images.removeAt(i);
            images.insert(i, url);
          }
        }

        vendorModel.value.id = isNewStore ? null : Constant.userModel?.vendorID;
        vendorModel.value.author = Constant.userModel!.id;
        vendorModel.value.authorName = Constant.userModel!.firstName;
        vendorModel.value.authorProfilePic = Constant.userModel!.profilePictureURL;

        vendorModel.value.categoryID = selectedCategories.map((e) => e.id ?? '').toList();
        vendorModel.value.categoryTitle = selectedCategories.map((e) => e.title ?? '').toList();
        vendorModel.value.g = G(
          geohash: Geoflutterfire().point(latitude: selectedLocation!.latitude, longitude: selectedLocation!.longitude).hash,
          geopoint: GeoPoint(selectedLocation!.latitude, selectedLocation!.longitude),
        );
        vendorModel.value.description = restaurantDescriptionController.value.text;
        vendorModel.value.phonenumber = mobileNumberController.value.text;
        vendorModel.value.filters = Filters.fromJson(filters);
        vendorModel.value.location = addressController.value.text;
        vendorModel.value.latitude = selectedLocation!.latitude;
        vendorModel.value.longitude = selectedLocation!.longitude;
        vendorModel.value.photos = images;
        vendorModel.value.sectionId = selectedSectionModel.value.id;
        if (images.isNotEmpty) {
          vendorModel.value.photo = images.first;
        } else {
          vendorModel.value.photo = null;
        }

        vendorModel.value.deliveryCharge = deliveryChargeModel;
        vendorModel.value.title = restaurantNameController.value.text;
        vendorModel.value.zoneId = selectedZone.value.id;
        if (selectedRegion.value.id != null) {
          vendorModel.value.regionId = selectedRegion.value.id;
        }
        vendorModel.value.isSelfDelivery = isSelfDelivery.value;
        vendorModel.value.packagingCharge = packagingChargeAmountController.value.text.isNotEmpty ? packagingChargeAmountController.value.text : '0';

        if (selectedSectionModel.value.adminCommision!.isEnabled == true || Constant.isSubscriptionModelApplied == true) {
          vendorModel.value.subscriptionPlanId = userModel.value.subscriptionPlanId;
          vendorModel.value.subscriptionPlan = userModel.value.subscriptionPlan;
          vendorModel.value.subscriptionExpiryDate = userModel.value.subscriptionExpiryDate;
          vendorModel.value.subscriptionTotalOrders = userModel.value.subscriptionPlan?.orderLimit;
        }

        if (!isNewStore && Constant.userModel!.vendorID!.isNotEmpty) {
          await FireStoreUtils.updateVendor(vendorModel.value).then((value) {
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Store details save successfully".tr);
          });
        } else {
          vendorModel.value.adminCommission = selectedSectionModel.value.adminCommision!;
          vendorModel.value.workingHours = [
            WorkingHours(
              day: 'Monday',
              timeslot: [Timeslot(from: '00:00', to: '23:59')],
            ),
            WorkingHours(
              day: 'Tuesday',
              timeslot: [Timeslot(from: '00:00', to: '23:59')],
            ),
            WorkingHours(
              day: 'Wednesday',
              timeslot: [Timeslot(from: '00:00', to: '23:59')],
            ),
            WorkingHours(
              day: 'Thursday',
              timeslot: [Timeslot(from: '00:00', to: '23:59')],
            ),
            WorkingHours(
              day: 'Friday',
              timeslot: [Timeslot(from: '00:00', to: '23:59')],
            ),
            WorkingHours(
              day: 'Saturday',
              timeslot: [Timeslot(from: '00:00', to: '23:59')],
            ),
            WorkingHours(
              day: 'Sunday',
              timeslot: [Timeslot(from: '00:00', to: '23:59')],
            ),
          ];
          // The session's product taxes belong to the store being worked on; an
          // additional store must not replace them.
          if (!isNewStore && vendorModel.value.latitude != null && vendorModel.value.longitude != null) {
            await FireStoreUtils.getTaxList(double.parse("${vendorModel.value.latitude}"), double.parse("${vendorModel.value.longitude}"), vendorModel.value.sectionId.toString()).then((value) {
              Constant.taxProductList = value!.where((TaxModel taxModel) => taxModel.scope == "product").toList();
            });
          }
          await FireStoreUtils.firebaseCreateNewVendor(vendorModel.value, selectAsCurrent: !isNewStore).then((value) {
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Store details save successfully".tr);
            if (isNewStore) {
              Get.back(result: true);
            }
          });
        }
        // The store's region may have changed: refresh the live currency - but
        // only for the store being worked on, not a newly added one.
        if (!isNewStore) {
          await RegionService.applyStore(vendorModel.value);
        }
      } else {
        ShowToastDialog.showToast("The chosen area is outside the selected zone.".tr);
      }
    }
  }

  Map<String, dynamic> filters = {};

  void filter() {
    if (selectedService.contains('Good for Breakfast')) {
      filters['Good for Breakfast'] = 'Yes';
    } else {
      filters['Good for Breakfast'] = 'No';
    }
    if (selectedService.contains('Good for Lunch')) {
      filters['Good for Lunch'] = 'Yes';
    } else {
      filters['Good for Lunch'] = 'No';
    }

    if (selectedService.contains('Good for Dinner')) {
      filters['Good for Dinner'] = 'Yes';
    } else {
      filters['Good for Dinner'] = 'No';
    }

    if (selectedService.contains('Takes Reservations')) {
      filters['Takes Reservations'] = 'Yes';
    } else {
      filters['Takes Reservations'] = 'No';
    }

    if (selectedService.contains('Vegetarian Friendly')) {
      filters['Vegetarian Friendly'] = 'Yes';
    } else {
      filters['Vegetarian Friendly'] = 'No';
    }

    if (selectedService.contains('Live Music')) {
      filters['Live Music'] = 'Yes';
    } else {
      filters['Live Music'] = 'No';
    }

    if (selectedService.contains('Outdoor Seating')) {
      filters['Outdoor Seating'] = 'Yes';
    } else {
      filters['Outdoor Seating'] = 'No';
    }

    if (selectedService.contains('Free Wi-Fi')) {
      filters['Free Wi-Fi'] = 'Yes';
    } else {
      filters['Free Wi-Fi'] = 'No';
    }
  }

  final ImagePicker _imagePicker = ImagePicker();

  Future pickFile({required ImageSource source}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      images.add(image);
      Get.back();
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("${"Failed to Pick :".tr} \n $e");
    }
  }
}
