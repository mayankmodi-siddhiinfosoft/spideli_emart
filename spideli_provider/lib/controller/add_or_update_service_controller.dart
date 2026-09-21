import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/category_model.dart';
import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/model/sectionModel.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

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
  RxBool publish = false.obs;
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

  getAttribute() async {
    serviceName.value.text = serviceModel.value.title.toString();
    rprice.value.text = serviceModel.value.price.toString();
    description.value.text = serviceModel.value.description.toString();
    disprice.value.text = serviceModel.value.disPrice.toString();
    publish.value = serviceModel.value.publish!;
    isDiscountedPriceOk.value = false;
    startTime!.value = serviceModel.value.startTime.toString();
    endTime!.value = serviceModel.value.endTime.toString();
    address.value.text = serviceModel.value.address.toString();
    priceUnit!.value = serviceModel.value.priceUnit.toString();
    latValue.value = serviceModel.value.latitude!;
    longValue.value = serviceModel.value.longitude!;
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
