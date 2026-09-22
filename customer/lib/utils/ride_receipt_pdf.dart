import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_order_details_controller.dart';
import 'package:customer/controllers/rental_order_details_controller.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/models/rental_order_model.dart';
import 'package:customer/models/user_model.dart';
import 'package:customer/utils/order_receipt_pdf.dart';
import 'package:customer/utils/region_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Receipt data of cab rides (city and intercity) and car rentals (spec 7.6).
/// Rendered, shared and downloaded by [OrderReceiptPdf] (same layout, logo,
/// Code 128 barcode). Amounts are the ones the details controllers compute
/// for the screen, in the booking's OWN region currency.
class RideReceiptPdf {
  RideReceiptPdf._();

  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy hh:mm aa');

  /// Cab ride or intercity ride (`rides`).
  static Future<ReceiptData> fromCabOrder(CabOrderDetailsController c) async {
    await RegionService.ensureLoaded();
    final CabOrderModel order = c.cabOrder.value;
    final bool intercity = order.rideType == 'intercity';
    final UserModel? driver = order.driver ?? (c.driverUser.value.id != null ? c.driverUser.value : null);
    final double platformFee = double.tryParse(order.platformFee ?? '') ?? 0;

    final List<MapEntry<String, String>> route = [
      MapEntry('Pickup'.tr, order.sourceLocationName ?? '-'),
      for (final (int i, Map<String, dynamic> stop) in order.orderedStops.indexed) MapEntry('${'Stop'.tr} ${i + 1}', stop['address']?.toString() ?? ''),
      MapEntry('Destination'.tr, order.destinationLocationName ?? '-'),
      if ((order.distance ?? '').isNotEmpty) MapEntry('Distance'.tr, '${(double.tryParse(order.distance!) ?? 0).toStringAsFixed(2)} ${'KM'.tr}'),
      if ((order.duration ?? '').isNotEmpty) MapEntry('Duration'.tr, order.duration!),
      if (order.roundTrip == true) MapEntry('Round trip'.tr, 'Yes'.tr),
      if (order.scheduleReturnDateTime != null && order.roundTrip == true) MapEntry('Return'.tr, _dateFormat.format(order.scheduleReturnDateTime!.toDate())),
      if (order.hasPassengers) MapEntry('Passengers'.tr, "${order.adults} ${'adults'.tr}, ${order.children} ${'children'.tr}"),
      if (order.isForSomeoneElse) MapEntry('Rider'.tr, [order.riderName, order.riderPhone].whereType<String>().join(' - ')),
    ];

    return ReceiptData(
      orderId: order.id ?? '',
      orderLabel: '${intercity ? 'Intercity ride'.tr : 'Ride'.tr} ${Constant.orderId(orderId: order.id.toString())}',
      date: (order.scheduleDateTime ?? order.createdAt)?.toDate(),
      partyTitle: 'Service'.tr,
      partyName: 'spideli'.tr.capitalizeFirst ?? 'Spideli',
      partyAddress: intercity ? 'Intercity ride'.tr : 'Cab ride'.tr,
      partyPhone: '',
      logoUrl: null,
      customerName: order.author?.fullName() ?? '',
      customerPhone: '${order.author?.countryCode ?? ''} ${order.author?.phoneNumber ?? ''}'.trim(),
      customerAddress: '',
      details: [
        if (order.vehicleType?.name?.isNotEmpty == true) MapEntry('Vehicle type'.tr, order.vehicleType!.name!),
        MapEntry('Status'.tr, (order.status ?? '').tr),
        MapEntry('Payment method'.tr, OrderReceiptPdf.paymentLabel(order.paymentMethod)),
      ],
      blocks: [_driverBlock(driver, order.sectionId), ReceiptBlock('Route'.tr, route)],
      items: const [],
      totals: [
        ReceiptTotal('Subtotal'.tr, c.subTotal.value),
        if (c.discount.value > 0) ReceiptTotal('Discount'.tr, -c.discount.value),
        if (platformFee > 0) ReceiptTotal('Platform fee'.tr, platformFee),
        if (c.orderTaxAmount.value > 0) ReceiptTotal('Tax on Order Total'.tr, c.orderTaxAmount.value),
        if (c.platformTaxAmount.value > 0) ReceiptTotal('Tax on Platform Fee'.tr, c.platformTaxAmount.value),
      ],
      totalPaid: c.totalAmount.value,
      currency: RegionService.currencyForRecord(order.regionId),
    );
  }

