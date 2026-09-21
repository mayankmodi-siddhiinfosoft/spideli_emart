import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class ProductListController extends GetxController {
  @override
  void onInit() {
    // TODO: implement onInit
    getUserProfile();
    super.onInit();
  }

  Rx<UserModel> userModel = UserModel().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  RxBool isLoading = true.obs;
  RxList<TaxModel> taxList = <TaxModel>[].obs;

  Future<void> getUserProfile() async {
    taxList.value = Constant.taxProductList ?? [];

    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        Constant.userModel = value;
        userModel.value = value;
      }
    });
    await getProduct();
    isLoading.value = false;
  }

  RxList<ProductModel> productList = <ProductModel>[].obs;

  Future<void> getProduct() async {
    if (userModel.value.vendorID != null) {
      await FireStoreUtils.getVendorById(userModel.value.vendorID ?? '').then((value) {
        if (value != null) {
          vendorModel.value = value;
        }
      });
    }
    await FireStoreUtils.getProduct().then((value) {
      if (value != null) {
        productList.value = value;
      }
    });
  }

  Future<void> updateList(int index, bool isPublish) async {
    ProductModel productModel = productList[index];
    if (isPublish == true) {
      productModel.publish = false;
    } else {
      productModel.publish = true;
    }

    productList.removeAt(index);
    productList.insert(index, productModel);
    update();
    await FireStoreUtils.setProduct(productModel);
  }

  void toggleSelection(int index, bool value) {
    taxList[index].isSelected = value;
    taxList.refresh();
  }

  List<TaxModel> get selectedTaxes => taxList.where((e) => e.isSelected).toList();
  List<ProductModel> get selectedProducts => productList.where((p) => selectedProductIds.contains(p.id)).toList();

  RxSet<String> selectedProductIds = <String>{}.obs;

  void toggleProductSelection(ProductModel product) {
    if (selectedProductIds.contains(product.id)) {
      selectedProductIds.remove(product.id);
    } else {
      selectedProductIds.add(product.id.toString());
    }
  }

  void clearSelection() {
    selectedProductIds.clear();
  }

  String getTaxDisplayText(List<TaxModel>? taxes) {
    if (taxes == null || taxes.isEmpty) return '';

    return taxes
        .map((tax) {
          if (tax.type == "fix") {
            return "${tax.title} (${Constant.amountShow(amount: tax.tax)})";
          } else {
            return "${tax.title} (${tax.tax}%)";
          }
        })
        .join(', ');
  }
}
