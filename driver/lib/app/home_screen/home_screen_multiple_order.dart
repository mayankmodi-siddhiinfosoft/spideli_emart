import 'package:driver/utils/region_service.dart';
import 'package:driver/utils/address_format.dart';
import 'package:driver/app/home_screen/home_screen.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controllers/dash_board_controller.dart';
import 'package:driver/controllers/home_screen_multiple_order_controller.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/services/assigned_delivery_orders.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/themes/theme_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

/// Archetype B + J — the multi-order queue. "New" is a stack of full
/// [DsRequestCard]s (fare, route, metrics, xl Reject / Accept); "Active" is a
/// compact route list that opens the live map screen.
class HomeScreenMultipleOrder extends StatelessWidget {
  const HomeScreenMultipleOrder({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    // Kept as the observable read that rebuilds this screen on a theme change;
    // colors now come from `context.dsColors`.
    themeController.isDark.value;

    return GetX(
        init: HomeScreenMultipleOrderController(),
        builder: (controller) {
          final bool isLoading = controller.isLoading.value;
          final bool isFreelanceDriver = controller.driverModel.value.vendorID?.isEmpty == true;
          // tryParse: `double.parse` threw in build on a missing balance or an
          // empty setting, and the whole screen (both tabs) was an error.
          final bool walletTooLow = Constant.userModel?.vendorID?.isEmpty == true &&
              (double.tryParse('${controller.driverModel.value.walletAmount ?? 0}') ?? 0) < (double.tryParse(Constant.minimumDepositToRideAccept) ?? 0);
          final String? uid = controller.driverModel.value.id;
          final Map<String, OrderModel> orders = Map<String, OrderModel>.from(controller.orders);
          final bool ordersLoaded = controller.ordersLoaded.value;
          final List<dynamic> newOrders = controller.newOrder.toList();
          // Only what the driver can still act on: a finished, cancelled or
          // reassigned id left in `inProgressOrderID` is not an active order.
          final List<dynamic> activeOrders = controller.activeOrder.where((id) {
            final OrderModel? order = orders[id.toString()];
            if (order == null) return !ordersLoaded;
            return AssignedDeliveryOrders.isWorkableFor(order, uid) ||
                (AssignedDeliveryOrders.isOfferFor(order, uid) && AssignedDeliveryOrders.isNamedFor(order, uid));
          }).toList();
          // The verification gate is about receiving offers; it never hides an
          // order that is already assigned to this driver.
          final bool documentsPending = activeOrders.isEmpty &&
              Constant.userModel?.vendorID?.isEmpty == true &&
              Constant.userModel?.isDocumentVerify == false &&
              controller.driverModel.value.isAutoVerify == false;
          final bool hasNewTab = Constant.userModel?.vendorID?.isEmpty == true;

          return DsScaffold(
            body: isLoading
                ? const DsSkeletonList(itemCount: 3, leading: false, trailing: false)
                : documentsPending
                    ? _documentsPendingView(context)
                    : Column(
                        children: [
                          if (walletTooLow)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, 0),
                              child: DsInlineAlert(
                                tone: DsTone.warning,
                                icon: Icons.account_balance_wallet_outlined,
                                message:
                                    "You must have a minimum ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} in your wallet to receive orders",
                              ),
                            ),
                          Expanded(
                            child: DefaultTabController(
                              length: hasNewTab ? 2 : 1,
                              // An assigned order with no new request waiting
                              // opens on "Active" — on "New" it read as "no
                              // order", and nothing on that tab can be acted on.
                              initialIndex: hasNewTab && newOrders.isEmpty && activeOrders.isNotEmpty ? 1 : 0,
                              child: Column(
                                children: [
                                  DsTabBar(
                                    onTap: (value) {
                                      controller.selectedTabIndex.value = value;
                                    },
                                    tabs: [
                                      if (hasNewTab) newOrders.isEmpty ? "New".tr : "${"New".tr} (${newOrders.length})",
                                      activeOrders.isEmpty ? "Active".tr : "${"Active".tr} (${activeOrders.length})",
                                    ],
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      children: hasNewTab
                                          ? [
                                              _newOrderTab(context, controller, newOrders, isFreelanceDriver),
                                              _activeOrderTab(context, controller, activeOrders, isFreelanceDriver),
                                            ]
                                          : [
                                              _activeOrderTab(context, controller, activeOrders, isFreelanceDriver),
                                            ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
          );
        });
  }

  Widget _documentsPendingView(BuildContext context) {
    return Center(
      child: DsEmptyState(
        icon: Icons.assignment_outlined,
        tone: DsTone.warning,
        title: "document_verification_pending".tr,
        message: "document_review_notification".tr,
        actionLabel: "view_status".tr,
        actionIcon: Icons.arrow_forward_rounded,
        onAction: () async {
          DashBoardController dashBoardController = Get.put(DashBoardController());
          dashBoardController.drawerIndex.value = 4;
        },
      ),
    );
  }

  Widget _newOrderTab(BuildContext context, HomeScreenMultipleOrderController controller, List<dynamic> orderIds, bool isFreelanceDriver) {
    if (orderIds.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: Icons.notifications_none_rounded,
          title: "New Order not found.".tr,
          message: "New delivery requests will show up here.".tr,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      itemCount: orderIds.length,
      itemBuilder: (BuildContext context, int index) {
        return DsFadeSlideIn(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            child: _orderFuture(
              context: context,
              controller: controller,
              orderId: orderIds[index],
              // The whole card opened the live map screen before; Accept /
              // Reject still win the tap when pressed directly.
              builder: (orderModel, kilometer) => DsPressable(
                pressedScale: 0.99,
                haptic: false,
                onTap: () {
                  Get.to(
                      const HomeScreen(
                        isAppBarShow: true,
                      ),
                      arguments: {"orderModel": orderModel});
                },
                child: DsRequestCard(
                  title: "New Order".tr,
                  subtitle: Constant.orderId(orderId: orderModel.id.toString()),
                  section: DsSection.delivery,
                  sectionLabel: Constant.sectionNameFromId(orderModel.sectionId),
                  fare: isFreelanceDriver
                      ? Constant.amountShow(currency: RegionService.currencyForRecord(orderModel.regionId), amount: orderModel.deliveryCharge)
                      : null,
                  fareCaption: isFreelanceDriver ? "Delivery Charge".tr : null,
                  stops: _stopsFor(orderModel),
                  metrics: _metricsFor(orderModel, kilometer),
                  onReject: () {
                    controller.rejectOrder(orderModel);
                  },
                  onAccept: () {
                    controller.acceptOrder(orderModel);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _activeOrderTab(BuildContext context, HomeScreenMultipleOrderController controller, List<dynamic> orderIds, bool isFreelanceDriver) {
    if (orderIds.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: Icons.local_shipping_outlined,
          title: "Active order not found.".tr,
          message: "Orders you accepted will appear here.".tr,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
      itemCount: orderIds.length,
      itemBuilder: (context, index) {
        return DsFadeSlideIn(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: DsSpace.md),
            child: _orderFuture(
              context: context,
              controller: controller,
              orderId: orderIds[index],
              builder: (orderModel, kilometer) => _activeOrderCard(context, orderModel, kilometer, isFreelanceDriver),
            ),
          ),
        );
      },
    );
  }

  /// One order from the controller's live map, with the zone / region rule
  /// applied exactly as before. No per-build read any more (see
  /// [HomeScreenMultipleOrderController.orders]).
  Widget _orderFuture({
    required BuildContext context,
    required HomeScreenMultipleOrderController controller,
    required dynamic orderId,
    required Widget Function(OrderModel orderModel, double kilometer) builder,
  }) {
    final OrderModel? orderModel = controller.orders[orderId.toString()];
    if (orderModel == null) {
      return controller.ordersLoaded.value ? const SizedBox() : const DsSkeletonCard(height: 180);
    }
    if (orderModel.status == Constant.driverPending &&
        orderModel.id != null &&
        controller.driverModel.value.id != null &&
        !AssignedDeliveryOrders.isNamedFor(orderModel, controller.driverModel.value.id) &&
        RegionService.isOutOfDriverRegion(orderModel.regionId, driver: controller.driverModel.value)) {
      // Zone-bound (spec 9.1): not offered; declined so dispatch moves on.
      FireStoreUtils.declineOutOfRegionVendorOrder(orderModel.id!, controller.driverModel.value.id!);
      return const SizedBox();
    }
    // `vendor!` / `address!.location!` threw here for a record without them,
    // and the card (with its buttons) became an error box.
    final double distanceInMeters = Geolocator.distanceBetween(orderModel.vendor?.latitude ?? 0.0, orderModel.vendor?.longitude ?? 0.0,
        orderModel.address?.location?.latitude ?? 0.0, orderModel.address?.location?.longitude ?? 0.0);
    return builder(orderModel, distanceInMeters / 1000);
  }

  Widget _activeOrderCard(BuildContext context, OrderModel orderModel, double kilometer, bool isFreelanceDriver) {
    final t = context.dsText;
    return DsCard.outlined(
      padding: const EdgeInsets.all(DsSpace.lg),
      semanticLabel: Constant.orderId(orderId: orderModel.id.toString()),
      onTap: () {
        Get.to(
            const HomeScreen(
              isAppBarShow: true,
            ),
            arguments: {"orderModel": orderModel});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Constant.orderId(orderId: orderModel.id.toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSm.w700.tabular,
                ),
              ),
              const DsGap(DsSpace.sm),
              DsStatusChip(label: orderModel.status.toString().tr, status: orderModel.status, pulse: true),
            ],
          ),
          const DsGap(DsSpace.lg),
          DsRouteStops(stops: _stopsFor(orderModel)),
          const DsGap(DsSpace.md),
          DsTripMetrics(items: _metricsFor(orderModel, kilometer, isFreelanceDriver: isFreelanceDriver)),
        ],
      ),
    );
  }

  List<DsRouteStop> _stopsFor(OrderModel orderModel) {
    return [
      DsRouteStop(
        kind: DsStopKind.pickup,
        label: orderModel.vendor?.title ?? '',
        address: AddressFormat.clean(orderModel.vendor?.location),
      ),
      DsRouteStop(
        kind: DsStopKind.drop,
        label: "Deliver to the".tr,
        address: orderModel.address?.getFullAddress() ?? '',
      ),
    ];
  }

  List<DsTripMetric> _metricsFor(OrderModel orderModel, double kilometer, {bool isFreelanceDriver = false}) {
    final String tip = orderModel.tipAmount ?? '';
    final bool hasTip = (double.tryParse(tip) ?? 0) > 0;
    return [
      DsTripMetric(
        icon: Icons.route_rounded,
        value: "${double.parse(kilometer.toString()).toStringAsFixed(2)} ${Constant.distanceType}",
        label: "Trip Distance".tr,
      ),
      if (isFreelanceDriver)
        DsTripMetric(
          icon: Icons.delivery_dining_rounded,
          value: Constant.amountShow(currency: RegionService.currencyForRecord(orderModel.regionId), amount: orderModel.deliveryCharge),
          label: "Delivery Charge".tr,
        ),
      if (hasTip)
        DsTripMetric(
          icon: Icons.volunteer_activism_outlined,
          value: Constant.amountShow(currency: RegionService.currencyForRecord(orderModel.regionId), amount: orderModel.tipAmount),
          label: "Tips".tr,
        ),
    ];
  }
}
