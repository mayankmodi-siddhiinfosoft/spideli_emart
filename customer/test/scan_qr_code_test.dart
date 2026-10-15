import 'package:customer/controllers/scan_qr_code_controller.dart';
import 'package:customer/models/vendor_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The home's "Scan QR Code" button (multivendor and e-commerce): a store's
/// QR code holds its vendor id, matched against the home's own store list.
void main() {
  final List<VendorModel> stores = [VendorModel(id: 'store_a', title: 'A'), VendorModel(id: 'store_b', title: 'B')];

  test('a scanned vendor id opens that store', () {
    expect(ScanQrCodeController.storeFor(stores, 'store_b')?.title, 'B');
  });

  test('surrounding whitespace in the code is ignored', () {
    expect(ScanQrCodeController.storeFor(stores, '  store_a\n')?.title, 'A');
  });

  test('a code that is not a listed store, or empty, matches nothing', () {
    expect(ScanQrCodeController.storeFor(stores, 'store_c'), isNull);
    expect(ScanQrCodeController.storeFor(stores, '   '), isNull);
    expect(ScanQrCodeController.storeFor(const [], 'store_a'), isNull);
  });
}
