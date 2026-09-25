import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/app/product_screens/admin_product_screen.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:vendor/app/add_restaurant_screen/add_restaurant_screen.dart';
import 'package:vendor/app/product_screens/add_product_screen.dart';
import 'package:vendor/app/product_screens/product_sale_labels.dart';
import 'package:vendor/app/verification_screen/verification_screen.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/product_list_controller.dart';
import 'package:vendor/utils/fire_store_utils.dart';

/// Catalogue (archetype B – list/feed): collapsing title, catalogue health
/// summary, image-led product cards (1 column on phones, 2–3 on tablets).
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: ProductListController(),
      builder: (controller) {
        final l = context.dsLayout;
        final bool canAdd =
            !((controller.userModel.value.isDocumentVerify == false && controller.userModel.value.isAutoVerify == false) ||
                (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty));
        final bool showList = !controller.isLoading.value &&
            !(controller.userModel.value.isAutoVerify == false && true && controller.userModel.value.isDocumentVerify == false) &&
            !(controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty) &&
            controller.productList.isNotEmpty;

        final List<Widget> slivers;
        if (controller.isLoading.value) {
          slivers = [
            DsSliverResponsive(
              maxWidth: DsLayout.wideMax,
              gutter: false,
              sliver: const SliverToBoxAdapter(child: DsSkeletonList(itemCount: 5)),
            ),
          ];
        } else if (controller.userModel.value.isAutoVerify == false && true && controller.userModel.value.isDocumentVerify == false) {
          slivers = [
            _statusFill(
              DsEmptyState(
                icon: Icons.pending_actions_rounded,
                tone: DsTone.warning,
                title: "Document Verification in Pending".tr,
                message: "Your documents are being reviewed. We will notify you once the verification is complete.".tr,
                actionLabel: "View Status".tr,
                actionIcon: Icons.verified_user_outlined,
                onAction: () async {
                  Get.to(const VerificationScreen());
                },
              ),
            ),
          ];
        } else if (controller.userModel.value.vendorID == null || controller.userModel.value.vendorID!.isEmpty) {
          slivers = [
            _statusFill(
              DsEmptyState(
                icon: Icons.storefront_outlined,
                title: "Add Your First Store".tr,
                message: "Get started by adding your store details to manage your menu, orders.".tr,
                actionLabel: "Add Store".tr,
                actionIcon: Icons.add_business_outlined,
                onAction: () async {
                  Get.to(const AddRestaurantScreen());
                },
              ),
            ),
          ];
        } else if (controller.productList.isEmpty) {
          slivers = [
            _statusFill(
              DsEmptyState(
                icon: Icons.inventory_2_outlined,
                title: "No Products Available".tr,
                message: "Your menu is currently empty. Create your first product to start showcasing your offerings.".tr,
                actionLabel: "Add Product".tr,
                actionIcon: Icons.add_rounded,
                onAction: () async {
                  _onAddProduct(context, controller, isDark);
                },
              ),
            ),
          ];
        } else {
          final int columns = l.value(phone: 1, tablet: 2, desktop: 3);
          final int rows = (controller.productList.length / columns).ceil();
          slivers = [
            DsSliverResponsive(
              maxWidth: DsLayout.wideMax,
              top: DsSpace.sm,
              sliver: SliverToBoxAdapter(child: DsFadeSlideIn(child: _CatalogueSummary(controller: controller))),
            ),
            DsSliverResponsive(
              maxWidth: DsLayout.wideMax,
              top: DsSpace.lg,
              bottom: DsSpace.huge + DsSpace.xxxl,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, row) {
                    final List<Widget> cells = [];
                    for (int j = 0; j < columns; j++) {
                      final int index = row * columns + j;
                      if (j > 0) cells.add(const DsGap(DsSpace.md));
                      cells.add(Expanded(child: index < controller.productList.length ? _productCard(context, controller, index) : const SizedBox.shrink()));
                    }
                    return DsFadeSlideIn(
                      index: row,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.md),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
                      ),
                    );
                  },
                  childCount: rows,
                ),
              ),
            ),
          ];
        }

        return DsScaffold.collapsing(
          title: "Manage Products".tr,
          subtitle: showList ? "${controller.productList.length} ${'Products'.tr}" : null,
          onRefresh: showList ? controller.getProduct : null,
          actions: [
            canAdd
                ? DsButton.tonal(
                    label: "Add".tr,
                    icon: Icons.add_rounded,
                    size: DsButtonSize.sm,
                    onPressed: () {
                      _onAddProduct(context, controller, isDark);
                    },
                  )
                : const SizedBox(),
          ],
          slivers: slivers,
          floatingActionButton: Obx(() {
            if (controller.selectedProductIds.isEmpty) {
              return const SizedBox.shrink();
            }
            final c = context.dsColors;
            return FloatingActionButton.extended(
              backgroundColor: c.brand,
              foregroundColor: c.onBrand,
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text("${'Assign Tax'.tr} (${controller.selectedProductIds.length})", style: DsTypography.label.copyWith(color: c.onBrand)),
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
            );
          }),
        );
      },
    );
  }

  /// Subscription item-limit check, then the add-product chooser (unchanged logic).
  void _onAddProduct(BuildContext context, ProductListController controller, bool isDark) {
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
  }

  Widget _statusFill(Widget child) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: DsResponsive(
          // Fill the Center, and center the content inside it.
          alignment: Alignment.center,
          padded: true,
          child: DsFadeSlideIn(child: Padding(padding: const EdgeInsets.only(bottom: DsSpace.huge), child: child)),
        ),
      ),
    );
  }

  Widget _productCard(BuildContext context, ProductListController controller, int index) {
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

    // Wholesale tiers badge: the displayed variant's own wholesale price
    // replaces the FIRST tier's price; the tier quantities apply to all variants.
    final product = controller.productList[index];
    final displayedVariant = product.itemAttribute?.variants?.where((element) => element.variantSku == selectedVariants.join('-')).firstOrNull;
    final String? wholesaleBadge = wholesaleTiersBadge(product, variantWholesalePrice: displayedVariant?.variantWholesalePrice);
    final String? fulfilmentBadge = fulfilmentRestrictionLabel(product);
    final bool wholesaleOnly = product.effectiveSaleType == ProductModel.saleTypeWholesale && product.hasWholesaleTier;

    bool isDisplayItemAlert = false;
    if ((Constant.isSubscriptionModelApplied == true || Constant.selectedSection!.adminCommision?.isEnabled == true)) {
      if (controller.vendorModel.value.subscriptionPlan?.itemLimit == '-1') {
        isDisplayItemAlert = false;
      } else {
        isDisplayItemAlert = (index < int.parse(controller.userModel.value.subscriptionPlan?.itemLimit ?? '0') == true) ? false : true;
      }
    }

    return Obx(() {
      final c = context.dsColors;
      final t = context.dsText;
      final bool isPublished = controller.productList[index].publish ?? false;
      final String taxText = Constant.taxScope == "product" && controller.productList[index].taxSetting?.isEmpty != true
          ? controller.getTaxDisplayText(controller.productList[index].taxSetting)
          : '';
      return DsCard.outlined(
        padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.md, DsSpace.sm),
        semanticLabel: controller.productList[index].name.toString(),
        onTap: () {
          Get.to(const AddProductScreen(), arguments: {"productModel": controller.productList[index]})!.then((value) {
            if (value == true) {
              controller.getProduct();
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with a live/hidden indicator.
                Stack(
                  children: [
                    AnimatedOpacity(
                      duration: DsMotion.of(context, DsMotion.base),
                      opacity: isPublished ? 1 : 0.55,
                      child: DsImage(url: controller.productList[index].photo.toString(), width: 96, height: 96, radius: DsRadius.md, errorIcon: Icons.fastfood_outlined),
                    ),
                    PositionedDirectional(
                      top: DsSpace.xs + 2,
                      start: DsSpace.xs + 2,
                      child: AnimatedContainer(
                        duration: DsMotion.of(context, DsMotion.base),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPublished ? c.success : c.textDisabled,
                          border: Border.all(color: c.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(controller.productList[index].name.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSm),
                      const DsGap(DsSpace.xs),
                      double.parse(disPrice) <= 0
                          ? Text(Constant.amountShow(amount: price), style: t.titleSm.withColor(c.brandStrong).tabular)
                          : Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: DsSpace.sm,
                              children: [
                                Text(Constant.amountShow(amount: disPrice), style: t.titleSm.withColor(c.brandStrong).tabular),
                                Text(Constant.amountShow(amount: price), style: t.bodySm.withColor(c.textMuted).strike),
                              ],
                            ),
                      const DsGap(DsSpace.xs),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, size: 18, color: c.warning),
                          const DsGap(DsSpace.xs),
                          Flexible(
                            child: Text(
                              "${Constant.calculateReview(reviewCount: controller.productList[index].reviewsCount!.toStringAsFixed(0), reviewSum: controller.productList[index].reviewsSum.toString())} (${controller.productList[index].reviewsCount!.toStringAsFixed(0)})",
                              style: t.labelSm.withColor(c.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const DsGap(DsSpace.xs),
                      Constant.taxScope == "product"
                          ? controller.productList[index].taxSetting?.isEmpty == true
                                ? Text(controller.productList[index].description.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption)
                                : taxText == ''
                                ? Text(controller.productList[index].description.toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.caption)
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.receipt_long_outlined, size: 14, color: c.brandStrong)),
                                      const DsGap(DsSpace.xs),
                                      Expanded(
                                        child: Text(
                                          "${'Tax:'.tr} $taxText",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.labelSm.withColor(c.brandStrong),
                                        ),
                                      ),
                                    ],
                                  )
                          : Text(controller.productList[index].description.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
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
                    : const SizedBox(),
              ],
            ),
            if (wholesaleBadge != null || fulfilmentBadge != null) ...[
              const DsGap(DsSpace.md),
              Wrap(
                spacing: DsSpace.sm,
                runSpacing: DsSpace.sm,
                children: [
                  if (wholesaleBadge != null)
                    _WholesaleTag(text: wholesaleOnly ? "${"Wholesale only".tr} · $wholesaleBadge" : wholesaleBadge, strong: wholesaleOnly),
                  if (fulfilmentBadge != null)
                    DsBadge(
                      label: fulfilmentBadge,
                      tone: DsTone.info,
                      icon: product.effectiveFulfilment.contains(ProductModel.fulfilmentDelivery) ? Icons.delivery_dining_outlined : Icons.storefront_outlined,
                    ),
                ],
              ),
            ],
            if (isDisplayItemAlert) ...[
              const DsGap(DsSpace.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                decoration: BoxDecoration(color: c.dangerSoft, borderRadius: DsRadius.brSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.visibility_off_outlined, size: 16, color: c.dangerStrong),
                    const DsGap(DsSpace.sm),
                    Expanded(
                      child: Text(
                        "This product will not be displayed to customers due to your current subscription limitations.".tr,
                        style: t.caption.withColor(c.dangerStrong),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const DsGap(DsSpace.sm),
            Divider(height: 1, color: c.divider),
            const DsGap(DsSpace.xs),
            Row(
              children: [
                DsButton.ghost(
                  label: "Delete".tr,
                  icon: Icons.delete_outline_rounded,
                  size: DsButtonSize.sm,
                  color: c.dangerStrong,
                  onPressed: () async {
                    ShowToastDialog.showLoader("Please wait..".tr);
                    await FireStoreUtils.deleteProduct(controller.productList[index]).then((value) {
                      controller.getProduct();
                      ShowToastDialog.closeLoader();
                    });
                  },
                ),
                const Spacer(),
                Flexible(
                  child: Text("Publish".tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.withColor(isPublished ? c.textPrimary : c.textSecondary)),
                ),
                const DsGap(DsSpace.xs),
                Switch.adaptive(
                  value: controller.productList[index].publish ?? false,
                  onChanged: (value) async {
                    controller.updateList(index, controller.productList[index].publish!);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  void showAddProductBottomSheet(BuildContext context, ProductListController controller, bool isDarkMode) {
    showModalBottomSheet(
      backgroundColor: context.dsColors.surfaceRaised,
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
      builder: (_) => AddProductBottomSheet(controller: controller),
    );
  }
}

/// Wholesale tier summary tag (brand tinted, wraps to two lines).
class _WholesaleTag extends StatelessWidget {
  final String text;
  final bool strong;

  const _WholesaleTag({required this.text, required this.strong});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm + 2, vertical: DsSpace.xs),
      decoration: BoxDecoration(
        color: c.brandSoft,
        borderRadius: DsRadius.brPill,
        border: strong ? Border.all(color: c.brandMuted) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 14, color: c.brandStrong),
          const DsGap(DsSpace.xs),
          Flexible(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: DsTypography.labelSm.copyWith(color: c.brandStrong)),
          ),
        ],
      ),
    );
  }
}

/// Catalogue health: total / published / hidden with a "live" progress bar.
class _CatalogueSummary extends StatelessWidget {
  final ProductListController controller;

  const _CatalogueSummary({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final int total = controller.productList.length;
    final int published = controller.productList.where((p) => p.publish == true).length;
    final int hidden = total - published;
    Widget metric(String label, int value, Color color) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsAnimatedCounter(value: value, style: DsTypography.metric.copyWith(color: color, fontSize: 24)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.caption.copyWith(color: c.textSecondary)),
          ],
        ),
      );
    }

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                metric('Products'.tr, total, c.textPrimary),
                const DsDivider(vertical: true, spacing: DsSpace.md),
                metric('Published'.tr, published, c.successStrong),
                const DsDivider(vertical: true, spacing: DsSpace.md),
                metric('Hidden'.tr, hidden, c.textMuted),
              ],
            ),
          ),
          const DsGap(DsSpace.lg),
          DsProgressBar(value: total == 0 ? 0 : published / total, tone: DsTone.success, label: 'Live in store'.tr, showPercent: true, height: 6),
        ],
      ),
    );
  }
}

