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
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Add / edit coupon (archetype F): artwork first, then the coupon details,
/// discount type as a segmented switcher, validity and the two visibility
/// toggles, with the submit action in a sticky bar. Values, validators and
/// the Firestore write are untouched.
class AddOrUpdateCouponScreen extends StatelessWidget {
  const AddOrUpdateCouponScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX<AddOrUpdateCouponController>(
        init: AddOrUpdateCouponController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          final bool isPercent = controller.couponType.value == "Percentage".tr;
          final bool isEdit = controller.serviceModel.value.id != null;
          return DsScaffold(
            title: isEdit ? "Edit Coupon".tr : "Add Coupon".tr,
            onBack: () {
              Get.back();
            },
            maxContentWidth: DsLayout.contentMax,
            body: Form(
              key: controller.formKey.value,
              autovalidateMode: controller.autoValidateMode,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: DsFadeSlideIn.stagger([
                    // ── Artwork ───────────────────────────────────────────
                    DsFormSection(
                      title: 'Add Picture'.tr,
                      icon: Icons.image_outlined,
                      children: [
                        Center(
                          child: controller.mediaFiles.isEmpty == true
                              ? InkWell(
                                  borderRadius: DsRadius.brLg,
                                  onTap: () {
                                    _pickImage(controller, context);
                                  },
                                  child: controller.serviceModel.value.id == null
                                      ? const _CouponArtworkPlaceholder()
                                      : controller.serviceModel.value.image == ""
                                          ? const _CouponArtworkPlaceholder()
                                          : ClipRRect(
                                              borderRadius: DsRadius.brLg,
                                              child: CachedNetworkImage(
                                                imageUrl: controller.downloadUrl.value,
                                                height: 135,
                                                width: 135,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(width: 135, height: 135, color: c.shimmerBase),
                                                errorWidget: (context, url, error) => const _CouponArtworkPlaceholder(),
                                              ),
                                            ))
                              : _imageBuilder(controller.mediaFiles.first, context),
                        ),
                        const DsGap(DsSpace.lg),
                      ],
                    ),
                    // ── Coupon details ────────────────────────────────────
                    DsFormSection(
                      title: "Coupon Code".tr,
                      icon: Icons.confirmation_number_outlined,
                      children: [
                        DsDropdown<SectionModel>(
                          label: "Select Section".tr,
                          hint: "Select OnDemand section".tr,
                          prefixIcon: Icons.dashboard_customize_outlined,
                          validator: (value) => value == null ? 'field required' : null,
                          value: controller.selectedSection.value.id == null ? null : controller.selectedSection.value,
                          onChanged: (value) async {
                            controller.selectedSection.value = value!;
                          },
                          items: controller.sectionList.map((item) {
                            return DropdownMenuItem(
                              value: item,
                              child: Text(item.name.toString()),
                            );
                          }).toList(),
                        ),
                        DsTextField(
                          label: "Coupon Code".tr,
                          hint: "Add coupon code".tr,
                          controller: controller.couponCode.value,
                          validator: validateEmptyField,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.qr_code_rounded,
                          bottomSpacing: DsSpace.sm,
                        ),
                      ],
                    ),
                    // ── Discount ──────────────────────────────────────────
                    DsFormSection(
                      title: "Select Coupon Type".tr,
                      icon: Icons.discount_outlined,
                      children: [
                        DsSegmentedTabs(
                          segments: [
                            DsSegment('Fix Price'.tr, icon: Icons.payments_outlined),
                            DsSegment('Percentage'.tr, icon: Icons.percent_rounded),
                          ],
                          // Exact match, like the old radios: an unknown stored
                          // value selects neither segment.
                          index: controller.couponType.value == "Fix Price".tr
                              ? 0
                              : controller.couponType.value == "Percentage".tr
                                  ? 1
                                  : -1,
                          onChanged: (i) {
                            if (i == 0) {
                              controller.couponType.value = "Fix Price".tr;
                            } else {
                              controller.couponType.value = "Percentage".tr;
                            }
                          },
                        ),
                        const DsGap(DsSpace.lg),
                        DsFieldLabel(isPercent ? "Coupon Percentage" : "Coupon amount".tr, required: true),
                        TextFormField(
                          controller: controller.addPrice.value,
                          textAlignVertical: TextAlignVertical.center,
                          textInputAction: TextInputAction.next,
                          validator: validateEmptyField,
                          keyboardType: TextInputType.number,
                          cursorColor: c.brand,
                          style: t.bodyStrong.tabular,
                          decoration: DsInputDecoration.of(
                            context,
                            hint: isPercent ? "Add percentage".tr : "Add price".tr,
                            prefixIcon: isPercent ? Icons.percent_rounded : Icons.payments_outlined,
                            suffix: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                              child: Text(
                                isPercent ? "%" : currencyData!.symbol.toString(),
                                style: t.titleSm.withColor(c.brandStrong),
                              ),
                            ),
                          ),
                        ),
                        const DsGap(DsSpace.sm),
                      ],
                    ),
                    // ── Validity ──────────────────────────────────────────
                    DsFormSection(
                      title: "Expires at".tr,
                      icon: Icons.event_available_outlined,
                      children: [
                        DateTimeField(
                          format: controller.format,
                          controller: controller.expiryDate.value,
                          validator: (date) => (controller.expiryDate.value.text == '') ? "This field can't be empty.".tr : null,
                          textInputAction: TextInputAction.done,
                          style: t.bodyStrong,
                          decoration: DsInputDecoration.of(
                            context,
                            hint: "Select date".tr,
                            prefixIcon: Icons.calendar_month_outlined,
                            suffix: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                          ),
                          onShowPicker: (context, currentValue) {
                            return showDatePicker(
                                context: context,
                                firstDate: DateTime.now(),
                                initialDate: controller.serviceModel.value.id == null ? DateTime.now() : controller.serviceModel.value.expiresAt!.toDate(),
                                lastDate: DateTime(2100));
                          },
                        ),
                        const DsGap(DsSpace.sm),
                      ],
                    ),
                    // ── Visibility ────────────────────────────────────────
                    DsFormSection(
                      title: 'Visibility'.tr,
                      icon: Icons.toggle_on_outlined,
                      children: [
                        _ToggleRow(
                          title: 'Activate'.tr,
                          subtitle: controller.isOfferEnable.value ? 'This coupon can be redeemed.'.tr : 'This coupon is switched off.'.tr,
                          icon: controller.isOfferEnable.value ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                          tone: controller.isOfferEnable.value ? DsTone.success : DsTone.neutral,
                          value: controller.isOfferEnable.value,
                          onChanged: (bool newValue) async {
                            controller.isOfferEnable.value = newValue;
                          },
                        ),
                        const DsGap(DsSpace.md),
                        _ToggleRow(
                          title: 'Public'.tr,
                          subtitle: controller.isPublic.value ? 'Visible to every customer.'.tr : 'Only customers with the code can use it.'.tr,
                          icon: controller.isPublic.value ? Icons.public_rounded : Icons.lock_outline_rounded,
                          tone: controller.isPublic.value ? DsTone.info : DsTone.neutral,
                          value: controller.isPublic.value,
                          onChanged: (bool newValue) async {
                            controller.isPublic.value = newValue;
                          },
                        ),
                        const DsGap(DsSpace.sm),
                      ],
                    ),
                  ]),
                ),
              ),
            ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: controller.serviceModel.value.id == null ? "Create Coupon".tr : "Edit Coupon".tr,
                icon: Icons.check_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () async {
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
              ),
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