  /// Car rental booking (`rental_orders`).
  static Future<ReceiptData> fromRentalOrder(RentalOrderDetailsController c) async {
    await RegionService.ensureLoaded();
    final RentalOrderModel order = c.order.value;
    final UserModel? driver = order.driver ?? c.driverUser.value;
    final double platformFee = double.tryParse(order.platformFee ?? '') ?? 0;
    final double extras = c.extraKilometerCharge.value + c.extraMinutesCharge.value;
    final package = order.rentalPackageModel;

    final List<MapEntry<String, String>> rental = [
      MapEntry('Pickup'.tr, order.sourceLocationName ?? '-'),
      if (order.bookingDateTime != null) MapEntry('Booking date'.tr, _dateFormat.format(order.bookingDateTime!.toDate())),
      if (order.startTime != null) MapEntry('Start'.tr, _dateFormat.format(order.startTime!.toDate())),
      if (order.endTime != null) MapEntry('End'.tr, _dateFormat.format(order.endTime!.toDate())),
      if (order.rentalVehicleType?.name?.isNotEmpty == true) MapEntry('Vehicle type'.tr, order.rentalVehicleType!.name!),
      if (package != null) MapEntry('Rental Package'.tr, (package.name ?? '').tr),
      if (package?.includedHours?.isNotEmpty == true) MapEntry('Including Hours'.tr, '${package!.includedHours} ${'Hr'.tr}'),
      if (package?.includedDistance?.isNotEmpty == true) MapEntry('${'Including'.tr} ${Constant.distanceType.tr}', '${package!.includedDistance} ${Constant.distanceType}'),
      if (order.startKitoMetersReading != null && order.endKitoMetersReading != null) MapEntry('${'Extra'.tr} ${Constant.distanceType}', c.getExtraKm()),
    ];

    return ReceiptData(
      orderId: order.id ?? '',
      orderLabel: '${'Rental'.tr} ${Constant.orderId(orderId: order.id.toString())}',
      date: order.createdAt?.toDate() ?? order.bookingDateTime?.toDate(),
      partyTitle: 'Service'.tr,
      partyName: 'spideli'.tr.capitalizeFirst ?? 'Spideli',
      partyAddress: 'Car rental'.tr,
      partyPhone: '',
      logoUrl: null,
      customerName: order.author?.fullName() ?? '',
      customerPhone: '${order.author?.countryCode ?? ''} ${order.author?.phoneNumber ?? ''}'.trim(),
      customerAddress: '',
      details: [MapEntry('Status'.tr, (order.status ?? '').tr), MapEntry('Payment method'.tr, OrderReceiptPdf.paymentLabel(order.paymentMethod))],
      blocks: [_driverBlock(driver, order.sectionId), ReceiptBlock('Rental Details'.tr, rental)],
      items: const [],
      totals: [
        // The controller's subtotal already includes the extra km / minutes.
        if (extras > 0) ReceiptTotal('Rental price'.tr, c.subTotal.value - extras),
        if (c.extraKilometerCharge.value > 0) ReceiptTotal('Extra distance charge'.tr, c.extraKilometerCharge.value),
        if (c.extraMinutesCharge.value > 0) ReceiptTotal('Extra minutes charge'.tr, c.extraMinutesCharge.value),
        ReceiptTotal('Subtotal'.tr, c.subTotal.value),
        if (c.discount.value > 0) ReceiptTotal('Discount'.tr, -c.discount.value),
        if (platformFee > 0) ReceiptTotal('Platform fee'.tr, platformFee),
        if (c.orderTaxAmount.value > 0) ReceiptTotal('Tax on Order Total'.tr, c.orderTaxAmount.value),
        if (c.platformTaxAmount.value > 0) ReceiptTotal('Tax on Platform Fee'.tr, c.platformTaxAmount.value),
      ],
      totalPaid: c.totalAmount.value,
      currency: c.bookingCurrency,
    );
  }

  /// Driver name, phone and vehicle (from `vehicleDetails[sectionId]`).
  static ReceiptBlock _driverBlock(UserModel? driver, String? sectionId) {
    if (driver == null || driver.fullName().trim().isEmpty) return ReceiptBlock('Driver'.tr, const []);
    final dynamic vehicle = driver.vehicleDetails?[sectionId ?? ''];
    String field(String key) => vehicle is Map ? (vehicle[key]?.toString() ?? '').trim() : '';
    final String car = '${field('carBrand')} ${field('carModel')}'.trim();
    final String phone = '${driver.countryCode ?? ''} ${driver.phoneNumber ?? ''}'.trim();
    return ReceiptBlock('Driver'.tr, [
      MapEntry('Name'.tr, driver.fullName()),
      if (phone.isNotEmpty) MapEntry('Phone'.tr, phone),
      if (car.isNotEmpty) MapEntry('Vehicle'.tr, car),
      if (field('carPlateNumber').isNotEmpty) MapEntry('Plate number'.tr, field('carPlateNumber').toUpperCase()),
    ]);
  }
}