class MultiProductTaxBottomSheet extends StatelessWidget {
  final List<ProductModel> products;

  MultiProductTaxBottomSheet({super.key, required this.products});

  final ProductListController controller = Get.find();

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
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: DsSpace.sm),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
                ),

                /// HEADER
                Row(
                  children: [
                    const DsIconWell(icon: Icons.receipt_long_rounded, size: 40),
                    const DsGap(DsSpace.md),
                    Expanded(child: Text("${'Assign Tax to'.tr} ${products.length} ${'Products'.tr}", style: t.title)),
                    DsIconButton(icon: Icons.close_rounded, semanticLabel: 'Close'.tr, onPressed: () => Get.back()),
                  ],
                ),
                const DsGap(DsSpace.sm),
                Divider(color: c.divider),

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
                          title: Text("${tax.title} (${tax.type == "fix" ? Constant.amountShow(amount: tax.tax) : "${tax.tax}%"})", style: t.bodyStrong),
                        );
                      },
                    ),
                  ),
                ),
                const DsGap(DsSpace.md),

                /// APPLY BUTTON
                DsButton.primary(
                  label: "Apply Tax",
                  icon: Icons.check_rounded,
                  expand: true,
                  onPressed: () async {
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
          ),
        ),
      ),
    );
  }
}

class AddProductBottomSheet extends StatelessWidget {
  final ProductListController controller;

  const AddProductBottomSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.sm, DsSpace.xl, DsSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
              ),
            ),

            const DsGap(DsSpace.xl),
            Text("Add Product".tr, style: t.title),
            const DsGap(DsSpace.lg),

            /// Create New Product
            DsFadeSlideIn(
              index: 0,
              child: _optionTile(
                context: context,
                icon: Icons.add_box_rounded,
                tone: DsTone.brand,
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
            ),

            const DsGap(DsSpace.md),

            /// Import From Admin
            DsFadeSlideIn(
              index: 1,
              child: _optionTile(
                context: context,
                icon: Icons.cloud_download_rounded,
                tone: DsTone.info,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required BuildContext context,
    required IconData icon,
    required DsTone tone,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final c = context.dsColors;
    final t = context.dsText;
    return DsCard.outlined(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Row(
        children: [
          DsIconWell(icon: icon, tone: tone, size: 48),
          const DsGap(DsSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.tr, style: t.titleSm),
                const DsGap(DsSpace.xxs),
                Text(subtitle.tr, style: t.bodySm),
              ],
            ),
          ),
          const DsGap(DsSpace.sm),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}