  Widget _imageBuilder(dynamic image, BuildContext context) {
    final c = DsColors.of(context);
    // bool isLastItem = image == null;
    return GestureDetector(
      onTap: () {
        // _viewOrDeleteImage(image);
      },
      child: SizedBox(
        width: 135,
        height: 135,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: DsRadius.brLg,
            border: Border.all(color: c.border),
          ),
          child: ClipRRect(
            borderRadius: DsRadius.brLg,
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

/// Empty artwork drop zone – keeps the app's offer illustration.
class _CouponArtworkPlaceholder extends StatelessWidget {
  const _CouponArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      padding: const EdgeInsets.all(DsSpace.lg),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: DsRadius.brLg,
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image(
            image: const AssetImage("assets/images/add_offer_img.png"),
            width: MediaQuery.of(context).size.width * 1,
            height: MediaQuery.of(context).size.height * 0.12,
            fit: BoxFit.contain,
          ),
          const DsGap(DsSpace.sm),
          Text('Add Picture'.tr, style: t.label.withColor(c.brandStrong)),
        ],
      ),
    );
  }
}

/// Icon + title + description + switch row used by the visibility section.
class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final DsTone tone;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.title, required this.subtitle, required this.icon, required this.tone, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Row(
      children: [
        DsIconWell(icon: icon, tone: tone, size: 40),
        const DsGap(DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: t.titleSm),
              const DsGap(DsSpace.xxs),
              Text(subtitle, style: t.bodySm),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}
