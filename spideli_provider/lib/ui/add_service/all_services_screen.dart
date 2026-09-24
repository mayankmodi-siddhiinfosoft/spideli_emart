import 'package:cached_network_image/cached_network_image.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/all_services_controller.dart';
import 'package:spideliprovider/controller/dashboard_controller.dart';
import 'package:spideliprovider/main.dart';
import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/add_service/add_or_update_service.dart';
import 'package:spideliprovider/ui/dashboard/dashboard_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Service catalogue (archetype E): image-led cards with the artwork as the
/// hero, the price as a floating pill and the category path underneath. One
/// column on phones, an adaptive grid from tablets up. Drawer tab of the
/// dashboard – it already had a Scaffold, so it keeps exactly one.
class AllServiceScreen extends StatelessWidget {
  const AllServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX<AllServicesController>(
        global: false,
        init: AllServicesController(),
        builder: (controller) {
          // Read the observables here, in the tracked builder, and pass the
          // values down to the lazily-built children.
          final bool isLoading = controller.isLoading.value;
          final List<ProviderServiceModel> services = controller.providerList.toList();
          final l = context.dsLayout;
          return DsScaffold(
            maxContentWidth: DsLayout.wideMax,
            body: RefreshIndicator(
              onRefresh: () async {
                controller.getData();
              },
              child: DsAsync(
                isLoading: isLoading,
                skeleton: const DsSkeletonGrid(minItemWidth: 280, imageAspectRatio: 1.7),
                isEmpty: services.isEmpty,
                empty: DsEmptyState(
                  icon: Icons.handyman_outlined,
                  title: 'Service is not available.'.tr,
                  message: 'Add a service so customers can book you.'.tr,
                ),
                builder: (_) => _ServiceGrid(services: services, controller: controller, gutter: l.gutter),
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
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
              icon: const Icon(Icons.add_rounded),
              label: Text('Add Service'.tr),
            ),
          );
        });
  }

  static void showAlertDialog(ProviderServiceModel providerModel, BuildContext context, controller) {
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DsDialog(
          title: providerModel.title!,
          message: 'Are you sure you want to delete this service?'.tr,
          icon: Icons.delete_outline_rounded,
          tone: DsTone.danger,
          destructive: true,
          primaryLabel: "Ok".tr,
          onPrimary: () async {
            ShowToastDialog.showLoader("Please wait".tr);

            FireStoreUtils.deleteProduct(providerModel.id!).then((value) async {
              ShowToastDialog.closeLoader();
              controller.getData();
              DashBoardController dashBoardController = Get.put(DashBoardController());
              dashBoardController.onSelectItem(1);
              await Get.to(const DashBoardScreen());
            });
          },
          secondaryLabel: "Cancel".tr,
          onSecondary: () {
            Get.back();
          },
        );
      },
    );
  }
}

/// One scrolling column on phones, an adaptive grid of the same card on
/// tablets / iPad. Both grow with the text scale, so nothing clips.
class _ServiceGrid extends StatelessWidget {
  final List<ProviderServiceModel> services;
  final AllServicesController controller;
  final double gutter;

  const _ServiceGrid({required this.services, required this.controller, required this.gutter});

