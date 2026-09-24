import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/add_or_update_service_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/category_model.dart';
import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/model/sectionModel.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/subscription_plan_screen/subscription_plan_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/utils/utils.dart';
import 'package:spideliprovider/widgets/geoflutterfire/src/geoflutterfire.dart';
import 'package:spideliprovider/widgets/geoflutterfire/src/models/point.dart';
import 'package:spideliprovider/widgets/osm_map/map_picker_page.dart';
import 'package:spideliprovider/widgets/place_picker/location_picker_screen.dart';
import 'package:spideliprovider/widgets/place_picker/selected_location_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_helper.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Add / edit service (archetype F): a long form broken into titled DS
/// sections – details, location, availability, pricing, visibility and media –
/// with the submit action pinned in a sticky bar. Every controller, validator
/// and picker handler is unchanged.
class AddOrUpdateServiceScreen extends StatelessWidget {
  const AddOrUpdateServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX<AddOrUpdateServiceController>(
        init: AddOrUpdateServiceController(),
        builder: (controller) {
          final bool isEdit = controller.serviceModel.value.title.toString() != '';
          return DsScaffold(
            title: isEdit ? "Edit Service".tr : "Add Service".tr,
            onBack: () {
              Get.back();
            },
            maxContentWidth: DsLayout.contentMax,
            body: DsAsync(
              isLoading: controller.isLoading.value,
              skeleton: const DsSkeletonForm(fields: 6),
              builder: (_) => _ServiceForm(controller: controller),
            ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: 'Save'.tr,
                icon: Icons.check_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () {
                  _validate(controller, context);
                },
              ),
            ),
          );
        });
  }

  _validate(AddOrUpdateServiceController controller, BuildContext context) async {
    if (controller.selectedSection.value.id == null) {
      ShowToastDialog.showToast('Please Select OnDemand section.'.tr);
    } else if (controller.selectedCategory.value.id == null) {
      ShowToastDialog.showToast('Please Select Category.'.tr);
    } else if (controller.selectedSubCategory.value.id == null) {
      ShowToastDialog.showToast('Please Select Sub Category.'.tr);
    } else if (controller.startTime!.value.isEmpty || controller.endTime!.value.isEmpty) {
      ShowToastDialog.showToast('Please Select start and end time.'.tr);
    } else if (controller.selectedDays!.isEmpty) {
      ShowToastDialog.showToast('Please Select Days.'.tr);
    } else {
      if (controller.formKey.value.currentState?.validate() ?? false) {
        if (controller.mediaFiles.isEmpty) {
          showimgAlertDialog(context, 'Please add Image'.tr, 'Add Image to continue'.tr, true);
        } else {
          controller.formKey.value.currentState!.save();
          ShowToastDialog.showLoader('Adding service...'.tr);

          ProviderServiceModel? providerModel = controller.serviceModel.value;

          List<String> mediaFilesURLs = controller.mediaFiles.whereType<String>().toList().cast<String>();
          List<File> imagesToUpload = controller.mediaFiles.whereType<File>().toList().cast<File>();
          if (imagesToUpload.isNotEmpty) {
            for (int i = 0; i < imagesToUpload.length; i++) {
              String url = await FireStoreUtils.uploadServiceImage(
                imagesToUpload[i],
                'Uploading Product Images {} of {}'.tr,
              );
              mediaFilesURLs.add(url);
            }
          }

          if ((providerModel.id!).isEmpty) {
            providerModel.subscriptionTotalOrders = MyAppState.currentUser!.subscriptionTotalOrders;
            providerModel.subscriptionPlanId = MyAppState.currentUser!.subscriptionPlanId;
            providerModel.subscriptionPlan = MyAppState.currentUser!.subscriptionPlan;
            providerModel.subscriptionPlan?.createdAt = MyAppState.currentUser!.subscriptionPlan!.createdAt;
            providerModel.subscriptionExpiryDate = MyAppState.currentUser!.subscriptionExpiryDate;
          }

          GeoFirePoint myLocation = Geoflutterfire().point(latitude: controller.latValue.value, longitude: controller.longValue.value);

          providerModel.phoneNumber = MyAppState.currentUser!.phoneNumber;
          providerModel.author = MyAppState.currentUser!.id;
          providerModel.sectionId = controller.selectedSection.value.id;
          providerModel.authorName = MyAppState.currentUser!.firstName + " " + MyAppState.currentUser!.lastName;
          providerModel.authorProfilePic = MyAppState.currentUser!.photos.isEmpty ? '' : MyAppState.currentUser!.photos.first;
          if (providerModel.id?.isEmpty == true) {
            providerModel.createdAt = Timestamp.now();
          }
          providerModel.geoFireData = GeoFireData(geohash: myLocation.hash, geoPoint: GeoPoint(controller.latValue.value, controller.longValue.value));
          providerModel.description = controller.description.value.text.toString();
          providerModel.latitude = controller.latValue.value;
          providerModel.longitude = controller.longValue.value;
          providerModel.address = controller.address.value.text;
          providerModel.title = controller.serviceName.value.text.toString();
          providerModel.categoryId = controller.selectedCategory.value.id.toString();
          providerModel.subCategoryId = controller.selectedSubCategory.value.id.toString();
          providerModel.price = controller.rprice.value.text.toString();
          providerModel.disPrice = controller.disprice.value.text.toString().isEmpty ? "0" : controller.disprice.value.text.toString();
          providerModel.publish = controller.publish.value;
          providerModel.photos = mediaFilesURLs;
          providerModel.startTime = controller.startTime.toString();
          providerModel.endTime = controller.endTime.toString();
          providerModel.priceUnit = controller.priceUnit.toString();
          providerModel.days = controller.selectedDays!.toList();

          await FireStoreUtils.getCurrentUser(MyAppState.currentUser!.id).then((userdata) {
            MyAppState.currentUser = userdata;
            MyAppState.currentUser?.sectionId = controller.selectedSection.value.id!;
          });
          if (MyAppState.currentUser?.adminCommission == null) {
            MyAppState.currentUser?.adminCommission = controller.selectedSection.value.adminCommision;
          }
          await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
          await FireStoreUtils.firebaseAddOrUpdateProvider(providerModel);
          await ShowToastDialog.closeLoader();
          ShowToastDialog.showToast(controller.serviceModel.value.title.toString() != '' ? "Service successfully updated" : "Service successfully added");
          if ((MyAppState.currentUser?.adminCommission?.enable == true || isSubscriptionModelApplied == true) &&
              (MyAppState.currentUser?.subscriptionPlanId == null || MyAppState.currentUser?.subscriptionPlanId == '')) {
            Get.offAll(const SubscriptionPlanScreen(), arguments: {"isShowAppBar": false, "isDropdownDisable": true});
          } else {
            Future.delayed(Duration(seconds: 2), () {
              Get.back(result: true);
              Get.back(result: true);
            });
          }
        }
      } else {
        controller.validate = AutovalidateMode.onUserInteraction;
      }
    }
  }

  showAlertDialogNew(BuildContext context) {
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DsDialog(
          title: "Adding Service".tr,
          message: "Data is saved to database.".tr,
          icon: Icons.cloud_done_outlined,
          tone: DsTone.success,
          primaryLabel: "OK".tr,
          onPrimary: () async {
            Get.back(result: true);
            Get.back(result: true);
          },
        );
      },
    );
  }
}

