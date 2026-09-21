import 'package:cached_network_image/cached_network_image.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/all_services_controller.dart';
import 'package:spideliprovider/controller/dashboard_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/app_colors.dart';
import 'package:spideliprovider/themes/responsive.dart';
import 'package:spideliprovider/ui/add_service/add_or_update_service.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class AllServiceScreen extends StatelessWidget {
  const AllServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<AllServicesController>(
        global: false,
        init: AllServicesController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: themeChange.getTheme() ? AppColors.colorDark : AppColors.colorWhite,
            body: RefreshIndicator(
              onRefresh: () async {
                controller.getData();
              },
              child: controller.isLoading.value
                  ? loader()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: controller.providerList.isEmpty
                          ? emptyView(text: 'Service is not available.'.tr, themeChange: themeChange)
                          : SizedBox(
                              height: Responsive.height(85, context),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: controller.providerList.length,
                                itemBuilder: (context, index) {
                                  return buildCategoryItem(controller.providerList[index], index, context, controller, themeChange);
                                },
                              ),
                            ),
                    ),
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: AppColors.colorPrimary,
              onPressed: () {
                if ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) && MyAppState.currentUser?.subscriptionPlan != null) {
                  if (MyAppState.currentUser?.subscriptionPlan?.itemLimit != '-1' &&
                      (controller.providerList.isEmpty == true ? 0 : controller.providerList.length) >= int.parse(MyAppState.currentUser?.subscriptionPlan?.itemLimit ?? '0')) {
                    ShowToastDialog.showToast("You have reached the maximum service capacity for your current plan. Upgrade your subscription to continue add service seamlessly!.".tr);
                    return;
                  } else {
                    Get.to(const AddOrUpdateServiceScreen())?.then((value) {
                      if (value != null) {
                        controller.getData();
                      }
                    });
                  }
                } else {
                  Get.to(const AddOrUpdateServiceScreen())?.then((value) {
                    if (value != null) {
                      controller.getData();
                    }
                  });
                }
              },
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            ),
          );
        });
  }

  buildCategoryItem(ProviderServiceModel model, int index, BuildContext context, controller, themeChange) {
    bool isDisplayItemAlert = false;
    print("isSubscriptionModelApplied :: ${isSubscriptionModelApplied} :: ${selectedSectionModel?.adminCommision?.enable} :: ${model.subscriptionTotalOrders}");
    if ((isSubscriptionModelApplied == true || selectedSectionModel?.adminCommision?.enable == true) && MyAppState.currentUser?.subscriptionPlan != null) {
      if (model.subscriptionPlan?.itemLimit == '-1') {
        isDisplayItemAlert = false;
      } else {
        isDisplayItemAlert = (index < int.parse(MyAppState.currentUser?.subscriptionPlan?.itemLimit ?? '0') == true) ? false : true;
      }
    } else {
      isDisplayItemAlert = false;
    }

    return Container(
      height: Responsive.height(30, context),
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: () async {
          Get.to(const AddOrUpdateServiceScreen(), arguments: {
            "providerModel": model,
          })?.then((value) {
            if (value != null) {
              controller.getData();
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300, width: 1),
            color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorLightGrey,
          ),
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.08,
                    width: MediaQuery.of(context).size.width,
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: model.photos.isNotEmpty ? model.photos.first.toString() : '',
                          imageBuilder: (context, imageProvider) => Container(
                            height: MediaQuery.of(context).size.height * 0.28,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                              border: Border.all(color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : Colors.grey.shade100, width: 1),
                              color: themeChange.getTheme() ? AppColors.darkContainerBorderColor : AppColors.colorLightGrey,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          placeholder: (context, url) => ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/placeholder.png',
                              fit: BoxFit.fill,
                              width: MediaQuery.of(context).size.width,
                            ),
                          ),
                          errorWidget: (context, url, error) => Image.asset(
                            'assets/images/placeholder.png',
                            width: MediaQuery.of(context).size.width,
                            fit: BoxFit.fill,
                          ),
                        ),
                        Positioned(
                          top: 15,
                          right: 10,
                          child: InkWell(
                            onTap: () {
                              showAlertDialog(model, context, controller);
                            },
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.red,
                              ),
                              child: const Icon(
                                Icons.delete_outline_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              model.title!,
                              maxLines: 1,
                              style: const TextStyle(
                                letterSpacing: 0.5,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.colorPrimary,
                              border: Border.all(
                                color: AppColors.colorWhite,
                                width: 1,
                              ),
                            ),
                            child: model.disPrice == "" || model.disPrice == "0"
                                ? Text(
                                    model.priceUnit == 'Fixed' ? amountShow(amount: model.price) : '${amountShow(amount: model.price)}/hr',
                                    style: TextStyle(
                                      fontFamily: "Poppinsm",
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.colorWhite,
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Text(
                                        model.priceUnit == 'Fixed' ? amountShow(amount: model.disPrice) : '${amountShow(amount: model.disPrice)}/hr',
                                        style: TextStyle(
                                          fontFamily: "Poppinsm",
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.0,
                                          color: AppColors.colorWhite,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8.0),
                                        child: Text(
                                          model.priceUnit == 'Fixed' ? amountShow(amount: model.price) : '${amountShow(amount: model.price)}/hr',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0, color: Colors.grey, decoration: TextDecoration.lineThrough),
                                        ),
                                      ),
                                    ],
                                  ),
                          )
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(model.reviewsCount != 0 ? (model.reviewsSum! / model.reviewsCount!).toStringAsFixed(1) : 0.toString(),
                                      style: const TextStyle(
                                        letterSpacing: 0.5,
                                        color: Colors.white,
                                      )),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                FutureBuilder(
                                    future: FireStoreUtils.getCategoryById(model.categoryId.toString()),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Center(child: Container());
                                      } else {
                                        if (snapshot.hasError) {
                                          return Center(child: Text('Error: ' + '${snapshot.error}'));
                                        } else {
                                          return Text(
                                            snapshot.data != null ? snapshot.data!.title.toString() : "",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontFamily: "Poppinsm",
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }
                                      }
                                    }),
                                Text(
                                  " / ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: "Poppinsm",
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                FutureBuilder(
                                    future: FireStoreUtils.getCategoryById(model.subCategoryId.toString()),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Center(child: Container());
                                      } else {
                                        if (snapshot.hasError) {
                                          return Center(child: Text('Error: ' + '${snapshot.error}'));
                                        } else {
                                          return Text(
                                            snapshot.data != null ? snapshot.data!.title.toString() : "",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontFamily: "Poppinsm",
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }
                                      }
                                    }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Visibility(
                  visible: isDisplayItemAlert,
                  child: Text(
                    "This service will not be displayed to customers due to your current subscription limitations.".tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  showAlertDialog(ProviderServiceModel providerModel, BuildContext context, controller) {
    Widget okButton = TextButton(
      child: Text(
        "Ok".tr,
      ),
      onPressed: () async {
        ShowToastDialog.showLoader("Please wait".tr);

        FireStoreUtils.deleteProduct(providerModel.id!).then((value) async {
          ShowToastDialog.closeLoader();
          controller.getData();
          DashBoardController dashBoardController = Get.put(DashBoardController());
          dashBoardController.onSelectItem(1);
          await Get.to(const DashBoardScreen());
        });
      },
    );
    Widget cancel = TextButton(
      child: Text("Cancel".tr),
      onPressed: () {
        Get.back();
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text(providerModel.title!),
      content: Text('Are you sure you want to delete this service?'.tr),
      actions: [
        okButton,
        cancel,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}