  @override
  Widget build(BuildContext context) {
    return DsResponsiveBuilder(
      builder: (context, l) {
        final padding = EdgeInsets.fromLTRB(gutter, DsSpace.md, gutter, DsSpace.huge + DsSpace.xxl);
        if (!l.isWide) {
          return ListView.builder(
            padding: padding,
            itemCount: services.length,
            itemBuilder: (context, index) {
              return DsFadeSlideIn(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: DsSpace.lg),
                  child: _ServiceCard(model: services[index], index: index, controller: controller, imageHeight: 176),
                ),
              );
            },
          );
        }
        return SingleChildScrollView(
          padding: padding,
          physics: const AlwaysScrollableScrollPhysics(),
          child: DsAdaptiveGrid(
            minItemWidth: 280,
            spacing: DsSpace.lg,
            runSpacing: DsSpace.lg,
            maxColumns: 4,
            children: [
              for (int index = 0; index < services.length; index++)
                DsFadeSlideIn(
                  index: index,
                  child: _ServiceCard(model: services[index], index: index, controller: controller, imageHeight: 150),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ProviderServiceModel model;
  final int index;
  final AllServicesController controller;
  final double imageHeight;

  const _ServiceCard({required this.model, required this.index, required this.controller, required this.imageHeight});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;

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

    final bool hasDiscount = !(model.disPrice == "" || model.disPrice == "0");
    final String priceText = model.priceUnit == 'Fixed' ? amountShow(amount: hasDiscount ? model.disPrice : model.price) : '${amountShow(amount: hasDiscount ? model.disPrice : model.price)}/hr';
    final String oldPriceText = model.priceUnit == 'Fixed' ? amountShow(amount: model.price) : '${amountShow(amount: model.price)}/hr';
    final String rating = model.reviewsCount != 0 ? (model.reviewsSum! / model.reviewsCount!).toStringAsFixed(1) : 0.toString();

    return DsCard(
      padding: EdgeInsets.zero,
      radius: DsRadius.lg,
      semanticLabel: model.title,
      onTap: () async {
        Get.to(const AddOrUpdateServiceScreen(), arguments: {
          "providerModel": model,
        })?.then((value) {
          if (value != null) {
            controller.getData();
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              _ServiceImage(url: model.photos.isNotEmpty ? model.photos.first.toString() : '', height: imageHeight),
              // Bottom scrim so the rating stays readable on light photos.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(gradient: DsGradients.imageScrim),
                  ),
                ),
              ),
              PositionedDirectional(
                top: DsSpace.sm,
                end: DsSpace.sm,
                child: DsIconButton(
                  icon: Icons.delete_outline_rounded,
                  semanticLabel: 'Delete'.tr,
                  variant: DsIconButtonVariant.filled,
                  color: c.danger,
                  size: 36,
                  onPressed: () {
                    AllServiceScreen.showAlertDialog(model, context, controller);
                  },
                ),
              ),
              PositionedDirectional(
                bottom: DsSpace.sm,
                start: DsSpace.md,
                child: DsBadge(
                  label: rating,
                  icon: Icons.star_rounded,
                  tone: DsTone.success,
                  style: DsBadgeStyle.solid,
                ),
              ),
              if (isDisplayItemAlert)
                PositionedDirectional(
                  bottom: DsSpace.sm,
                  end: DsSpace.md,
                  child: Tooltip(
                    message: "This service will not be displayed to customers due to your current subscription limitations.".tr,
                    child: DsBadge(
                      label: "Hidden by plan".tr,
                      icon: Icons.visibility_off_outlined,
                      tone: DsTone.danger,
                      style: DsBadgeStyle.solid,
                      small: true,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSm,
                ),
                const DsGap(DsSpace.xs),
                _CategoryPath(model: model),
                const DsGap(DsSpace.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        priceText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSm.withColor(c.brandStrong).tabular,
                      ),
                    ),
                    if (hasDiscount) ...[
                      const DsGap(DsSpace.sm),
                      Flexible(
                        child: Text(
                          oldPriceText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.tabular.strike,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Category / Sub category" – keeps the screen's two existing lookups.
class _CategoryPath extends StatelessWidget {
  final ProviderServiceModel model;

  const _CategoryPath({required this.model});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    Widget name(Future<dynamic> future) => FutureBuilder(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return DsShimmer(child: DsSkeleton.line(width: 56));
            } else {
              if (snapshot.hasError) {
                return Text('Error: ' + '${snapshot.error}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.withColor(c.dangerStrong));
              } else {
                return Text(
                  snapshot.data != null ? snapshot.data!.title.toString() : "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySm,
                );
              }
            }
          },
        );
    return Row(
      children: [
        Icon(Icons.category_outlined, size: 14, color: c.textMuted),
        const DsGap(DsSpace.xs),
        Flexible(child: name(FireStoreUtils.getCategoryById(model.categoryId.toString()))),
        Text(" / ", style: t.bodySm),
        Flexible(child: name(FireStoreUtils.getCategoryById(model.subCategoryId.toString()))),
      ],
    );
  }
}

/// Service artwork with the app's placeholder asset as loading / error state.
class _ServiceImage extends StatelessWidget {
  final String url;
  final double height;

  const _ServiceImage({required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Image.asset(
          'assets/images/placeholder.png',
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        );
    if (url.isEmpty) {
      return SizedBox(height: height, width: double.infinity, child: placeholder());
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        fadeInDuration: DsMotion.of(context, DsMotion.base),
        placeholder: (context, url) => placeholder(),
        errorWidget: (context, url, error) => placeholder(),
      ),
    );
  }
}
