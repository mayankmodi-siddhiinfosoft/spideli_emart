import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vendor/constant/collection_name.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/models/order_model.dart';
import 'package:vendor/models/user_model.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/service/audio_player_service.dart';
import 'package:vendor/utils/fire_store_utils.dart';

class HomeController extends GetxController {
  RxBool isLoading = true.obs;

  Rx<TextEditingController> estimatedTimeController = TextEditingController().obs;
  Rx<TextEditingController> courierCompanyName = TextEditingController().obs;
  Rx<TextEditingController> courierCompanyTrackingId = TextEditingController().obs;

  RxInt selectedTabIndex = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getUserProfile();
    super.onInit();
  }

  RxList<OrderModel> allOrderList = <OrderModel>[].obs;
  RxList<OrderModel> newOrderList = <OrderModel>[].obs;
  RxList<OrderModel> acceptedOrderList = <OrderModel>[].obs;
  RxList<OrderModel> completedOrderList = <OrderModel>[].obs;
  RxList<OrderModel> rejectedOrderList = <OrderModel>[].obs;
  RxList<OrderModel> cancelledOrderList = <OrderModel>[].obs;

  Rx<UserModel> userModel = UserModel().obs;
  Rx<VendorModel> vendermodel = VendorModel().obs;

  Future<void> getUserProfile() async {
    await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid()).then((value) async {
      if (value != null) {
        userModel.value = value;
        Constant.userModel = userModel.value;
        if (userModel.value.employeePermissionId != null) {
          Constant.employeeRoleModel = await FireStoreUtils.getEmployeeRoleById(userModel.value.employeePermissionId!);
        }
      }
    });
    if (userModel.value.vendorID != null && userModel.value.vendorID!.isNotEmpty) {
      await FireStoreUtils.getVendorById(userModel.value.vendorID!).then((vender) {
        if (vender?.id != null) {
          vendermodel.value = vender!;
        }
      });
    }
    await getOrder();

    isLoading.value = false;
  }

  RxList<UserModel> driverUserList = <UserModel>[].obs;
  Rx<UserModel> selectDriverUser = UserModel().obs;

  Future<void> getAllDriverList() async {
    await FireStoreUtils.getAvalibleDrivers().then((value) {
      if (value.isNotEmpty == true) {
        driverUserList.value = value;
      }
    });
    isLoading.value = false;
  }

  Future<void> getOrder() async {
    FireStoreUtils.fireStore.collection(CollectionName.vendorOrders).where('vendorID', isEqualTo: Constant.userModel!.vendorID).orderBy('createdAt', descending: true).snapshots().listen((
      event,
    ) async {
      allOrderList.clear();
      for (var element in event.docs) {
        OrderModel orderModel = OrderModel.fromJson(element.data());
        allOrderList.add(orderModel);
        newOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderPlaced).toList();
        acceptedOrderList.value = allOrderList
            .where(
              (p0) =>
                  p0.status == Constant.orderAccepted ||
                  p0.status == Constant.driverPending ||
                  p0.status == Constant.driverRejected ||
                  p0.status == Constant.orderShipped ||
                  p0.status == Constant.orderInTransit,
            )
            .toList();
        completedOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderCompleted).toList();
        rejectedOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderRejected).toList();
        cancelledOrderList.value = allOrderList.where((p0) => p0.status == Constant.orderCancelled).toList();
      }
      update();
      if (newOrderList.isNotEmpty == true) {
        await AudioPlayerService.playSound(true);
      }
      if (newOrderList.isEmpty == true) {
        await AudioPlayerService.playSound(false);
      }
    });
  }
}
