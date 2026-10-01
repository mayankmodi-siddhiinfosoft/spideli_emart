import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/models/order_model.dart';
import 'package:driver/models/user_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class HomeScreenMultipleOrderController extends GetxController {
  /// `Constant.userModel!` threw in the field initialiser — i.e. before
  /// `onInit`, so GetX could not even construct this controller — whenever the
  /// global had not been populated yet (cold start straight onto the
  /// dashboard). The live user document arrives from [getDriver] anyway.
  Rx<UserModel> driverModel = (Constant.userModel ?? UserModel()).obs;
  RxBool isLoading = true.obs;
  RxInt selectedTabIndex = 0.obs;

  RxList<dynamic> newOrder = [].obs;
  RxList<dynamic> activeOrder = [].obs;

  @override
  void onInit() {
    // TODO: implement onInt
    getDriver();
    super.onInit();
  }

  Future<void> getDriver() async {
    FireStoreUtils.fireStore.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).snapshots().listen(
      (event) async {
        if (event.exists) {
          driverModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = driverModel.value;
          newOrder.clear();
          activeOrder.clear();
          if (driverModel.value.orderRequestData != null) {
            for (var element in driverModel.value.orderRequestData!) {
              newOrder.add(element);
            }
          }

          if (driverModel.value.inProgressOrderID != null) {
            for (var element in driverModel.value.inProgressOrderID!) {
              activeOrder.add(element);
            }
          }

          if (newOrder.isEmpty == true) {
            await AudioPlayerService.playSound(false);
          }

          if (newOrder.isNotEmpty) {
            if (driverModel.value.vendorID?.isEmpty == true) {
              await AudioPlayerService.playSound(true);
            }
          }
        }
      },
    );
    isLoading.value = false;
    update();
  }

  Future<void> acceptOrder(OrderModel currentOrder) async {
    await AudioPlayerService.playSound(false);
    ShowToastDialog.showLoader("Please wait".tr);
    // Same as the single-order screen: these arrays can be absent on a
    // driver's user document, and the `!` made Accept fail silently.
    driverModel.value.inProgressOrderID ??= [];
    driverModel.value.orderRequestData ??= [];
    driverModel.value.orderRequestData!.remove(currentOrder.id);
    if (!driverModel.value.inProgressOrderID!.contains(currentOrder.id)) {
      driverModel.value.inProgressOrderID!.add(currentOrder.id);
    }

    await FireStoreUtils.updateUser(driverModel.value);

    currentOrder.status = Constant.driverAccepted;
    currentOrder.driverID = driverModel.value.id;
    currentOrder.driver = driverModel.value;

    await FireStoreUtils.setOrder(currentOrder);
    ShowToastDialog.closeLoader();
    await SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, currentOrder.author?.fcmToken ?? '', {});
    await SendNotification.sendFcmMessage(Constant.driverAcceptedNotification, currentOrder.vendor?.fcmToken ?? '', {});
  }

  Future<void> rejectOrder(OrderModel currentOrder) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await AudioPlayerService.playSound(false);
    currentOrder.rejectedByDrivers ??= [];
    currentOrder.rejectedByDrivers!.add(driverModel.value.id);
    currentOrder.status = Constant.driverRejected;
    await FireStoreUtils.setOrder(currentOrder);
    driverModel.value.orderRequestData ??= [];
    driverModel.value.orderRequestData!.remove(currentOrder.id);
    await FireStoreUtils.updateUser(driverModel.value);
    ShowToastDialog.closeLoader();
  }
}
