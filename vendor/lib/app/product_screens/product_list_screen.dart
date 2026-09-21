import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vendor/app/product_screens/admin_product_screen.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/product_screens/add_product_screen.dart';
import 'package:vendor/app/verification_screen/verification_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/product_list_controller.dart';
import 'package:vendor/themes/app_them_data.dart';
import 'package:vendor/themes/responsive.dart';
import 'package:vendor/themes/round_button_fill.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/utils/network_image_widget.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ProductListController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppThemeData.primary300,
            centerTitle: false,
            title: Text(
              "Manage Products".tr,
              style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
            ),
            actions: [
              (controller.userModel.value.isDocumentVerify == false && controller.userModel.value.isAutoVerify == false) ||
                      (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty)
                  ? const SizedBox()
                  : InkWell(
                      onTap: () {
                        if ((Constant.isSubscriptionModelApplied == true || Constant.selectedSection!.adminCommision?.isEnabled == true) &&
                            controller.vendorModel.value.subscriptionPlan?.itemLimit != '-1' &&
                            int.parse(
                                  controller.vendorModel.value.subscriptionPlan?.itemLimit != null && controller.vendorModel.value.subscriptionPlan?.itemLimit.toString() != "null"
                                      ? "${controller.vendorModel.value.subscriptionPlan?.itemLimit}"
                                      : '0',
                                ) <=
                                controller.productList.length) {
                          ShowToastDialog.showToast("Your current subscription plan has reached its maximum product limit. Upgrade now to add more products.".tr);
                        } else {
                          showAddProductBottomSheet(context, controller, isDark);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.add, color: isDark ? AppThemeData.grey900 : AppThemeData.grey50),
                            const SizedBox(width: 5),
                            Text(
                              "Add".tr,
                              style: TextStyle(color: isDark ? AppThemeData.grey900 : AppThemeData.grey50, fontSize: 18, fontFamily: AppThemeData.medium),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : controller.userModel.value.isAutoVerify == false && true && controller.userModel.value.isDocumentVerify == false
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: ShapeDecoration(
                          color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                        ),
                        child: Padding(padding: const EdgeInsets.all(20), child: SvgPicture.asset("assets/icons/ic_document.svg")),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Document Verification in Pending".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                      ),
                      const SizedBox(height: 20),
                      RoundedButtonFill(
                        title: "View Status".tr,
                        width: 55,
                        height: 5.5,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () async {
                          Get.to(const VerificationScreen());
                        },
                      ),
                    ],
                  ),
                )
              : controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: ShapeDecoration(
                          color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                        ),
                        child: Padding(padding: const EdgeInsets.all(20), child: SvgPicture.asset("assets/icons/ic_building_two.svg")),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Add Your First Store".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Get started by adding your store details to manage your menu, orders.".tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                      ),
                      const SizedBox(height: 20),
                      RoundedButtonFill(
                        title: "Add Store".tr,
                        width: 55,
                        height: 5.5,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () async {
                          Get.to(const AddRestaurantScreen());
                        },
                      ),
                    ],
                  ),
                )
              : controller.productList.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: ShapeDecoration(
                          color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(120)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SvgPicture.asset("assets/icons/ic_menu.svg", colorFilter: ColorFilter.mode(isDark ? AppThemeData.grey400 : AppThemeData.grey500, BlendMode.srcIn)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No Products Available".tr,
                        style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 22, fontFamily: AppThemeData.semiBold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Your menu is currently empty. Create your first product to start showcasing your offerings.".tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey500, fontSize: 16, fontFamily: AppThemeData.bold),
                      ),
                      const SizedBox(height: 20),
                      RoundedButtonFill(
                        title: "Add Product".tr,
                        width: 55,
                        height: 5.5,
                        color: AppThemeData.primary300,
                        textColor: AppThemeData.grey50,
                        onPress: () async {
                          if ((Constant.isSubscriptionModelApplied == true || Constant.selectedSection!.adminCommision?.isEnabled == true) &&
                              controller.vendorModel.value.subscriptionPlan?.itemLimit != '-1' &&
                              int.parse(
                                    controller.vendorModel.value.subscriptionPlan?.itemLimit != null && controller.vendorModel.value.subscriptionPlan?.itemLimit.toString() != "null"
                                        ? "${controller.vendorModel.value.subscriptionPlan?.itemLimit}"
                                        : '0',
                                  ) <=
                                  controller.productList.length) {
                            ShowToastDialog.showToast("Your current subscription plan has reached its maximum product limit. Upgrade now to add more products.".tr);
                          } else {
                            showAddProductBottomSheet(context, controller, isDark);
                          }
                        },
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: ListView.builder(
                    itemCount: controller.productList.length,
                    shrinkWrap: true,
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
                                controller.productList[index].itemAttribute!.attributes![controller.productList[index].itemAttribute!.attributes!.indexOf(element)].attributeOptions![0].toString(),
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

                      bool isDisplayItemAlert = false;
                      if ((Constant.isSubscriptionModelApplied == true || Constant.selectedSection!.adminCommision?.isEnabled == true)) {
                        if (controller.vendorModel.value.subscriptionPlan?.itemLimit == '-1') {
                          isDisplayItemAlert = false;
                        } else {
                          isDisplayItemAlert = (index < int.parse(controller.userModel.value.subscriptionPlan?.itemLimit ?? '0') == true) ? false : true;
                        }
                      }

                      return InkWell(
                        splashColor: Colors.transparent,
                        onTap: () {
                          Get.to(const AddProductScreen(), arguments: {"productModel": controller.productList[index]})!.then((value) {
                            if (value == true) {
                              controller.getProduct();
                            }
                          });
                        },
                        child: Obx(
                          () => Padding(
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                              Row(
                                                children: [
                                                  SvgPicture.asset("assets/icons/ic_star.svg", colorFilter: const ColorFilter.mode(AppThemeData.warning300, BlendMode.srcIn)),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    "${Constant.calculateReview(reviewCount: controller.productList[index].reviewsCount!.toStringAsFixed(0), reviewSum: controller.productList[index].reviewsSum.toString())} (${controller.productList[index].reviewsCount!.toStringAsFixed(0)})",
                                                    style: TextStyle(color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular, fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                              Constant.taxScope == "product"
                                                  ? controller.productList[index].taxSetting?.isEmpty == true
                                                        ? Text(
                                                            controller.productList[index].description.toString(),
                                                            maxLines: 1,
                                                            style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular),
                                                          )
                                                        : Text(
                                                            controller.getTaxDisplayText(controller.productList[index].taxSetting) == ''
                                                                ? controller.productList[index].description.toString()
                                                                : "${'Tax:'.tr} ${controller.getTaxDisplayText(controller.productList[index].taxSetting)}",
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: controller.getTaxDisplayText(controller.productList[index].taxSetting) == ''
                                                                ? TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular)
                                                                : TextStyle(fontSize: 14, color: isDark ? AppThemeData.primary300 : AppThemeData.primary300, fontFamily: AppThemeData.semiBold),
                                                          )
                                                  : Text(
                                                      controller.productList[index].description.toString(),
                                                      maxLines: 1,
                                                      style: TextStyle(fontSize: 12, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontFamily: AppThemeData.regular),
                                                    ),
                                            ],
                                          ),
                                        ),
                                        Constant.taxScope == "product" && controller.taxList.isNotEmpty == true
                                            ? Checkbox(
                                                value: controller.selectedProductIds.contains(controller.productList[index].id),
                                                onChanged: (value) {
                                                  controller.toggleProductSelection(controller.productList[index]);
                                                },
                                              )
                                            : SizedBox(),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            splashColor: Colors.transparent,
                                            onTap: () async {
                                              ShowToastDialog.showLoader("Please wait..".tr);
                                              await FireStoreUtils.deleteProduct(controller.productList[index]).then((value) {
                                                controller.getProduct();
                                                ShowToastDialog.closeLoader();
                                              });
                                            },
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                SvgPicture.asset("assets/icons/ic_delete-one.svg"),
                                                const SizedBox(width: 10),
                                                Text(
                                                  "Delete".tr,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: isDark ? AppThemeData.danger300 : AppThemeData.danger300, fontSize: 16, fontFamily: AppThemeData.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Publish".tr,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(color: isDark ? AppThemeData.grey100 : AppThemeData.grey800, fontSize: 16, fontFamily: AppThemeData.bold),
                                              ),
                                              Transform.scale(
                                                scale: 0.6,
                                                child: CupertinoSwitch(
                                                  activeTrackColor: AppThemeData.primary300,
                                                  value: controller.productList[index].publish ?? false,
                                                  onChanged: (value) async {
                                                    controller.updateList(index, controller.productList[index].publish!);
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Visibility(
                                      visible: isDisplayItemAlert,
                                      child: Text(
                                        "This product will not be displayed to customers due to your current subscription limitations.".tr,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: isDark ? AppThemeData.danger300 : AppThemeData.danger300, fontSize: 12, fontFamily: AppThemeData.regular),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

          floatingActionButton: Obx(() {
            if (controller.selectedProductIds.isEmpty) {
              return const SizedBox.shrink();
            }

            return SizedBox(
              height: 45, // 🔥 increase height here
              child: FloatingActionButton.extended(
                backgroundColor: AppThemeData.primary300,
                icon: const Icon(Icons.receipt_long, color: Colors.white),
                label: Text("${'Assign Tax'.tr} (${controller.selectedProductIds.length})", style: const TextStyle(color: Colors.white)),
                onPressed: () {
                  for (var tax in controller.taxList) {
                    tax.isSelected = false;
                  }
                  if (controller.selectedProducts.length == 1) {
                    if (controller.taxList.isNotEmpty == true && controller.selectedProducts[0].taxSetting?.isNotEmpty == true) {
                      for (var tax in controller.taxList) {
                        for (var item in controller.selectedProducts[0].taxSetting!) {
                          if (tax.id == item.id) {
                            tax.isSelected = true;
                          }
                        }
                      }
                    }
                  }
                  Get.bottomSheet(MultiProductTaxBottomSheet(products: controller.selectedProducts), isScrollControlled: true, backgroundColor: Colors.transparent);
                },
              ),
            );
          }),
        );
      },
    );
  }

  void showAddProductBottomSheet(BuildContext context, ProductListController controller, bool isDarkMode) {
    showModalBottomSheet(
      backgroundColor: isDarkMode ? AppThemeData.grey900 : AppThemeData.surface,
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AddProductBottomSheet(controller: controller),
    );
  }
}

class MultiProductTaxBottomSheet extends StatelessWidget {
  final List<ProductModel> products;

  MultiProductTaxBottomSheet({super.key, required this.products});

  final ProductListController controller = Get.find();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          /// HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${'Assign Tax to'.tr} ${products.length} ${'Products'.tr}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
            ],
          ),

          const Divider(),

          Expanded(
            child: Obx(
              () => ListView.builder(
                itemCount: controller.taxList.length,
                itemBuilder: (context, index) {
                  final tax = controller.taxList[index];
                  return CheckboxListTile(
                    value: tax.isSelected,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onChanged: (value) {
                      controller.toggleSelection(index, value!);
                    },
                    title: Text("${tax.title} (${tax.type == "fix" ? Constant.amountShow(amount: tax.tax) : "${tax.tax}%"})"),
                  );
                },
              ),
            ),
          ),

          /// APPLY BUTTON
          RoundedButtonFill(
            title: "Apply Tax",
            color: AppThemeData.primary300,
            height: 4.2,
            textColor: AppThemeData.grey50,
            onPress: () async {
              ShowToastDialog.showLoader("Updating...".tr);

              final selectedTaxes = controller.selectedTaxes;

              for (var product in products) {
                product.taxSetting = List.from(selectedTaxes);
                await FireStoreUtils.updateProduct(product);
              }

              controller.clearSelection();
              ShowToastDialog.closeLoader();
              ShowToastDialog.showToast("Tax applied successfully".tr);
              Get.back();
            },
          ),
        ],
      ),
    );
  }
}

