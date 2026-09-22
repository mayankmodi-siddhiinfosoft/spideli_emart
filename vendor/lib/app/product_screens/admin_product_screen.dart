import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/admin_product_controller.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/tax_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/fire_store_utils.dart';

/// Global Menu import: search bar + image-first catalogue grid
/// (2 columns on phones, more on tablets) with an import action per item.
class AdminProductScreen extends StatelessWidget {
  const AdminProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AdminProductController(),
      builder: (controller) {
        final l = context.dsLayout;
        final bool isLoading = controller.isLoading.value;
        final bool isEmpty = controller.productList.isEmpty == true;
        final int count = controller.productList.length;
        return DsScaffold(
          title: "Import Products".tr,
          onBack: () {
            Get.back(result: true);
          },
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.sm, l.gutter, DsSpace.sm),
                child: DsSearchBar(
                  hint: 'Search the product'.tr,
                  controller: controller.searchTextController.value,
                  onChanged: (value) {
                    controller.onSearchTextChanged(value);
                  },
                ),
              ),
              Expanded(
                child: DsAsync(
                  isLoading: isLoading,
                  skeleton: const DsSkeletonGrid(minItemWidth: 170, itemCount: 6),
                  isEmpty: isEmpty,
                  empty: Center(
                    child: DsEmptyState(icon: Icons.search_off_rounded, title: "No Result Found".tr, compact: true),
                  ),
                  builder: (context) {
                    final int columns = l.columnsFor(170).clamp(2, 5);
                    final int rows = (count / columns).ceil();
                    return ListView.builder(
                      itemCount: rows,
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.xs, l.gutter, DsSpace.xxxl),
                      itemBuilder: (context, row) {
                        final List<Widget> cells = [];
                        for (int j = 0; j < columns; j++) {
                          final int index = row * columns + j;
                          if (j > 0) cells.add(const DsGap(DsSpace.md));
                          cells.add(Expanded(child: index < count ? _productCard(context, controller, index) : const SizedBox.shrink()));
                        }
                        return DsFadeSlideIn(
                          index: row,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: DsSpace.md),
                            child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _productCard(BuildContext context, AdminProductController controller, int index) {
    final c = context.dsColors;
    final t = context.dsText;
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

    return DsCard.outlined(
      padding: EdgeInsets.zero,
      semanticLabel: controller.productList[index].name.toString(),
      onTap: () {
        productDetailsBottomSheet(context, controller.productList[index], controller);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsImage(url: controller.productList[index].photo.toString(), height: 120, radius: 0, errorIcon: Icons.fastfood_outlined),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.md, DsSpace.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.productList[index].name.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.label),
                const DsGap(DsSpace.xs),
                double.parse(disPrice) <= 0
                    ? Text(Constant.amountShow(amount: price), style: t.label.withColor(c.brandStrong).tabular)
                    : Wrap(
                        spacing: DsSpace.xs + 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(Constant.amountShow(amount: disPrice), style: t.label.withColor(c.brandStrong).tabular),
                          Text(Constant.amountShow(amount: price), style: t.caption.strike),
                        ],
                      ),
                const DsGap(DsSpace.xs),
                Text(controller.productList[index].description.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.caption),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.sm, DsSpace.xs, DsSpace.sm, DsSpace.sm),
            child: DsButton.tonal(
              label: "Import Product".tr,
              icon: Icons.download_rounded,
              size: DsButtonSize.sm,
              expand: true,
              onPressed: () async {
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
          ),
        ],
      ),
    );
  }

  Future<dynamic> productDetailsBottomSheet(BuildContext context, ProductModel productModel, AdminProductController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: context.dsColors.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
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
    final c = context.dsColors;
    final t = context.dsText;
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: DsLayout.contentMax),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.sm, DsSpace.xl, DsSpace.lg),
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: DsRadius.sheetTop),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: DsSpace.sm),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
                  ),
                ),

                /// HEADER
                Row(
                  children: [
                    const DsIconWell(icon: Icons.receipt_long_rounded, size: 40),
                    const DsGap(DsSpace.md),
                    Expanded(child: Text('Select Taxes'.tr, style: t.title)),
                    DsIconButton(icon: Icons.close_rounded, semanticLabel: 'Close'.tr, onPressed: () => Get.back()),
                  ],
                ),
                const DsGap(DsSpace.md),
                DsInlineAlert(tone: DsTone.info, message: "Note: Tax selection is optional. You can add taxes later from manage product section.".tr),
                const DsGap(DsSpace.sm),

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
                          onChanged: (value) => controller.toggleSelection(index, value!),
                          title: Text("${taxModel.title.toString()} (${taxModel.type == "fix" ? Constant.amountShow(amount: taxModel.tax) : "${taxModel.tax}%"})", style: t.bodyStrong),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                ),
                const DsGap(DsSpace.md),

                DsButton.primary(
                  label: "Import Product".tr,
                  icon: Icons.download_rounded,
                  expand: true,
                  onPressed: () async {
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
          ),
        ),
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
    final c = context.dsColors;
    final t = context.dsText;
    return Scaffold(
      backgroundColor: c.surfaceRaised,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.sm, DsSpace.xl, DsSpace.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: DsSpace.lg),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
              ),
            ),
            DsFadeSlideIn(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DsImage(url: productModel.photo.toString(), width: 88, height: 88, radius: DsRadius.lg, errorIcon: Icons.fastfood_outlined),
                  const DsGap(DsSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(productModel.name.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.title),
                        const DsGap(DsSpace.xs),
                        Text(productModel.description.toString(), style: t.bodySm),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const DsGap(DsSpace.lg),
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
                      return DsFadeSlideIn(
                        index: index + 1,
                        child: DsCard.outlined(
                          margin: const EdgeInsets.only(bottom: DsSpace.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              productModel.itemAttribute!.attributes![index].attributeOptions!.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(bottom: DsSpace.md),
                                      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm),
                                    )
                                  : const Offstage(),
                              Wrap(
                                spacing: DsSpace.sm,
                                runSpacing: DsSpace.sm,
                                children: List.generate(productModel.itemAttribute!.attributes![index].attributeOptions!.length, (i) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm - 2),
                                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brPill),
                                    child: Text(
                                      productModel.itemAttribute!.attributes![index].attributeOptions![i].toString(),
                                      overflow: TextOverflow.ellipsis,
                                      style: t.bodyStrong,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            productModel.addOnsTitle == null || productModel.addOnsTitle!.isEmpty
                ? const SizedBox()
                : DsFadeSlideIn(
                    index: 2,
                    child: DsCard.outlined(
                      padding: const EdgeInsets.symmetric(vertical: DsSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                            child: Text("Addons".tr, style: t.titleSm),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(vertical: DsSpace.sm), child: Divider(height: 1, color: c.divider)),
                          ListView.builder(
                            itemCount: productModel.addOnsTitle!.length,
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              String title = productModel.addOnsTitle![index];
                              String price = productModel.addOnsPrice![index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
                                child: Row(
                                  children: [
                                    Icon(Icons.add_circle_outline_rounded, size: 18, color: c.textMuted),
                                    const DsGap(DsSpace.sm),
                                    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong)),
                                    const DsGap(DsSpace.sm),
                                    Text(Constant.amountShow(amount: price), maxLines: 1, style: t.label.withColor(c.brandStrong).tabular),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
