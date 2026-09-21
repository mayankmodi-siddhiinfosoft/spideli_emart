import 'package:cached_network_image/cached_network_image.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/coupon_model.dart';
import 'package:spideliprovider/model/sectionModel.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datetime_picker_formfield_new/datetime_picker_formfield.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/add_or_update_coupon_controller.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class AddOrUpdateCouponScreen extends StatelessWidget {
  const AddOrUpdateCouponScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<AddOrUpdateCouponController>(
        init: AddOrUpdateCouponController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
            appBar: AppBar(
              backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
              title: Text(
                controller.serviceModel.value.id != null ? "Edit Coupon".tr : "Add Coupon".tr,
                style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 18, fontFamily: AppColors.semiBold),
              ),
              leading: InkWell(
                  onTap: () {
                    Get.back();
                  },
                  child: const Icon(
                    Icons.arrow_back,
                  )),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 1,
                  width: MediaQuery.of(context).size.width,
                  color: Colors.black12,
                ),
                Expanded(
                  child: Form(
                    key: controller.formKey.value,
                    autovalidateMode: controller.autoValidateMode,
                    child: Container(
                      height: MediaQuery.of(context).size.height,
                      margin: EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                                padding: const EdgeInsets.only(top: 10, bottom: 5),
                                child: Text(
                                  "Select Section".tr,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                )),
                            DropdownButtonFormField<SectionModel>(
                                isExpanded: true,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                ),
                                validator: (value) => value == null ? 'field required' : null,
                                value: controller.selectedSection.value.id == null ? null : controller.selectedSection.value,
                                onChanged: (value) async {
                                  controller.selectedSection.value = value!;
                                },
                                hint: Text("Select OnDemand section".tr),
                                items: controller.sectionList.map((item) {
                                  return DropdownMenuItem(
                                    value: item,
                                    child: Text(item.name.toString()),
                                  );
                                }).toList()),
                            Container(
                                padding: const EdgeInsets.only(top: 10, bottom: 5),
                                child: Text(
                                  "Coupon Code".tr,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                )),
                            TextFormField(
                                controller: controller.couponCode.value,
                                textAlignVertical: TextAlignVertical.center,
                                textInputAction: TextInputAction.next,
                                validator: validateEmptyField,
                                keyboardType: TextInputType.text,
                                cursorColor: AppColors.colorPrimary,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                  hintText: "Add coupon code".tr,
                                  hintStyle: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 17),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                )),
                            Container(
                                padding: const EdgeInsets.only(top: 10, bottom: 5),
                                child: Text(
                                  "Select Coupon Type".tr,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                )),
                            Row(
                              children: [
                                Expanded(
                                  child: Theme(
                                    data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.grey, disabledColor: Colors.grey),
                                    child: RadioListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          'Fix Price'.tr,
                                          style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 14, fontFamily: AppColors.medium, fontWeight: FontWeight.bold),
                                        ),
                                        value: "Fix Price".tr,
                                        groupValue: controller.couponType.value,
                                        activeColor: AppColors.colorPrimary,
                                        onChanged: (value) {
                                          controller.couponType.value = value!.toString();
                                        }),
                                  ),
                                ),
                                Expanded(
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      unselectedWidgetColor: Colors.grey,
                                      disabledColor: Colors.grey,
                                    ),
                                    child: RadioListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          'Percentage'.tr,
                                          style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 14, fontFamily: AppColors.medium, fontWeight: FontWeight.bold),
                                        ),
                                        value: "Percentage".tr,
                                        activeColor: AppColors.colorPrimary,
                                        groupValue: controller.couponType.value,
                                        onChanged: (value) {
                                          controller.couponType.value = value!.toString();
                                        }),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 15,
                            ),
                            Container(
                                padding: const EdgeInsets.only(top: 10, bottom: 5),
                                child: Text(
                                  controller.couponType.value == "Percentage".tr ? "Coupon Percentage" : "Coupon amount".tr,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                )),
                            TextFormField(
                                controller: controller.addPrice.value,
                                textAlignVertical: TextAlignVertical.center,
                                textInputAction: TextInputAction.next,
                                validator: validateEmptyField,
                                keyboardType: TextInputType.number,
                                cursorColor: AppColors.colorPrimary,
                                decoration: InputDecoration(
                                  suffixIcon: Container(
                                    margin: EdgeInsets.only(top: 11, right: 0),
                                    child: Text(
                                      controller.couponType.value == "Percentage".tr ? "%" : currencyData!.symbol.toString(),
                                      style: TextStyle(color: AppColors.colorPrimary, fontSize: 22, fontFamily: AppColors.medium, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                  hintText: controller.couponType.value == "Percentage".tr ? "Add percentage".tr : "Add price".tr,
                                  hintStyle: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 17),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                )),
                            Container(
                                padding: const EdgeInsets.only(top: 10, bottom: 5),
                                child: Text(
                                  "Expires at".tr,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark),
                                )),
                            DateTimeField(
                              format: controller.format,
                              controller: controller.expiryDate.value,
                              validator: (date) => (controller.expiryDate.value.text == '') ? "This field can't be empty.".tr : null,
                              textInputAction: TextInputAction.done,
                              style: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 17, fontFamily: AppColors.medium, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                  contentPadding: EdgeInsets.fromLTRB(15, 10, 15, 10),
                                  hintText: "Select date".tr,
                                  hintStyle: TextStyle(color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontSize: 17, fontFamily: AppColors.medium, fontWeight: FontWeight.bold),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7.0), borderSide: BorderSide(color: AppColors.colorPrimary, width: 2.0)),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                                    borderRadius: BorderRadius.circular(7.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(7.0),
                                  )),
                              onShowPicker: (context, currentValue) {
                                return showDatePicker(
                                    context: context,
                                    firstDate: DateTime.now(),
                                    initialDate: controller.serviceModel.value.id == null ? DateTime.now() : controller.serviceModel.value.expiresAt!.toDate(),
                                    lastDate: DateTime(2100));
                              },
                            ),
                            SizedBox(
                              height: 30,
                            ),
                            controller.mediaFiles.isEmpty == true
                                ? InkWell(
                                    onTap: () {
                                      _pickImage(controller, context);
                                    },
                                    child: controller.serviceModel.value.id == null
                                        ? Image(
                                            image: AssetImage("assets/images/add_offer_img.png"),
                                            width: MediaQuery.of(context).size.width * 1,
                                            height: MediaQuery.of(context).size.height * 0.12,
                                          )
                                        : controller.serviceModel.value.image == ""
                                            ? Image(
                                                image: AssetImage("assets/images/add_offer_img.png"),
                                                width: MediaQuery.of(context).size.width * 1,
                                                height: MediaQuery.of(context).size.height * 0.12,
                                              )
                                            : ClipRRect(
                                                borderRadius: new BorderRadius.circular(15.0),
                                                child: CachedNetworkImage(
                                                  imageUrl: controller.downloadUrl.value,
                                                  height: 135,
                                                  width: 135,
                                                )))
                                : _imageBuilder(controller.mediaFiles.first, context),
                            SizedBox(
                              height: 15,
                            ),
                            Container(
                              decoration: new BoxDecoration(borderRadius: new BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade400)),
                              padding: EdgeInsets.zero,
                              child: SwitchListTile.adaptive(
                                  activeColor: AppColors.colorPrimary,
                                  title: Text('Activate'.tr,
                                      style: TextStyle(fontSize: 15, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontWeight: FontWeight.bold, fontFamily: AppColors.medium)),
                                  value: controller.isOfferEnable.value,
                                  onChanged: (bool newValue) async {
                                    controller.isOfferEnable.value = newValue;
                                  }),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Container(
                              decoration: new BoxDecoration(borderRadius: new BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade400)),
                              padding: EdgeInsets.zero,
                              child: SwitchListTile.adaptive(
                                  activeColor: AppColors.colorPrimary,
                                  title: Text('Public'.tr,
                                      style: TextStyle(fontSize: 15, color: themeChange.getTheme() ? Colors.white : AppColors.colorDark, fontWeight: FontWeight.bold, fontFamily: AppColors.medium)),
                                  value: controller.isPublic.value,
                                  onChanged: (bool newValue) async {
                                    controller.isPublic.value = newValue;
                                  }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (controller.formKey.value.currentState?.validate() == false) {
                    } else {
                      ShowToastDialog.showLoader(controller.serviceModel.value.id == null ? 'Adding Offer...'.tr : "Editing Offer...".tr);
                      if (controller.mediaFiles.length > 0) {
                        var uniqueID = Uuid().v4();
                        Reference upload = FirebaseStorage.instance.ref().child(STORAGE_ROOT +
                            'provider/couponImages/$uniqueID'
                                '.png');

                        UploadTask uploadTask = upload.putFile(controller.mediaFiles.first);
                        // ignore: body_might_complete_normally_catch_error
                        uploadTask.whenComplete(() {}).catchError((onError) {
                          print((onError as PlatformException).message);
                        });
                        var storageRef = (await uploadTask.whenComplete(() {})).ref;
                        controller.downloadUrl.value = await storageRef.getDownloadURL();
                        controller.downloadUrl.value.toString();
                      }

                      Timestamp myTimeStamp = Timestamp.fromDate(DateTime.parse(controller.expiryDate.value.text.toString().trim()).toUtc());

                      CouponModel? mOfferModel = controller.serviceModel.value;

                      mOfferModel.code = controller.couponCode.value.text.toString().trim();
                      mOfferModel.discount = controller.addPrice.value.text.toString().trim();
                      mOfferModel.discountType = controller.couponType.value;
                      mOfferModel.image = controller.downloadUrl.toString();
                      mOfferModel.expiresAt = myTimeStamp;
                      mOfferModel.isEnabled = controller.isOfferEnable.value;
                      mOfferModel.isPublic = controller.isPublic.value;
                      mOfferModel.providerId = MyAppState.currentUser!.id;
                      mOfferModel.sectionId = controller.selectedSection.value.id;

                      FireStoreUtils.firebaseAddOrUpdateCoupon(mOfferModel);

                      ShowToastDialog.closeLoader();
                      Get.back(result: true);
                    }
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    margin: EdgeInsets.fromLTRB(25, 0, 25, 20),
                    padding: EdgeInsets.fromLTRB(15, 12, 15, 12),
                    decoration: new BoxDecoration(
                      color: AppColors.colorPrimary,
                      borderRadius: new BorderRadius.circular(7),
                    ),
                    child: Text(
                      controller.serviceModel.value.id == null ? "Create Coupon".tr : "Edit Coupon".tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 17, fontFamily: AppColors.medium, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          );
        });
  }

  _pickImage(AddOrUpdateCouponController controller, BuildContext context) {
    final action = CupertinoActionSheet(
      message: Text(
        'Add Picture'.tr,
        style: TextStyle(fontSize: 15.0),
      ),
      actions: <Widget>[
        CupertinoActionSheetAction(
          child: Text('Choose image from gallery'.tr),
          isDefaultAction: false,
          onPressed: () async {
            Get.back();
            XFile? image = await controller.imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              controller.mediaFiles.add(File(image.path));
            }
          },
        ),
        CupertinoActionSheetAction(
          child: Text('Take a picture'.tr),
          isDestructiveAction: false,
          onPressed: () async {
            Get.back();
            XFile? image = await controller.imagePicker.pickImage(source: ImageSource.camera);
            if (image != null) {
              controller.mediaFiles.add(File(image.path));
              controller.update();
            }
          },
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr),
        onPressed: () {
          Get.back();
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  _imageBuilder(dynamic image, context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    // bool isLastItem = image == null;
    return GestureDetector(
      onTap: () {
        // _viewOrDeleteImage(image);
      },
      child: Container(
        width: 100,
        child: Card(
          shape: RoundedRectangleBorder(
            side: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
          color: themeChange.getTheme() ? Colors.black : Colors.white,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image is File
                ? Image.file(
                    image,
                    fit: BoxFit.cover,
                  )
                : displayImage(image),
          ),
        ),
      ),
    );
  }
}
