import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/admin_product_controller.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';

class AdminProductScreen extends StatelessWidget {
  const AdminProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: AdminProductController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            title: Text(
              "Import Products".tr,
              style: TextStyle(color: AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
            leading: InkWell(
              onTap: () {
                Get.back(result: true);
              },
              child: Icon(Icons.arrow_back_ios_new),
            ),
            iconTheme: IconThemeData(color: AppThemeData.grey50),
          ),
          body: Column(
            children: [
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextFieldWidget(
                  hintText: 'Search the product'.tr,
                  prefix: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SvgPicture.asset("assets/icons/ic_search.svg", width: 20, height: 20)),
                  controller: controller.searchTextController.value,
                  onchange: (value) {
                    controller.onSearchTextChanged(value);
                  },
                ),
              ),
              Expanded(
                child: controller.isLoading.value
                    ? Constant.loader()
                    : controller.productList.isEmpty == true
                    ? Constant.showEmptyView(message: "No Result Found".tr, isDark: themeController.isDark.value)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          itemCount: controller.productList.length,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            String price = "0.0";
                            String disPrice = "0.0";
                            List<String> selectedVariants = [];
                            List<String> selectedIndexVariants = [];
                            List<String> selectedIndexArray = [];
                            if (controller.productList[index].itemAttribute != null) {
                              if (controller.productList[index].itemAttribute!.attributes!.isNotEmpty) {
                                for (var element in controller.productList[index].itemAttribute!.attributes!) {
                                  if (element.attributeOptions!.isNotEmpty) {
                                    selectedVariants.add(
                                      controller.productList[index].itemAttribute!.attributes![controller.productList[index].itemAttribute!.attributes!.indexOf(element)].attributeOptions![0]
                                          .toString(),
                                    );
                                    selectedIndexVariants.add(
                                      '${controller.productList[index].itemAttribute!.attributes!.indexOf(element)} _${controller.productList[index].itemAttribute!.attributes![0].attributeOptions![0].toString()}',
                                    );
                                    selectedIndexArray.add('${controller.productList[index].itemAttribute!.attributes!.indexOf(element)}_0');
                                  }
                                }
                              }
                              if (controller.productList[index].itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).isNotEmpty) {
                                price = controller.productList[index].itemAttribute!.variants!.where((element) => element.variantSku == selectedVariants.join('-')).first.variantPrice ?? '0';
                                disPrice = '0';
                              }
                            } else {
                              price = controller.productList[index].price.toString();
                              disPrice = controller.productList[index].disPrice.toString();
                            }

                            return InkWell(
                              splashColor: Colors.transparent,
                              onTap: () {
                                productDetailsBottomSheet(context, controller.productList[index], controller);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Container(
                                  decoration: ShapeDecoration(
                                    color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: const BorderRadius.all(Radius.circular(16)),
                                              child: Stack(
                                                children: [
                                                  NetworkImageWidget(
                                                    imageUrl: controller.productList[index].photo.toString(),
                                                    fit: BoxFit.cover,
                                                    height: Responsive.height(12, context),
                                                    width: Responsive.width(24, context),
                                                  ),
                                                  Container(
                                                    height: Responsive.height(12, context),
                                                    width: Responsive.width(24, context),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: const Alignment(-0.00, -1.00),
                                                        end: const Alignment(0, 1),
                                                        colors: [Colors.black.withOpacity(0), const Color(0xFF111827)],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    controller.productList[index].name.toString(),
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                      fontFamily: AppThemeData.semiBold,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  double.parse(disPrice) <= 0
                                                      ? Text(
                                                          Constant.amountShow(amount: price),
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                            fontFamily: AppThemeData.semiBold,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        )
                                                      : Row(
                                                          children: [
                                                            Text(
                                                              Constant.amountShow(amount: disPrice),
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                                                fontFamily: AppThemeData.semiBold,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 5),
                                                            Text(
                                                              Constant.amountShow(amount: price),
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                decoration: TextDecoration.lineThrough,
                                                                decorationColor: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                                color: isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                                                                fontFamily: AppThemeData.semiBold,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                  Text(
                                                    controller.productList[index].description.toString(),
                                                    maxLines: 2,
                                                    style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        RoundedButtonFill(
                                          title: "Import Product".tr,
                                          color: AppThemeData.primary300,
                                          height: 4.2,
                                          textColor: AppThemeData.grey50,
                                          onPress: () async {
                                            if ((Constant.isSubscriptionModelApplied == true || Constant.vendorAdminCommission?.isEnabled == true) &&
                                                controller.vendorModel.value.subscriptionPlan?.itemLimit != '-1' &&
                                                int.parse(
                                                      controller.vendorModel.value.subscriptionPlan?.itemLimit != null && controller.vendorModel.value.subscriptionPlan?.itemLimit.toString() != "null"
                                                          ? "${controller.vendorModel.value.subscriptionPlan?.itemLimit}"
                                                          : '0',
                                                    ) <=
                                                    controller.vendorProductList.length) {
                                              ShowToastDialog.showToast("Your current subscription plan has reached its maximum product limit. Upgrade now to add more products.".tr);
                                            } else {
                                              if (Constant.taxScope == "product" && controller.taxList.isNotEmpty == true) {
                                                for (var tax in controller.taxList) {
                                                  tax.isSelected = false;
                                                }

                                                Get.bottomSheet(TaxBottomSheet(productModel: controller.productList[index]), isScrollControlled: true, backgroundColor: Colors.transparent);
                                              } else {
                                                ShowToastDialog.showToast("Importing product...".tr);
                                                controller.productList[index].id = Constant.getUuid();
                                                controller.productList[index].vendorID = Constant.userModel!.vendorID;
                                                controller.productList[index].createdAt = Timestamp.now();
                                                controller.productList[index].sectionId = Constant.selectedSection?.id;
                                                await FireStoreUtils.updateProduct(controller.productList[index]);
                                                await controller.getVendorProduct();
                                                ShowToastDialog.closeLoader();
                                                ShowToastDialog.showToast("Product imported successfully".tr);
                                              }
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<dynamic> productDetailsBottomSheet(BuildContext context, ProductModel productModel, AdminProductController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: StatefulBuilder(
          builder: (context1, setState) {
            return ProductDetailsView(productModel: productModel, controller: controller);
          },
        ),
      ),
    );
  }
}

class TaxBottomSheet extends StatelessWidget {
  final ProductModel productModel;

  TaxBottomSheet({super.key, required this.productModel});

  final AdminProductController controller = Get.find<AdminProductController>();

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.grey900 : AppThemeData.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          /// HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select Taxes'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
            ],
          ),
          Text("Note: Tax selection is optional. You can add taxes later from manage product section.".tr, style: TextStyle(fontSize: 14, fontFamily: AppThemeData.regular)),
          SizedBox(height: 5),
          const Divider(),

          /// CHECKBOX LIST
          Expanded(
            child: Obx(
              () => ListView.builder(
                itemCount: controller.taxList.length,
                itemBuilder: (context, index) {
                  final taxModel = controller.taxList[index];
                  return CheckboxListTile(
                    value: taxModel.isSelected,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) => controller.toggleSelection(index, value!),
                    title: Text("${taxModel.title.toString()} (${taxModel.type == "fix" ? Constant.amountShow(amount: taxModel.tax) : "${taxModel.tax}%"})"),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ),

          RoundedButtonFill(
            title: "Import Product".tr,
            color: AppThemeData.primary300,
            height: 4.2,
            textColor: AppThemeData.grey50,
            onPress: () async {
              List<TaxModel> selected = controller.selectedTaxes;
              ShowToastDialog.showToast("Importing product...".tr);
              productModel.id = Constant.getUuid();
              productModel.vendorID = Constant.userModel!.vendorID;
              productModel.createdAt = Timestamp.now();
              productModel.taxSetting = selected;
              await FireStoreUtils.updateProduct(productModel);
              await controller.getVendorProduct();
              ShowToastDialog.closeLoader();
              ShowToastDialog.showToast("Product imported successfully".tr);
              Get.back(result: true);
            },
          ),
        ],
      ),
    );
  }
}

class ProductDetailsView extends StatelessWidget {
  final ProductModel productModel;
  final AdminProductController controller;

  const ProductDetailsView({super.key, required this.productModel, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Scaffold(
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      child: Stack(
                        children: [
                          NetworkImageWidget(imageUrl: productModel.photo.toString(), height: Responsive.height(11, context), width: Responsive.width(22, context), fit: BoxFit.cover),
                          Container(
                            height: Responsive.height(11, context),
                            width: Responsive.width(22, context),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: const Alignment(-0.00, -1.00), end: const Alignment(0, 1), colors: [Colors.black.withOpacity(0), const Color(0xFF111827)]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  productModel.name.toString(),
                                  textAlign: TextAlign.start,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 16,
                                    overflow: TextOverflow.ellipsis,
                                    fontFamily: AppThemeData.semiBold,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            productModel.description.toString(),
                            textAlign: TextAlign.start,
                            style: TextStyle(fontSize: 12, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w400, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            productModel.itemAttribute == null || productModel.itemAttribute!.attributes!.isEmpty
                ? const SizedBox()
                : ListView.builder(
                    itemCount: productModel.itemAttribute!.attributes!.length,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      String title = "";
                      for (var element in controller.attributesList) {
                        if (productModel.itemAttribute!.attributes![index].attributeId == element.id) {
                          title = element.title.toString();
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        child: Container(
                          decoration: ShapeDecoration(
                            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                productModel.itemAttribute!.attributes![index].attributeOptions!.isNotEmpty
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                overflow: TextOverflow.ellipsis,
                                                fontFamily: AppThemeData.semiBold,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                              ),
                                            ),
                                          ),
                                          // Padding(
                                          //   padding: const EdgeInsets.symmetric(horizontal: 10),
                                          //   child: Text(
                                          //     "Required • Select any 1 option".tr,
                                          //     style: TextStyle(
                                          //       fontSize: 12,
                                          //       overflow: TextOverflow.ellipsis,
                                          //       fontFamily: AppThemeData.medium,
                                          //       fontWeight: FontWeight.w500,
                                          //       color: isDark ? AppThemeData.grey400 : AppThemeData.grey500,
                                          //     ),
                                          //   ),
                                          // ),
                                          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                                        ],
                                      )
                                    : Offstage(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Wrap(
                                    spacing: 6.0,
                                    runSpacing: 6.0,
                                    children: List.generate(productModel.itemAttribute!.attributes![index].attributeOptions!.length, (i) {
                                      return Chip(
                                        shape: const RoundedRectangleBorder(
                                          side: BorderSide(color: Colors.transparent),
                                          borderRadius: BorderRadius.all(Radius.circular(20)),
                                        ),
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              productModel.itemAttribute!.attributes![index].attributeOptions![i].toString(),
                                              style: TextStyle(
                                                overflow: TextOverflow.ellipsis,
                                                fontFamily: AppThemeData.medium,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? AppThemeData.grey600 : AppThemeData.grey900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                                        elevation: 6.0,
                                        padding: const EdgeInsets.all(8.0),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            productModel.addOnsTitle == null || productModel.addOnsTitle!.isEmpty
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Container(
                      decoration: ShapeDecoration(
                        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                "Addons".tr,
                                style: TextStyle(
                                  fontSize: 16,
                                  overflow: TextOverflow.ellipsis,
                                  fontFamily: AppThemeData.semiBold,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                ),
                              ),
                            ),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                            ListView.builder(
                              itemCount: productModel.addOnsTitle!.length,
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index) {
                                String title = productModel.addOnsTitle![index];
                                String price = productModel.addOnsPrice![index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          textAlign: TextAlign.start,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 16,
                                            overflow: TextOverflow.ellipsis,
                                            fontFamily: AppThemeData.medium,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        Constant.amountShow(amount: price),
                                        textAlign: TextAlign.start,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 16,
                                          overflow: TextOverflow.ellipsis,
                                          fontFamily: AppThemeData.medium,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? AppThemeData.grey100 : AppThemeData.grey800,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