/// The scrollable form body, in DS sections.
class _ServiceForm extends StatelessWidget {
  final AddOrUpdateServiceController controller;

  const _ServiceForm({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    // This widget's build runs after the enclosing GetX/DsAsync builder has
    // finished tracking, so its own observable reads need their own observer.
    return DsObserve(
      builder: (context) => Form(
        key: controller.formKey.value,
        autovalidateMode: controller.validate,
        child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: DsFadeSlideIn.stagger([
            // ── Service details ───────────────────────────────────────────
            DsFormSection(
              title: "Service details".tr,
              icon: Icons.handyman_outlined,
              children: [
                DsTextField(
                  label: "Service Name".tr,
                  hint: "Service Name".tr,
                  controller: controller.serviceName.value,
                  validator: validateEmptyField,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.design_services_outlined,
                ),
                // Section: a dropdown while the plan allows it, otherwise the
                // locked read-only field with the same toast.
                ((controller.serviceModel.value.subscriptionPlan == null) || (isSubscriptionModelApplied == false && controller.selectedSection.value.adminCommision?.enable == false))
                    ? DsDropdown<SectionModel>(
                        label: "Select Section".tr,
                        hint: "Select OnDemand section".tr,
                        prefixIcon: Icons.dashboard_customize_outlined,
                        validator: (value) => value == null ? 'field required' : null,
                        value: controller.selectedSection.value.id == null ? null : controller.selectedSection.value,
                        onChanged: (value) async {
                          controller.selectedSection.value = value!;

                          await FireStoreUtils.getCategory(controller.selectedSection.value.id.toString()).then((value) {
                            controller.categoryVal.value = value;
                          });

                          if (controller.categoryVal.isNotEmpty) {
                            controller.selectedCategory.value = controller.categoryVal.first;
                            await FireStoreUtils.getSubCategory(controller.selectedCategory.value.id!).then((value) {
                              controller.subCategoryList.value = value;
                            });
                            if (controller.subCategoryList.isNotEmpty) {
                              controller.selectedSubCategory.value = controller.subCategoryList.first;
                            }
                          } else {
                            Get.showSnackbar(
                              GetSnackBar(
                                message: 'No category for this section'.tr,
                                duration: 5.seconds,
                              ),
                            );
                          }
                        },
                        items: controller.sectionList.map((item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Text(item.name.toString()),
                          );
                        }).toList(),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DsFieldLabel("Select Section".tr),
                            InkWell(
                              onTap: () {
                                ShowToastDialog.showToast("You are not able to change section. because of your plan is purchased on ${selectedSectionModel!.name} section");
                              },
                              child: TextFormField(
                                initialValue: controller.selectedSection.value.name.toString() + " (${controller.selectedSection.value.serviceType})",
                                textAlignVertical: TextAlignVertical.center,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.streetAddress,
                                enabled: false,
                                cursorColor: c.brand,
                                style: t.bodyStrong.withColor(c.textSecondary),
                                decoration: DsInputDecoration.of(
                                  context,
                                  hint: 'Section'.tr,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  enabled: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                DsDropdown<CategoryModel>(
                  label: "Select Category".tr,
                  hint: 'Select Category'.tr,
                  prefixIcon: Icons.category_outlined,
                  validator: (value) => value == null ? 'field required'.tr : null,
                  value: controller.selectedCategory.value.id == null ? null : controller.selectedCategory.value,
                  onChanged: (value) async {
                    controller.selectedCategory.value = value!;
                    print(controller.selectedCategory.value.title);
                    await FireStoreUtils.getSubCategory(controller.selectedCategory.value.id.toString()).then((value) {
                      controller.subCategoryList.value = value;
                    });
                    if (controller.subCategoryList.isNotEmpty) {
                      controller.selectedSubCategory.value = controller.subCategoryList.first;
                    } else {
                      Get.showSnackbar(
                        GetSnackBar(
                          message: 'No Sub category for this category'.tr,
                          duration: 5.seconds,
                        ),
                      );
                    }
                  },
                  items: controller.categoryVal.map((CategoryModel item) {
                    return DropdownMenuItem<CategoryModel>(
                      value: item,
                      child: Text(item.title.toString()),
                    );
                  }).toList(),
                ),
                DsDropdown<CategoryModel>(
                  label: "Select Sub Category".tr,
                  hint: 'Select Sub Category'.tr,
                  prefixIcon: Icons.account_tree_outlined,
                  value: controller.selectedSubCategory.value,
                  validator: (value) => value == null ? 'field required'.tr : null,
                  onChanged: (value) {
                    controller.selectedSubCategory.value = value!;
                    controller.update();
                  },
                  items: controller.subCategoryList.map((CategoryModel item) {
                    return DropdownMenuItem<CategoryModel>(
                      value: item,
                      child: Text(item.title.toString()),
                    );
                  }).toList(),
                ),
                DsTextField(
                  label: "Description".tr,
                  hint: 'Description'.tr,
                  controller: controller.description.value,
                  validator: validateEmptyField,
                  keyboardType: TextInputType.streetAddress,
                  textInputAction: TextInputAction.next,
                  minLines: 3,
                  maxLines: 4,
                  bottomSpacing: DsSpace.sm,
                ),
              ],
            ),
            // ── Location ──────────────────────────────────────────────────
            DsFormSection(
              title: "Address".tr,
              icon: Icons.location_on_outlined,
              trailing: DsButton.ghost(
                label: "Change".tr,
                icon: Icons.my_location_rounded,
                size: DsButtonSize.sm,
                onPressed: () async {
                  checkPermission(() async {
                    ShowToastDialog.showLoader("Please wait");
                    try {
                      await Geolocator.requestPermission();
                      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                      ShowToastDialog.closeLoader();
                      if (selectedMapType == 'osm') {
                        final result = await Get.to(() => MapPickerPage());
                        final firstPlace = result;
                        if (result != null) {
                          controller.latValue.value = firstPlace.coordinates.latitude;
                          controller.longValue.value = firstPlace.coordinates.longitude;

                          controller.address.value.text = firstPlace.address;
                        }
                      } else {
                        Get.to(LocationPickerScreen())!.then((value) async {
                          if (value != null) {
                            SelectedLocationModel selectedLocationModel = value;
                            controller.latValue.value = selectedLocationModel.latLng!.latitude;
                            controller.longValue.value = selectedLocationModel.latLng!.longitude;

                            controller.address.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                            controller.update();
                          }
                        });
                      }
                    } catch (e) {
                      print(e.toString());
                    }
                  }, context);
                },
              ),
              children: [
                DsTextField(
                  hint: 'Address'.tr,
                  controller: controller.address.value,
                  readOnly: true,
                  validator: validateEmptyField,
                  keyboardType: TextInputType.streetAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.place_outlined,
                  bottomSpacing: DsSpace.sm,
                  onTap: () {
                    checkPermission(() async {
                      try {
                        await Geolocator.requestPermission();
                        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

                        if (selectedMapType == 'osm') {
                          final result = await Get.to(() => MapPickerPage());
                          final firstPlace = result;
                          if (result != null) {
                            controller.latValue.value = firstPlace.coordinates.latitude;
                            controller.longValue.value = firstPlace.coordinates.longitude;

                            controller.address.value.text = firstPlace.address;
                          }
                        } else {
                          Get.to(LocationPickerScreen())!.then((value) async {
                            if (value != null) {
                              SelectedLocationModel selectedLocationModel = value;
                              controller.latValue.value = selectedLocationModel.latLng!.latitude;
                              controller.longValue.value = selectedLocationModel.latLng!.longitude;

                              controller.address.value.text = Utils.formatAddress(selectedLocation: selectedLocationModel);
                              controller.update();
                            }
                          });
                        }
                      } catch (e) {
                        await Geocoding().placemarkFromCoordinates(19.228825, 72.854118).then((valuePlaceMaker) async {
                          List<Placemark> placeMarks = await Geocoding().placemarkFromCoordinates(19.228825, 72.854118);

                          controller.address.value.text =
                              "${placeMarks.first.name.toString()},${placeMarks.first.subLocality.toString()},${placeMarks.first.locality.toString()},${placeMarks.first.administrativeArea.toString()},${placeMarks.first.country.toString()}";
                        });
                        controller.update();
                      }
                    }, context);
                  },
                ),
              ],
            ),
            // ── Availability ──────────────────────────────────────────────
            DsFormSection(
              title: 'Availability'.tr,
              icon: Icons.schedule_outlined,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PickerField(
                        label: 'Start Time'.tr,
                        value: controller.startTime!.isEmpty ? null : controller.startTime!.value,
                        hint: 'HH:mm'.tr,
                        icon: Icons.play_circle_outline_rounded,
                        onTap: () async {
                          initializeDateFormatting();
                          TimeOfDay? from = await _selectTime(context);
                          print('=====${controller.endTime!}');
                          print('=====${controller.endTime!}');
                          if (controller.endTime!.isNotEmpty) {
                            if (DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                              from!.hour,
                              from.minute,
                            ).isAfter(DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                              int.parse(controller.endTime!.toString().split(":").first.toString()),
                              int.parse(controller.endTime!.toString().split(":").last.toString()),
                            ))) {
                              controller.startTime!.value = "";
                              ShowToastDialog.showToast("Please enter valid time");
                            } else {
                              controller.startTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, from.hour, from.minute));
                            }
                          } else {
                            controller.startTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, from!.hour, from.minute));
                          }

                          controller.update();
                        },
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: _PickerField(
                        label: 'End Time'.tr,
                        value: controller.endTime!.isEmpty ? null : controller.endTime!.value,
                        hint: 'HH:mm'.tr,
                        icon: Icons.stop_circle_outlined,
                        onTap: () async {
                          TimeOfDay? to = await _selectTime(context);
                          if (controller.startTime!.isNotEmpty) {
                            if (DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                              to!.hour,
                              to.minute,
                            ).isBefore(DateTime(
                              DateTime.now().year,
                              DateTime.now().month,
                              DateTime.now().day,
                              int.parse(controller.startTime!.toString().split(":").first.toString()),
                              int.parse(controller.startTime!.toString().split(":").last.toString()),
                            ))) {
                              controller.endTime!.value = "";
                              ShowToastDialog.showToast("Please enter valid time");
                            } else {
                              if (to.format(context).toString() == "12:00 AM") {
                                controller.endTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59));
                              } else {
                                controller.endTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, to.hour, to.minute));
                                controller.update();
                              }
                            }
                          } else {
                            if (to!.format(context).toString() == "12:00 AM") {
                              controller.endTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59));
                            } else {
                              controller.endTime!.value = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, to.hour, to.minute));
                              controller.update();
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                DsFieldLabel('Days'.tr),
                Wrap(
                  spacing: DsSpace.sm,
                  runSpacing: DsSpace.sm,
                  children: controller.selectedDaysList!
                      .map((item) {
                        return FilterChip(
                          showCheckmark: false,
                          label: Text(item.toString()),
                          selected: controller.selectedDays!.contains(item.toString()),
                          onSelected: (bool selected) {
                            if (selected) {
                              controller.selectedDays!.add(item.toString());
                            } else {
                              controller.selectedDays!.remove(item.toString());
                            }
                          },
                        );
                      })
                      .toList()
                      .cast<Widget>(),
                ),
                const DsGap(DsSpace.sm),
              ],
            ),
            // ── Pricing ───────────────────────────────────────────────────
            DsFormSection(
              title: 'Pricing'.tr,
              icon: Icons.sell_outlined,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DsFieldLabel('Price'.tr, required: true),
                          TextFormField(
                            maxLength: 5,
                            textInputAction: TextInputAction.done,
                            controller: controller.rprice.value,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            style: t.bodyStrong.tabular,
                            cursorColor: c.brand,
                            validator: validateEmptyField,
                            decoration: DsInputDecoration.of(
                              context,
                              hint: "0",
                              counterText: '',
                              prefix: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md),
                                child: Text(currencyData!.symbol.toString(), style: t.bodyStrong.withColor(c.textSecondary)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DsFieldLabel('Discount Price'.tr),
                          TextFormField(
                            maxLength: 5,
                            textInputAction: TextInputAction.done,
                            controller: controller.disprice.value,
                            onChanged: (val) {
                              var regularPrice = double.parse(controller.rprice.value.text.toString());
                              var discountedPrice = double.parse(controller.disprice.value.text.toString());

                              if (discountedPrice > regularPrice) {
                                controller.isDiscountedPriceOk.value = true;
                                ShowToastDialog.showToast('Please enter valid discount price'.tr);
                              } else {
                                controller.isDiscountedPriceOk.value = false;
                              }
                              controller.update();
                            },
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            style: t.bodyStrong.tabular,
                            cursorColor: c.brand,
                            //validator: validateEmptyField,
                            decoration: DsInputDecoration.of(
                              context,
                              hint: "0",
                              counterText: '',
                              prefix: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md),
                                child: Text(currencyData!.symbol.toString(), style: t.bodyStrong.withColor(c.textSecondary)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.lg),
                DsDropdown<String>(
                  label: "Price Unit".tr,
                  hint: "Select Price Unit".tr,
                  prefixIcon: Icons.timelapse_outlined,
                  validator: (value) => value == null ? 'field required' : null,
                  value: controller.priceUnit!.isEmpty ? null : controller.priceUnit!.value,
                  onChanged: (value) {
                    controller.priceUnit!.value = value!;
                  },
                  items: controller.priceUnitList.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(item.toString()),
                    );
                  }).toList(),
                  bottomSpacing: DsSpace.sm,
                ),
              ],
            ),
            // ── Visibility ────────────────────────────────────────────────
            DsCard.outlined(
              margin: const EdgeInsets.only(bottom: DsSpace.lg),
              padding: const EdgeInsets.all(DsSpace.lg),
              child: Row(
                children: [
                  DsIconWell(
                    icon: controller.publish.value ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    tone: controller.publish.value ? DsTone.success : DsTone.neutral,
                    size: 40,
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Publish'.tr, style: t.titleSm),
                        const DsGap(DsSpace.xxs),
                        Text(
                          controller.publish.value ? 'Customers can find and book this service.'.tr : 'This service stays hidden from customers.'.tr,
                          style: t.bodySm,
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: controller.publish.value,
                    onChanged: (bool newValue) {
                      controller.publish.value = newValue;
                      controller.update();
                    },
                  ),
                ],
              ),
            ),
            // ── Media ─────────────────────────────────────────────────────
            DsFormSection(
              title: 'Add Photos'.tr,
              icon: Icons.photo_library_outlined,
              children: [
                SizedBox(
                  height: 108,
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'Add Photos'.tr,
                        child: InkWell(
                          borderRadius: DsRadius.brMd,
                          onTap: () {
                            pickImage(controller);
                          },
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: c.brandSoft,
                              borderRadius: DsRadius.brMd,
                              border: Border.all(color: c.brand.withValues(alpha: 0.4), width: 1.4),
                            ),
                            child: Icon(
                              CupertinoIcons.camera,
                              size: 34,
                              color: c.brandStrong,
                            ),
                          ),
                        ),
                      ),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: ListView.builder(
                          itemCount: controller.mediaFiles.length,
                          itemBuilder: (context, index) {
                            return imageBuilder(controller.mediaFiles[index], controller, context);
                          },
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                        ),
                      ),
                    ],
                  ),
                ),
                const DsGap(DsSpace.sm),
              ],
            ),
            ]),
          ),
        ),
      ),
    );
  }

  pickImage(controller) {
    final action = CupertinoActionSheet(
      message: Text(
        'Add Picture'.tr,
        style: const TextStyle(fontSize: 15.0),
      ),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDefaultAction: false,
          onPressed: () async {
            Get.back();
            XFile? image = await controller.imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              controller.mediaFiles.add(File(image.path));
            }
            controller.update();
          },
          child: Text('Choose image from gallery'.tr),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () async {
            Get.back();
            XFile? image = await controller.imagePicker.pickImage(source: ImageSource.camera);
            if (image != null) {
              controller.mediaFiles.add(File(image.path));
              controller.update();
            }
          },
          child: Text('Take a picture'.tr),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr),
        onPressed: () {
          Get.back();
        },
      ),
    );
    showCupertinoModalPopup(context: MyAppState.navigatorKey.currentContext!, builder: (context) => action);
  }

  Widget imageBuilder(dynamic image, AddOrUpdateServiceController controller, BuildContext context) {
    final c = DsColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: DsSpace.md),
      child: SizedBox(
        width: 100,
        height: 100,
        child: ClipRRect(
          borderRadius: DsRadius.brMd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: c.surfaceAlt),
              image is File
                  ? Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: 100,
                      height: 100,
                    )
                  : displayImage(image),
              PositionedDirectional(
                top: 2,
                end: 2,
                child: DsIconButton(
                  icon: Icons.cancel,
                  semanticLabel: 'Remove'.tr,
                  size: 28,
                  color: c.danger,
                  onPressed: () {
                    if (image is File) {
                      controller.mediaFiles.removeWhere((value) => value is File && value.path == image.path);
                    } else {
                      controller.mediaFiles.removeWhere((value) => value is String && value == image);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<TimeOfDay?> _selectTime(context) async {
    FocusScope.of(
      context,
    ).requestFocus(FocusNode()); //remove focus
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (newTime != null) {
      return newTime;
    }
    return null;
  }
}

/// A read-only, DS-styled tappable field for pickers (time, date) whose value
/// lives in a plain observable rather than a [TextEditingController].
class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({required this.label, required this.value, required this.hint, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DsFieldLabel(label, required: true),
        Semantics(
          button: true,
          label: '$label: ${hasValue ? value! : hint}',
          child: InkWell(
            borderRadius: DsRadius.brMd,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: DsRadius.brMd,
                border: Border.all(color: c.isDark ? c.border : c.surfaceAlt),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: c.textMuted),
                  const DsGap(DsSpace.sm),
                  Expanded(
                    child: Text(
                      hasValue ? value! : hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hasValue ? t.bodyStrong.tabular : t.body.withColor(c.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
