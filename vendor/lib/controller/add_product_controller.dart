import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/models/attributes_model.dart';
import 'package:vendor/models/ai_title_description_model.dart';
import 'package:vendor/models/ai_variant_data_model.dart';
import 'package:vendor/models/brands_model.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/models/vendor_category_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/service/api.dart';
import 'package:http/http.dart' as http;
import 'package:vendor/utils/fire_store_utils.dart';

class AddProductController extends GetxController {
  RxBool isLoading = true.obs;
  Rx<TextEditingController> attributesValueController = TextEditingController().obs;

  Rx<TextEditingController> productTitleController = TextEditingController().obs;
  Rx<TextEditingController> productDescriptionController = TextEditingController().obs;
  Rx<TextEditingController> regularPriceController = TextEditingController().obs;
  Rx<TextEditingController> discountedPriceController = TextEditingController().obs;
  Rx<TextEditingController> productQuantityController = TextEditingController().obs;
  Rx<TextEditingController> caloriesController = TextEditingController().obs;
  Rx<TextEditingController> gramsController = TextEditingController().obs;
  Rx<TextEditingController> proteinController = TextEditingController().obs;
  Rx<TextEditingController> fatsController = TextEditingController().obs;

  Rx<ItemAttribute?> itemAttributes = ItemAttribute(attributes: [], variants: []).obs;

  RxList<VendorCategoryModel> vendorCategoryList = <VendorCategoryModel>[].obs;
  Rx<VendorCategoryModel> selectedProductCategory = VendorCategoryModel().obs;

  RxList<BrandsModel> brandsList = <BrandsModel>[].obs;
  Rx<BrandsModel> selectedBrands = BrandsModel().obs;

  RxList<String> digitalProduct = ["Yes", "No"].obs;
  RxString selectedDigital = "No".obs;
  RxString digitalProductFileName = "".obs;

  final myKey1 = GlobalKey<DropdownSearchState<AttributesModel>>();

  Rx<ProductModel> productModel = ProductModel().obs;
  Rx<VendorModel> vendorModel = VendorModel().obs;
  RxList images = <dynamic>[].obs;

  RxList<AttributesModel> attributesList = <AttributesModel>[].obs;
  RxList<AttributesModel> selectedAttributesList = <AttributesModel>[].obs;

  RxList<ProductSpecificationModel> specificationList = <ProductSpecificationModel>[].obs;
  RxList<ProductSpecificationModel> addonsList = <ProductSpecificationModel>[].obs;

  RxString title = "".obs;

  RxBool isPublish = true.obs;
  RxBool isPureVeg = true.obs;
  RxBool isNonVeg = false.obs;

  RxBool takeAway = false.obs;
  RxBool isDiscountedPriceOk = false.obs;

  RxBool isTitleGenerated = false.obs;
  RxBool generateVariationDataGenerated = false.obs;
  RxBool generateIngredientsGenerated = false.obs;
  RxBool generateSpecificationGenerated = false.obs;
  RxBool generateAddOnsGenerated = false.obs;