class AddProductBottomSheet extends StatelessWidget {
  final ProductListController controller;

  const AddProductBottomSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Drag Handle
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
          ),

          const SizedBox(height: 20),

          /// Create New Product
          _optionTile(
            isDark: isDark,
            icon: Icons.add_box_rounded,
            title: "Create a new product",
            subtitle: "Add your own custom product",
            onTap: () {
              Get.back();
              Get.to(const AddProductScreen())!.then((value) {
                if (value == true) {
                  controller.getProduct();
                }
              });
            },
          ),

          const SizedBox(height: 12),

          /// Import From Admin
          _optionTile(
            isDark: isDark,
            icon: Icons.cloud_download_rounded,
            title: "Import products from Global Menu",
            subtitle: "Select from admin created Food products",
            onTap: () {
              Get.back();
              // Navigate to Admin Product List Screen
              Get.to(() => AdminProductScreen())?.then((value) {
                controller.getProduct();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _optionTile({required bool isDark, required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppThemeData.primary300.withOpacity(0.1),
              child: Icon(icon, color: AppThemeData.primary300),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.tr,
                    style: TextStyle(fontSize: 15, color: isDark ? AppThemeData.grey50 : AppThemeData.grey900, fontWeight: FontWeight.w600),
                  ),
                  Text(subtitle.tr, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
