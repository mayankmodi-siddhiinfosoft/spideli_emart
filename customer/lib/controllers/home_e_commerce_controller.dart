import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/models/advertisement_model.dart';
import 'package:customer/models/banner_model.dart';
import 'package:customer/models/brands_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/vendor_category_model.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/service/cart_provider.dart';
import 'package:customer/service/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/constant.dart';
import '../service/database_helper.dart';
import '../themes/custom_dialog_box.dart';
import '../utils/wholesale_pricing.dart';

class HomeECommerceController extends GetxController {
  final CartProvider cartProvider = CartProvider();

  Future<void> getCartData() async {
    cartProvider.cartStream.listen((event) async {
      cartItem.clear();
      cartItem.addAll(event);
    });
    update();
  }

  RxBool isLoading = true.obs;
  RxBool isListView = true.obs;
  RxBool isPopular = true.obs;

  /// Delivery / TakeAway order type (the app's existing mode, spec 7.3).
  RxString selectedOrderTypeValue = OrderTypeMode.current.obs;

  /// Same behaviour as the food home toggle: a non-empty cart is emptied after confirmation.
  void changeOrderType(BuildContext context, String value) {
    final String type = OrderTypeMode.normalise(value);
    if (type == selectedOrderTypeValue.value) return;
    Future<void> apply() async {
      await OrderTypeMode.set(type);
      selectedOrderTypeValue.value = type;
    }

    if (cartItem.isEmpty) {
      apply();
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomDialogBox(
          title: "Alert".tr,
          descriptions: "Do you really want to change the delivery option? Your cart will be empty.".tr,
          positiveString: "Ok".tr,
          negativeString: "Cancel".tr,
          positiveClick: () async {
            await apply();
            DatabaseHelper.instance.deleteAllCartProducts();
            cartProvider.clearDatabase();
            getCartData();
            Get.back();
          },
          negativeClick: () {
            Get.back();
          },
          img: null,
        );
      },
    );
  }

  Rx<PageController> pageController = PageController(viewportFraction: 0.877).obs;
  Rx<PageController> pageBottomController = PageController(viewportFraction: 0.877).obs;
  RxInt currentPage = 0.obs;
  RxInt currentBottomPage = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getVendorCategory();
    getData();
    super.onInit();
  }

  RxList<VendorCategoryModel> vendorCategoryModel = <VendorCategoryModel>[].obs;
  RxList<VendorCategoryModel> categoryWiseProductList = <VendorCategoryModel>[].obs;

  RxList<VendorModel> allNearestRestaurant = <VendorModel>[].obs;
  RxList<VendorModel> newArrivalRestaurantList = <VendorModel>[].obs;
  RxList<AdvertisementModel> advertisementList = <AdvertisementModel>[].obs;

  RxList<BannerModel> bannerModel = <BannerModel>[].obs;
  RxList<BannerModel> bannerBottomModel = <BannerModel>[].obs;
  RxList<BrandsModel> brandList = <BrandsModel>[].obs;

  Future<void> getData() async {
    isLoading.value = true;
    getCartData();
    FireStoreUtils.getAllNearestRestaurant(ecommarce: true).listen((event) async {
      print("=====>${event.length}");

      newArrivalRestaurantList.clear();
      allNearestRestaurant.clear();
      advertisementList.clear();

      allNearestRestaurant.addAll(event);
      newArrivalRestaurantList.addAll(event);
      Constant.restaurantList = allNearestRestaurant;
      List<String> usedCategoryIds = allNearestRestaurant.expand((vendor) => vendor.categoryID ?? []).whereType<String>().toSet().toList();
      vendorCategoryModel.value = vendorCategoryModel.where((category) => usedCategoryIds.contains(category.id)).toList();

      newArrivalRestaurantList.sort((a, b) => (b.createdAt ?? Timestamp.now()).toDate().compareTo((a.createdAt ?? Timestamp.now()).toDate()));

      if (Constant.isEnableAdsFeature == true) {
        await FireStoreUtils.getAllAdvertisement().then((value) {
          advertisementList.clear();
          for (var element1 in value) {
            for (var element in allNearestRestaurant) {
              if (element1.vendorId == element.id) {
                advertisementList.add(element1);
              }
            }
          }
        });
      }
    });
    setLoading();
  }

  Future<void> setLoading() async {
    await Future.delayed(Duration(seconds: 1), () async {
      if (allNearestRestaurant.isEmpty) {
        await Future.delayed(Duration(seconds: 2), () {
          isLoading.value = false;
        });
      } else {
        isLoading.value = false;
      }
      update();
    });
  }

  Future<void> getVendorCategory() async {
    await FireStoreUtils.getHomeVendorCategory().then((value) {
      vendorCategoryModel.value = value;
    });
    await FireStoreUtils.getHomePageShowCategory().then((value) {
      categoryWiseProductList.value = value;
    });

    await FireStoreUtils.getHomeTopBanner().then((value) {
      bannerModel.value = value;
    });

    await FireStoreUtils.getHomeBottomBanner().then((value) {
      bannerBottomModel.value = value;
    });

    await FireStoreUtils.getBrandList().then((value) {
      brandList.value = value;
    });
    await getFavouriteRestaurant();
  }

  RxList<FavouriteModel> favouriteList = <FavouriteModel>[].obs;

  Future<void> getFavouriteRestaurant() async {
    if (Constant.userModel?.id != null) {
      await FireStoreUtils.getFavouriteRestaurant().then((value) {
        favouriteList.value = value;
      });
    }
  }
}
