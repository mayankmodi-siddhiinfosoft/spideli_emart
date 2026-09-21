import 'dart:developer';

import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/models/favourite_item_model.dart';
import 'package:customer/models/favourite_model.dart';
import 'package:customer/models/product_model.dart';
import 'package:customer/models/vendor_model.dart';
import '../service/fire_store_utils.dart';
import 'package:get/get.dart';

class FavouriteController extends GetxController {
  RxBool favouriteRestaurant = true.obs;
  RxList<FavouriteModel> favouriteList = <FavouriteModel>[].obs;
  RxList<VendorModel> favouriteVendorList = <VendorModel>[].obs;

  RxList<FavouriteItemModel> favouriteItemList = <FavouriteItemModel>[].obs;
  RxList<ProductModel> favouriteFoodList = <ProductModel>[].obs;

  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    reset();
    if (Constant.userModel != null) {
      await FireStoreUtils.getFavouriteRestaurant().then((value) {
        favouriteList.value = value;
      });

      await FireStoreUtils.getFavouriteItem().then((value) {
        favouriteItemList.value = value;
      });
      List<VendorModel> favouriteVendorData = [];
      for (var element in favouriteList) {
        await FireStoreUtils.getVendorById(element.restaurantId.toString()).then((value) async {
          if (value != null) {
            if ((Constant.isSubscriptionModelApplied == true || value.adminCommission?.isEnabled == true) && value.subscriptionPlan != null) {
              if (value.subscriptionTotalOrders == "-1") {
                favouriteVendorData.add(value);
              } else {
                if ((value.subscriptionExpiryDate != null && value.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) || value.subscriptionPlan?.expiryDay == '-1') {
                  if (value.subscriptionTotalOrders != '0') {
                    favouriteVendorData.add(value);
                  }
                }
              }
            } else {
              favouriteVendorData.add(value);
            }
          }
        });
      }
      favouriteVendorData.sort((a, b) {
        final aOpen = Constant.statusCheckOpenORClose(vendorModel: a);
        final bOpen = Constant.statusCheckOpenORClose(vendorModel: b);
        if (aOpen == bOpen) return 0;
        return aOpen ? -1 : 1;
      });
      favouriteVendorList.value = favouriteVendorData;

      for (var element in favouriteItemList) {
        await FireStoreUtils.getProductById(element.productId.toString()).then((value) async {
          log("getProductById :: ${value?.name} :: ${value?.publish}");
          if (value != null && value.publish == true) {
            await FireStoreUtils.fireStore.collection(CollectionName.vendors).doc(value.vendorID.toString()).get().then((value1) async {
              if (value1.exists) {
                VendorModel vendorModel = VendorModel.fromJson(value1.data()!);
                if (Constant.isSubscriptionModelApplied == true || vendorModel.adminCommission?.isEnabled == true) {
                  if (vendorModel.subscriptionPlan != null) {
                    if (vendorModel.subscriptionTotalOrders == "-1") {
                      favouriteFoodList.add(value);
                    } else {
                      if ((vendorModel.subscriptionExpiryDate != null && vendorModel.subscriptionExpiryDate!.toDate().isBefore(DateTime.now()) == false) ||
                          vendorModel.subscriptionPlan?.expiryDay == "-1") {
                        if (vendorModel.subscriptionTotalOrders != '0') {
                          favouriteFoodList.add(value);
                        }
                      }
                    }
                  }
                } else {
                  favouriteFoodList.add(value);
                }
              }
            });
          }
        });
      }
    }
    List<ProductModel> favouriteFoodData = favouriteFoodList;
    List<VendorModel> favouriteVendorData = favouriteVendorList;
    favouriteFoodList.value = removeDuplicateFoods(favouriteFoodData);
    favouriteVendorList.value = removeDuplicateVendor(favouriteVendorData);
    isLoading.value = false;
  }

  void reset() {
    favouriteRestaurant.value = true;
    favouriteList.value = [];
    favouriteVendorList.value = [];
    favouriteItemList.value = [];
    favouriteFoodList.value = [];
    isLoading.value = true;
  }

  List<ProductModel> removeDuplicateFoods(List<ProductModel> favouriteFoodList) {
    final seenIds = <String>{};
    return favouriteFoodList.where((food) {
      return seenIds.add(food.id!);
    }).toList();
  }

  List<VendorModel> removeDuplicateVendor(List<VendorModel> favouriteFoodVendor) {
    final seenIds = <String>{};
    return favouriteFoodVendor.where((food) {
      return seenIds.add(food.id!);
    }).toList();
  }
}