  RxString aiPhotoFile = "".obs;
  RxList<TaxModel> taxList = <TaxModel>[].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    priceAndDiscountPriceListen();
    super.onInit();
  }

  void addAttribute(String id) {
    ItemAttribute? itemAttribute = itemAttributes.value;
    List<Attributes>? attributesList = itemAttribute!.attributes;
    attributesList!.add(Attributes(attributeId: id, attributeOptions: []));
    itemAttributes.value = itemAttribute;
    update();
  }

  RxDouble regularPrice = 0.0.obs;
  RxDouble discountPrice = 0.0.obs;

  void priceAndDiscountPriceListen() {
    regularPriceController.value.addListener(() {
      regularPrice.value = double.parse(regularPriceController.value.text.trim().isEmpty ? '0.0' : regularPriceController.value.text.trim());
      if (discountPrice.value != 0.0 && regularPrice.value < discountPrice.value) {
        ShowToastDialog.showToast("Enter a regular price greater than the discount price.".tr);
      }
    });
    discountedPriceController.value.addListener(() {
      discountPrice.value = double.parse(discountedPriceController.value.text.trim().isEmpty ? '0.0' : discountedPriceController.value.text.trim());

      if (regularPrice.value != 0.0 && discountPrice.value > regularPrice.value) {
        isDiscountedPriceOk.value = true;
        ShowToastDialog.showToast("Enter a discount price less than the regular price.".tr);
      } else {
        isDiscountedPriceOk.value = false;
      }
      update();
    });
  }

  @override
  void dispose() {
    regularPriceController.value.dispose();
    discountedPriceController.value.dispose();
    super.dispose();
  }

  Future<void> getArgument() async {
    if (Constant.userModel!.vendorID != null && Constant.userModel!.vendorID!.isNotEmpty) {
      await FireStoreUtils.getVendorById(Constant.userModel!.vendorID.toString()).then((value) {
        if (value != null) {
          vendorModel.value = value;
        }
      });
      taxList.value = Constant.taxProductList ?? [];
      if (taxList.isNotEmpty) {
        for (var tax in taxList) {
          tax.isSelected = false;
        }
      }
    }

    print("======>");
    print(Constant.userModel!.sectionId);
    print(vendorModel.value.categoryID);
    await FireStoreUtils.getVendorCategoryById(Constant.userModel!.sectionId.toString()).then((value) {
      if (vendorModel.value.categoryID!.isNotEmpty) {
        vendorCategoryList.value = value.where((category) => vendorModel.value.categoryID!.contains(category.id)).toList();
      }
    });

    await FireStoreUtils.getAttributes().then((value) {
      if (value != null) {
        attributesList.value = value;
      }
    });

    await FireStoreUtils.getBrands().then((value) {
      brandsList.value = value;
    });

    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      productModel.value = argumentData['productModel'];

      for (var element in productModel.value.photos!) {
        images.add(element);
      }

      isPublish.value = productModel.value.publish ?? false;
      productTitleController.value.text = productModel.value.name.toString();
      productDescriptionController.value.text = productModel.value.description.toString();
      regularPriceController.value.text = productModel.value.price.toString();
      discountedPriceController.value.text = productModel.value.disPrice.toString();
      productQuantityController.value.text = productModel.value.quantity.toString();

      caloriesController.value.text = productModel.value.calories.toString();
      gramsController.value.text = productModel.value.grams.toString();
      fatsController.value.text = productModel.value.fats.toString();
      proteinController.value.text = productModel.value.proteins.toString();
      isPureVeg.value = productModel.value.veg ?? true;
      isNonVeg.value = productModel.value.nonveg ?? false;
      takeAway.value = productModel.value.takeawayOption ?? false;
      if (productModel.value.productSpecification != null) {
        productModel.value.productSpecification!.forEach((key, value) {
          specificationList.add(ProductSpecificationModel(lable: key, value: value));
        });
      }

      itemAttributes.value = productModel.value.itemAttribute ?? ItemAttribute();
      if (productModel.value.isDigitalProduct == true) {
        digitalProductFileName.value = Constant.getFileName(productModel.value.digitalProduct.toString());
        selectedDigital.value = productModel.value.isDigitalProduct == true ? "Yes" : "No";
      }
      if (productModel.value.itemAttribute != null) {
        for (var element in productModel.value.itemAttribute!.attributes!) {
          if (element.attributeId != null && element.attributeId != '') {
            AttributesModel attributesModel = attributesList.firstWhere((product) {
              log("attributesModel :: ${product.id} :: ${element.attributeId}");
              return product.id == element.attributeId;
            });
            selectedAttributesList.add(attributesModel);
          }
        }
      }

      for (var element in productModel.value.addOnsTitle!) {
        addonsList.add(ProductSpecificationModel(lable: element, value: productModel.value.addOnsPrice![productModel.value.addOnsTitle!.indexOf(element)]));
      }

      if (Constant.selectedSection != null && Constant.selectedSection?.serviceTypeFlag == "ecommerce-service") {
        if (productModel.value.brandId != null || productModel.value.brandId?.isEmpty == true) {
          selectedBrands.value = brandsList.firstWhere((p0) => p0.id == productModel.value.brandId);
        }
      }

      for (var element in vendorCategoryList) {
        if (element.id == productModel.value.categoryID) {
          selectedProductCategory.value = element;
        }
      }
    }

    if (productModel.value.taxSetting?.isNotEmpty == true) {
      final selectedTaxIds = productModel.value.taxSetting!.map((e) => e.id).toSet();
      for (var tax in taxList) {
        tax.isSelected = selectedTaxIds.contains(tax.id);
      }
    }

    isLoading.value = false;
  }

  Map<String, dynamic> specification = {};
  File? digitalFile;

  Future<void> saveDetails() async {
    if (selectedProductCategory.value.id == null) {
      ShowToastDialog.showToast("Please Select category".tr);
    } else if (productTitleController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter title".tr);
    } else if (productDescriptionController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter description".tr);
    } else if (regularPriceController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter valid regular price".tr);
    } else if (isDiscountedPriceOk.value == true) {
      ShowToastDialog.showToast("Please enter valid discount price".tr);
    } else if (productQuantityController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter product quantity");
    } else if (double.parse(regularPriceController.value.text.toString()) <= 0) {
      ShowToastDialog.showToast("Please enter valid regular price".tr);
    } else if (Constant.selectedSection!.serviceTypeFlag == "ecommerce-service" && selectedDigital.value == "Yes" && digitalFile == null && digitalProductFileName.isEmpty) {
      ShowToastDialog.showToast("Please upload digital product".tr);
    } else {
      specification.clear();
      for (var element in specificationList) {
        if (element.value!.isNotEmpty && element.lable!.isNotEmpty) {
          specification.addEntries([MapEntry(element.lable.toString(), element.value)]);
        }
      }

      if (selectedDigital.value == "Yes" && digitalFile != null) {
        String fileName = digitalFile!.path.split('/').last;
        Reference upload = FirebaseStorage.instance.ref().child('/digitalProducts/$fileName');
        UploadTask uploadTask = upload.putFile(digitalFile!);
        uploadTask.whenComplete(() {}).catchError((onError) {
          print((onError as PlatformException).message);
          throw onError;
        });
        var storageRef = (await uploadTask.whenComplete(() {})).ref;
        String downloadUrl = await storageRef.getDownloadURL();
        productModel.value.digitalProduct = downloadUrl;
      }

      ShowToastDialog.showLoader("Please wait...".tr);
      for (int i = 0; i < images.length; i++) {
        if (images[i].runtimeType == XFile) {
          String url = await Constant.uploadUserImageToFireStorage(File(images[i].path), "profileImage/${FireStoreUtils.getCurrentUid()}", File(images[i].path).path.split('/').last);
          images.removeAt(i);
          images.insert(i, url);
        }
      }

      List listAddTitle = [];
      List listAddPrice = [];
      for (var element in addonsList) {
        if (element.value!.isNotEmpty && element.lable!.isNotEmpty) {
          listAddTitle.add(element.lable.toString());
          listAddPrice.add(element.value.toString());
        }
      }

      if (productModel.value.id == null) {
        productModel.value.createdAt = Timestamp.now();
        productModel.value.id = Constant.getUuid();
      } else {
        productModel.value.createdAt = productModel.value.createdAt;
        productModel.value.id = productModel.value.id;
      }
      productModel.value.photo = images.isNotEmpty ? images.first : "";
      productModel.value.photos = images;
      productModel.value.price = regularPriceController.value.text.toString();
      productModel.value.disPrice = discountedPriceController.value.text.toString().isEmpty ? "0" : discountedPriceController.value.text.toString();
      productModel.value.quantity = int.parse(productQuantityController.value.text);
      productModel.value.description = productDescriptionController.value.text;
      productModel.value.calories = int.parse(caloriesController.value.text.isEmpty ? "0" : caloriesController.value.text);
      productModel.value.grams = int.parse(gramsController.value.text.isEmpty ? "0" : gramsController.value.text);
      productModel.value.proteins = int.parse(proteinController.value.text.isEmpty ? "0" : proteinController.value.text);
      productModel.value.fats = int.parse(fatsController.value.text.isEmpty ? "0" : fatsController.value.text);
      productModel.value.name = productTitleController.value.text;
      productModel.value.veg = isPureVeg.value;
      productModel.value.nonveg = isNonVeg.value;
      productModel.value.publish = isPublish.value;
      productModel.value.vendorID = Constant.userModel!.vendorID;
      productModel.value.sectionId = vendorModel.value.sectionId;
      productModel.value.categoryID = selectedProductCategory.value.id.toString();
      productModel.value.itemAttribute =
          ((itemAttributes.value!.attributes == null || itemAttributes.value!.attributes!.isEmpty) && (itemAttributes.value!.variants == null || itemAttributes.value!.variants!.isEmpty))
          ? null
          : itemAttributes.value;
      productModel.value.addOnsTitle = listAddTitle;
      productModel.value.addOnsPrice = listAddPrice;
      productModel.value.takeawayOption = takeAway.value;
      productModel.value.productSpecification = specification;
      productModel.value.brandId = selectedBrands.value.id;
      productModel.value.taxSetting = List.from(selectedTaxes);

      await FireStoreUtils.updateProduct(productModel.value);
      ShowToastDialog.closeLoader();
      Get.back(result: true);
    }
  }

  final ImagePicker _imagePicker = ImagePicker();

  Future pickFile({required ImageSource source}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      images.clear();
      images.add(image);
      Get.back();
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("${"Failed to Pick :".tr} \n $e");
    }
  }

  List<dynamic> getCombination(List<List<dynamic>> listArray) {
    if (listArray.length == 1) {
      return listArray[0];
    } else {
      List<dynamic> result = [];
      var allCasesOfRest = getCombination(listArray.sublist(1));
      for (var i = 0; i < allCasesOfRest.length; i++) {
        for (var j = 0; j < listArray[0].length; j++) {
          result.add(listArray[0][j] + "-" + allCasesOfRest[i]);
        }
      }
      return result;
    }
  }

  Future<void> generateTitleAndDescription() async {
    isTitleGenerated.value = true;
    Map<String, dynamic> bodyParams = {'name': productTitleController.value.text};
    log("✅ API :: HEADER :: ${jsonEncode(API.headers)}");
    log("✅ API :: BODY :: ${jsonEncode(bodyParams)}");
    await API
        .handleApiRequest(
          request: () => http.post(Uri.parse(API.generateTitleAndDescription), headers: API.headers, body: jsonEncode(bodyParams)),
          showLoader: false,
        )
        .then((value) {
          isTitleGenerated.value = false;

          if (value != null) {
            if (value['success'] == "Failed") {
              ShowToastDialog.showToast(value['error']);
            } else {
              AITitleDescriptionModel aiTitleDescriptionModel = AITitleDescriptionModel.fromJson(value);
              productTitleController.value.text = aiTitleDescriptionModel.data!.title ?? "";
              productDescriptionController.value.text = aiTitleDescriptionModel.data!.description ?? "";
            }
          }
        });
  }

  Future<void> generateVariationData() async {
    generateVariationDataGenerated.value = true;

    Map<String, dynamic> bodyParams = {
      'name': productTitleController.value.text,
      'description': productDescriptionController.value.text,
      'categories': vendorCategoryList.map((e) => e.toJson()).toList(),
      'item_attribute': attributesList.map((e) => e.toJson()).toList(),
    };
    log("Body Params :: $bodyParams");
    await API
        .handleApiRequest(
          request: () => http.post(Uri.parse(API.generateVariationData), headers: API.headers, body: jsonEncode(bodyParams)),
          showLoader: false,
        )
        .then((value) {
          generateVariationDataGenerated.value = false;

          if (value != null) {
            if (value['status'] == "failed") {
              ShowToastDialog.showToast(value['message']);
            } else {
              selectedAttributesList.clear();
              AIVariationDataModel aiVariationDataModel = AIVariationDataModel.fromJson(value);
              itemAttributes.value = aiVariationDataModel.data!.itemAttribute ?? ItemAttribute();

              if (aiVariationDataModel.data!.itemAttribute != null) {
                for (var element in aiVariationDataModel.data!.itemAttribute!.attributes!) {
                  AttributesModel attributesModel = attributesList.firstWhere((product) => product.id == element.attributeId);
                  selectedAttributesList.add(attributesModel);

                  update();
                }
              }

              for (var element in vendorCategoryList) {
                if (element.id == aiVariationDataModel.data!.categoryId) {
                  selectedProductCategory.value = element;
                }
              }
              update();
            }
          }
        });
  }

  Future<void> generateIngredients() async {
    generateIngredientsGenerated.value = true;

    Map<String, dynamic> bodyParams = {'name': productTitleController.value.text, 'description': productDescriptionController.value.text};
    log("Body Params :: $bodyParams");
    await API
        .handleApiRequest(
          request: () => http.post(Uri.parse(API.generateIngredients), headers: API.headers, body: jsonEncode(bodyParams)),
          showLoader: false,
        )
        .then((value) {
          generateIngredientsGenerated.value = false;

          if (value != null) {
            if (value['status'] == "failed") {
              ShowToastDialog.showToast(value['message']);
            } else {
              caloriesController.value.text = value['data']['calories'].toString();
              gramsController.value.text = value['data']['grams'].toString();
              proteinController.value.text = value['data']['proteins'].toString();
              fatsController.value.text = value['data']['fats'].toString();
            }
          }
        });
  }

  Future<void> generateSpecification() async {
    generateSpecificationGenerated.value = true;

    Map<String, dynamic> bodyParams = {'name': productTitleController.value.text, 'description': productDescriptionController.value.text};
    log("Body Params :: $bodyParams");
    await API
        .handleApiRequest(
          request: () => http.post(Uri.parse(API.generateSpecification), headers: API.headers, body: jsonEncode(bodyParams)),
          showLoader: false,
        )
        .then((value) {
          generateSpecificationGenerated.value = false;

          if (value != null) {
            if (value['status'] == "failed") {
              ShowToastDialog.showToast(value['message']);
            } else {
              value['data']['product_specification'].forEach((key, value) {
                specificationList.add(ProductSpecificationModel(lable: key, value: value));
              });
            }
          }
        });
  }

  Future<void> generateAddOns() async {
    generateAddOnsGenerated.value = true;

    Map<String, dynamic> bodyParams = {'name': productTitleController.value.text, 'description': productDescriptionController.value.text};
    log("Body Params :: $bodyParams");
    await API
        .handleApiRequest(
          request: () => http.post(Uri.parse(API.generateAddons), headers: API.headers, body: jsonEncode(bodyParams)),
          showLoader: false,
        )
        .then((value) {
          generateAddOnsGenerated.value = false;

          if (value != null) {
            if (value['status'] == "failed") {
              ShowToastDialog.showToast(value['message']);
            } else {
              final List<dynamic>? titles = value['data']['addOnsTitle'];
              final List<dynamic>? prices = value['data']['addOnsPrice'];

              if (titles != null && prices != null) {
                for (int i = 0; i < titles.length; i++) {
                  final title = titles[i].toString();
                  final price = i < prices.length ? prices[i].toString() : '0';
                  addonsList.add(ProductSpecificationModel(lable: title, value: price));
                }
              }
            }
          }
        });
  }

  Future<void> generateAllRecordByImage() async {
    isTitleGenerated.value = true;
    generateVariationDataGenerated.value = true;
    generateIngredientsGenerated.value = true;
    generateSpecificationGenerated.value = true;
    generateAddOnsGenerated.value = true;

    List<http.MultipartFile> files = [];

    final imageFile = http.MultipartFile.fromBytes('image', File(aiPhotoFile.value).readAsBytesSync(), filename: File(aiPhotoFile.value).path.split('/').last);
    files.add(imageFile);

    Map<String, String> fields = {'categories': jsonEncode(vendorCategoryList.map((e) => e.toJson()).toList()), 'item_attribute': jsonEncode(attributesList.map((e) => e.toJson()).toList())};
    final response = await API.handleMultipartRequest(url: API.generateImageData, headers: API.headers, fields: fields, files: files, showLoader: false);

    isTitleGenerated.value = false;
    generateVariationDataGenerated.value = false;
    generateIngredientsGenerated.value = false;
    generateSpecificationGenerated.value = false;
    generateAddOnsGenerated.value = false;

    if (response != null && response['status'] == 'success') {
      productTitleController.value.text = response['data']['title'] ?? "";
      productDescriptionController.value.text = response['data']['description'] ?? "";
      caloriesController.value.text = response['data']['ingredients']['calories'].toString();
      gramsController.value.text = response['data']['ingredients']['grams'].toString();
      proteinController.value.text = response['data']['ingredients']['proteins'].toString();
      fatsController.value.text = response['data']['ingredients']['fats'].toString();

      selectedAttributesList.clear();
      AIVariationData aiVariationDataModel = AIVariationData.fromJson(response['data']['variation']);
      itemAttributes.value = aiVariationDataModel.itemAttribute ?? ItemAttribute();

      if (aiVariationDataModel.itemAttribute != null) {
        for (var element in aiVariationDataModel.itemAttribute!.attributes!) {
          AttributesModel attributesModel = attributesList.firstWhere((product) => product.id == element.attributeId);
          selectedAttributesList.add(attributesModel);

          update();
        }
      }

      for (var element in vendorCategoryList) {
        if (element.id == aiVariationDataModel.categoryId) {
          selectedProductCategory.value = element;
        }
      }
      update();

      final List<dynamic>? titles = response['data']['addons']['addOnsTitle'];
      final List<dynamic>? prices = response['data']['addons']['addOnsPrice'];

      if (titles != null && prices != null) {
        for (int i = 0; i < titles.length; i++) {
          final title = titles[i].toString();
          final price = i < prices.length ? prices[i].toString() : '0';
          addonsList.add(ProductSpecificationModel(lable: title, value: price));
        }
      }

      response['data']['specification']['product_specification'].forEach((key, value) {
        specificationList.add(ProductSpecificationModel(lable: key, value: value));
      });
    } else {
      ShowToastDialog.showToast(response['message'] ?? "Something went wrong, please try again.");
      log("Book Parcel Error: ${response.toString()}");
    }
  }

  void toggleSelection(int index, bool value) {
    taxList[index].isSelected = value;
    taxList.refresh();
  }

  List<TaxModel> get selectedTaxes => taxList.where((e) => e.isSelected).toList();
}
