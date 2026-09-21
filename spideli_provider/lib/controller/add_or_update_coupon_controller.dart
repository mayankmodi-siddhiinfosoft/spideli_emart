import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/model/coupon_model.dart';
import 'package:spideliprovider/model/sectionModel.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddOrUpdateCouponController extends GetxController {
  Rx<TextEditingController> couponCode = TextEditingController().obs;
  Rx<TextEditingController> addPrice = TextEditingController().obs;
  Rx<TextEditingController> expiryDate = TextEditingController().obs;

  RxList<dynamic> mediaFiles = <dynamic>[].obs;
  RxBool isOfferEnable = false.obs;
  RxBool isPublic = false.obs;
  RxString downloadUrl = "".obs;
  RxString couponType = "Fix Price".obs;
  final format = DateFormat("yyyy-MM-dd");

  final ImagePicker imagePicker = ImagePicker();
  Rx<GlobalKey<FormState>> formKey = GlobalKey<FormState>().obs;
  AutovalidateMode autoValidateMode = AutovalidateMode.disabled;

  Rx<CouponModel> serviceModel = CouponModel().obs;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  RxList<SectionModel> sectionList = <SectionModel>[].obs;
  Rx<SectionModel> selectedSection = SectionModel().obs;

  getData() async {
    sectionList.clear();
    await FireStoreUtils.firestore.collection(sections).where("serviceTypeFlag", isEqualTo: "ondemand-service").where("isActive", isEqualTo: true).get().then((value) {
      value.docs.forEach((element) {
        SectionModel sectionModel = SectionModel.fromJson(element.data());
        sectionList.add(sectionModel);
      });
    });
    getArgument();
    update();
  }

  getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      serviceModel.value = argumentData['couponModel'];

      couponCode.value.text = serviceModel.value.code!;
      addPrice.value.text = serviceModel.value.discount!;
      expiryDate.value.text = dateFormatYYYYMMDD(serviceModel.value.expiresAt!.toDate().toString())!;
      couponType.value = serviceModel.value.discountType!;
      downloadUrl.value = serviceModel.value.image!;
      isOfferEnable.value = serviceModel.value.isEnabled!;
      isPublic.value = serviceModel.value.isPublic!;

      sectionList.forEach((element) async {
        if (element.id == serviceModel.value.sectionId) {
          selectedSection.value = element;
        }
      });
    }

    update();
  }
}
