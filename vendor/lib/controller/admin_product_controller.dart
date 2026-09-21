import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/attributes_model.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class AdminProductController extends GetxController {
  RxBool isLoading = true.obs;

  // Rx<UserModel> userModel = UserModel().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  RxList<ProductModel> productList = <ProductModel>[].obs;
  RxList<ProductModel> allProductList = <ProductModel>[].obs;
  RxList<ProductModel> vendorProductList = <ProductModel>[].obs;

  var searchTextController = TextEditingController().obs;
  RxList<AttributesModel> attributesList = <AttributesModel>[].obs;
  RxList<TaxModel> taxList = <TaxModel>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    taxList.value = Constant.taxProductList ?? [];
    getAdminProducts();
    super.onInit();
  }

  Future<void> getAdminProducts() async {
    if (Constant.userModel?.vendorID != null && Constant.userModel?.vendorID?.isNotEmpty == true) {
      await FireStoreUtils.getVendorById(Constant.userModel!.vendorID.toString()).then((value) {
        if (value != null) {
          vendorModel.value = value;
        }
      });
    }

    await FireStoreUtils.getAttributes().then((value) {
      if (value != null) {
        attributesList.value = value;
      }
    });

    await FireStoreUtils.getAdminProduct(vendorModel.value.sectionId.toString()).then((products) {
      if (products != null) {
        allProductList.value = products;
      }
    });
    await getVendorProduct();
    isLoading.value = false;
    update();
    onSearchTextChanged('');
  }

  Future<void> getVendorProduct() async {
    await FireStoreUtils.getProduct().then(
      (value) {
        if (value != null) {
          vendorProductList.value = value;
        }
      },
    );
  }

  void onSearchTextChanged(String text) {
    if (text.isEmpty) {
      productList.clear();
      for (var element in allProductList) {
        productList.add(element);
      }
      return;
    }
    productList.clear();
    for (var element in allProductList) {
      if (element.name!.toLowerCase().contains(text.toLowerCase())) {
        productList.add(element);
      }
    }
    update();
  }

  void toggleSelection(int index, bool value) {
    taxList[index].isSelected = value;
    taxList.refresh();
  }

  List<TaxModel> get selectedTaxes => taxList.where((e) => e.isSelected).toList();
}
