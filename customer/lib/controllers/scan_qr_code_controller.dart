import 'package:customer/constant/constant.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:customer/screen_ui/multi_vendor_service/restaurant_details_screen/restaurant_details_screen.dart';
import 'package:customer/themes/show_toast_dialog.dart';
import 'package:get/get.dart';

/// The home's "Scan QR Code" button (multivendor and e-commerce). A store's
/// QR code holds its vendor id; the scan opens that store when it is one of
/// the stores the home lists for this service.
class ScanQrCodeController extends GetxController {
  /// The home's own live store list (`arguments: {"vendorList": …}`), else
  /// the list the open home published in [Constant.restaurantList]. Never a
  /// new query: the shared nearest-vendor stream would stop feeding the home.
  late final List<VendorModel> stores;

  bool _handled = false;

  @override
  void onInit() {
    final args = Get.arguments;
    final passed = args is Map ? args['vendorList'] : null;
    stores = passed is List<VendorModel> ? passed : (Constant.restaurantList ?? const <VendorModel>[]);
    super.onInit();
  }

  /// Opens the scanned store in place of the scanner, once: the live
  /// scanner reports the same code on several frames.
  void open(String code) {
    if (_handled) return;
    _handled = true;
    final VendorModel? store = storeFor(stores, code);
    if (store == null) {
      Get.back();
      ShowToastDialog.showToast("Store is not available".tr);
      return;
    }
    Get.off(const RestaurantDetailsScreen(), arguments: {"vendorModel": store});
  }

  /// The listed store whose vendor id the scanned [code] holds, or null.
  static VendorModel? storeFor(List<VendorModel> stores, String code) {
    final String id = code.trim();
    if (id.isEmpty) return null;
    return stores.firstWhereOrNull((vendor) => vendor.id == id);
  }
}
