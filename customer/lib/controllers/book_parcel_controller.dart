import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/models/vendor_model.dart';
import 'package:customer/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:dropdown_textfield/dropdown_textfield.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as latlong;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../constant/constant.dart';
import '../models/parcel_category.dart';
import '../models/parcel_order_model.dart';
import '../models/parcel_shipping_models.dart';
import '../models/parcel_weight_model.dart';
import '../models/user_model.dart';
import '../screen_ui/parcel_service/parcel_carrier_selection_screen.dart';
import '../screen_ui/parcel_service/parcel_order_confirmation.dart';
import '../service/fire_store_utils.dart';
import '../service/parcel_shipping_service.dart';
import '../themes/show_toast_dialog.dart';
import '../utils/parcel_pricing.dart';
import '../utils/region_service.dart';

class BookParcelController extends GetxController {
  // Sender details
  final Rx<TextEditingController> senderLocationController = TextEditingController().obs;
  final Rx<TextEditingController> senderNameController = TextEditingController().obs;
  final Rx<TextEditingController> senderMobileController = TextEditingController().obs;
  final Rx<SingleValueDropDownController> senderWeightController = SingleValueDropDownController().obs;
  final Rx<TextEditingController> senderNoteController = TextEditingController().obs;
  final Rx<TextEditingController> senderCountryCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;
  final Rx<TextEditingController> senderCountryISOCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;

  // Receiver details
  final Rx<TextEditingController> receiverLocationController = TextEditingController().obs;
  final Rx<TextEditingController> receiverNameController = TextEditingController().obs;
  final Rx<TextEditingController> receiverMobileController = TextEditingController().obs;
  final Rx<TextEditingController> receiverNoteController = TextEditingController().obs;
  final Rx<TextEditingController> receiverCountryCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;
  final Rx<TextEditingController> receiverISOCountryCodeController = TextEditingController(text: Constant.defaultCountryCode).obs;

  // Delivery type
  final RxString selectedDeliveryType = 'now'.obs;

  // ---- Shipping (PARCEL-CONTRACT): type & scope, route, parcel details, methods.
  final RxString shipmentType = ParcelShipping.parcel.obs;
  final RxString scope = ParcelScope.city.obs;
  final Rx<TextEditingController> senderEmailController = TextEditingController().obs;
  final Rx<TextEditingController> receiverEmailController = TextEditingController().obs;
  final Rx<TextEditingController> senderCityController = TextEditingController().obs;
  final Rx<TextEditingController> receiverCityController = TextEditingController().obs;
  final RxString senderCountry = ''.obs;
  final RxString senderCountryCode = ''.obs;
  final RxString receiverCountry = ''.obs;
  final RxString receiverCountryCode = ''.obs;
  final Rx<TextEditingController> weightKgController = TextEditingController().obs;
  final Rx<TextEditingController> lengthController = TextEditingController().obs;
  final Rx<TextEditingController> widthController = TextEditingController().obs;
  final Rx<TextEditingController> heightController = TextEditingController().obs;
  final Rx<TextEditingController> declaredValueController = TextEditingController().obs;
  final Rx<TextEditingController> contentDescriptionController = TextEditingController().obs;
  final RxString pickupMethod = ParcelShipping.home.obs;
  final RxString deliveryMethod = ParcelShipping.home.obs;
  final Rx<PickupPointModel?> originPickupPoint = Rx<PickupPointModel?>(null);
  final Rx<PickupPointModel?> destinationPickupPoint = Rx<PickupPointModel?>(null);

  bool get isCityScope => scope.value == ParcelScope.city;

  /// Today's flow: same city, home pickup and home delivery.
  bool get isLegacyShape => isCityScope && pickupMethod.value == ParcelShipping.home && deliveryMethod.value == ParcelShipping.home;

  double? get weightKg => double.tryParse(weightKgController.value.text.trim().replaceAll(',', '.'));

  /// Weight carriers are priced / filtered on: the entered kg, else (same
  /// city) the upper limit of the selected weight category.
  double get offerWeightKg {
    final double? kg = weightKg;
    if (kg != null && kg > 0) return kg;
    if (isCityScope) return ParcelPricing.categoryMaxKg(selectedWeight?.title) ?? 0;
    return 0;
  }

  String? get originRegionId => RegionService.regionAt(senderLocation.value?.latitude, senderLocation.value?.longitude);

  String? get destinationRegionId => RegionService.regionAt(receiverLocation.value?.latitude, receiverLocation.value?.longitude);

  ParcelPlace get originPlace => ParcelPlace(city: senderCityController.value.text.trim(), country: senderCountry.value, countryCode: senderCountryCode.value);

  ParcelPlace get destinationPlace => ParcelPlace(city: receiverCityController.value.text.trim(), country: receiverCountry.value, countryCode: receiverCountryCode.value);

  /// Fills city / country of a party from the picked coordinates (editable).
  Future<void> fillPlace({required bool sender, required double latitude, required double longitude}) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return;
      final place = placemarks.first;
      final String city = (place.locality ?? '').isNotEmpty ? place.locality! : (place.subAdministrativeArea ?? '');
      if (sender) {
        if (city.isNotEmpty) senderCityController.value.text = city;
        senderCountry.value = place.country ?? senderCountry.value;
        senderCountryCode.value = place.isoCountryCode ?? senderCountryCode.value;
      } else {
        if (city.isNotEmpty) receiverCityController.value.text = city;
        receiverCountry.value = place.country ?? receiverCountry.value;
        receiverCountryCode.value = place.isoCountryCode ?? receiverCountryCode.value;
      }
    } catch (e) {
      debugPrint('fillPlace failed: $e');
    }
  }

  // Scheduled delivery fields
  final Rx<TextEditingController> scheduledDateController = TextEditingController().obs;
  final Rx<TextEditingController> scheduledTimeController = TextEditingController().obs;
  final RxString scheduledDate = ''.obs;
  final RxString scheduledTime = ''.obs;

  // Parcel weight list
  final RxList<ParcelWeightModel> parcelWeight = <ParcelWeightModel>[].obs;

  final RxList<XFile> images = <XFile>[].obs;
  final ImagePicker _picker = ImagePicker();

  Rx<UserLocation?> senderLocation = Rx<UserLocation?>(null);
  Rx<UserLocation?> receiverLocation = Rx<UserLocation?>(null);

  ParcelWeightModel? selectedWeight;
  ParcelCategory? selectedCategory;

  // UI observables
  RxBool isScheduled = false.obs;
  RxDouble distance = 0.0.obs;
  RxDouble duration = 0.0.obs;
  RxDouble subTotal = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    setArguments();
    getParcelWeight();
    setCurrentLocationForSenderAndReceiver();
  }

  void setArguments() {
    if (Get.arguments != null && Get.arguments['parcelCategory'] != null) {
      selectedCategory = Get.arguments['parcelCategory'];
    }
  }

  Future<void> getParcelWeight() async {
    parcelWeight.value = await FireStoreUtils.getParcelWeight();
  }

  Future<void> pickScheduledDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) {
      final formattedDate = "${picked.day}/${picked.month}/${picked.year}";
      scheduledDate.value = formattedDate;
      scheduledDateController.value.text = formattedDate;
    }
  }

  Future<void> pickScheduledTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      final formattedTime = picked.format(context);
      scheduledTime.value = formattedTime;
      scheduledTimeController.value.text = formattedTime;
    }
  }

  void onCameraClick(BuildContext context) {
    final action = CupertinoActionSheet(
      message: Text('Add your parcel image.'.tr, style: const TextStyle(fontSize: 15.0)),
      actions: <Widget>[
        CupertinoActionSheetAction(
          child: Text('Choose image from gallery'.tr),
          onPressed: () async {
            Navigator.pop(context);
            final imageList = await _picker.pickMultiImage();
            if (imageList.isNotEmpty) {
              images.addAll(imageList);
            }
          },
        ),
        CupertinoActionSheetAction(
          child: Text('Take a picture'.tr),
          onPressed: () async {
            Navigator.pop(context);
            final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
            if (photo != null) {
              images.add(photo);
            }
          },
        ),
      ],
      cancelButton: CupertinoActionSheetAction(child: Text('Cancel'.tr), onPressed: () => Navigator.pop(context)),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  Future<void> setCurrentLocationForSenderAndReceiver() async {
    try {
      await Geolocator.requestPermission();
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await Geocoding().placemarkFromCoordinates(position.latitude, position.longitude);
      final place = placemarks.first;
      final address = "${place.name}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.postalCode}, ${place.country}";

      final userLocation = UserLocation(latitude: position.latitude, longitude: position.longitude);
      senderLocation.value = userLocation;
      senderLocationController.value.text = address;
      senderCityController.value.text = place.locality ?? '';
      senderCountry.value = place.country ?? '';
      senderCountryCode.value = place.isoCountryCode ?? '';
    } catch (e) {
      debugPrint("Failed to fetch current location: $e");
    }
  }

  bool validateFields() {
    if (senderNameController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter sender name".tr);
      return false;
    } else if (senderMobileController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter sender mobile".tr);
      return false;
    } else if (senderLocationController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter sender address".tr);
      return false;
    } else if (receiverNameController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter receiver name".tr);
      return false;
    } else if (receiverMobileController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter receiver mobile".tr);
      return false;
    } else if (receiverLocationController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter receiver address".tr);
      return false;
    } else if (isScheduled.value) {
      if (scheduledDate.value.isEmpty) {
        ShowToastDialog.showToast("Please select scheduled date".tr);
        return false;
      } else if (scheduledTime.value.isEmpty) {
        ShowToastDialog.showToast("Please select scheduled time".tr);
        return false;
      }
    }

    if (isCityScope && selectedWeight == null) {
      ShowToastDialog.showToast("Please select parcel weight".tr);
      return false;
    } else if (senderLocation.value == null || receiverLocation.value == null) {
      ShowToastDialog.showToast("Please select both sender and receiver locations".tr);
      return false;
    } else if (isCityScope && Constant.checkZoneCheck(receiverLocation.value!.latitude ?? 0.0, receiverLocation.value!.longitude ?? 0.0) != true) {
      // Picked under another scope (outside the zones by design), then switched to Same city.
      ShowToastDialog.showToast("Service is unavailable at the selected address.".tr);
      return false;
    }
    final String wText = weightKgController.value.text.trim();
    if (!isCityScope && (weightKg == null || weightKg! <= 0)) {
      ShowToastDialog.showToast("Please enter the parcel weight in kg".tr);
      return false;
    } else if (wText.isNotEmpty && (weightKg == null || weightKg! <= 0)) {
      ShowToastDialog.showToast("Please enter a valid weight in kg".tr);
      return false;
    }
    for (final email in [senderEmailController.value.text.trim(), receiverEmailController.value.text.trim()]) {
      if (email.isNotEmpty && !GetUtils.isEmail(email)) {
        ShowToastDialog.showToast("Please enter a valid email".tr);
        return false;
      }
    }
    if (!isCityScope) {
      if (originPlace.city.isEmpty || destinationPlace.city.isEmpty) {
        ShowToastDialog.showToast("Please enter the sender and receiver cities".tr);
        return false;
      }
      if (originPlace.countryCode.isEmpty || destinationPlace.countryCode.isEmpty) {
        ShowToastDialog.showToast("Please select the sender and receiver countries".tr);
        return false;
      }
      final bool sameCountry = originPlace.countryCode.toUpperCase() == destinationPlace.countryCode.toUpperCase();
      if (scope.value == ParcelScope.intercity && originPlace.cityMatches(destinationPlace.city)) {
        ShowToastDialog.showToast("Sender and receiver are in the same city: choose Same city".tr);
        return false;
      }
      if (scope.value == ParcelScope.intercity && !sameCountry) {
        ShowToastDialog.showToast("Receiver is in another country: choose Other country".tr);
        return false;
      }
      if (scope.value == ParcelScope.intercountry && sameCountry) {
        ShowToastDialog.showToast("Receiver is in the same country: choose Other city".tr);
        return false;
      }
    }
    if (pickupMethod.value == ParcelShipping.pickupPoint && originPickupPoint.value == null) {
      ShowToastDialog.showToast("Please choose the drop-off pickup point".tr);
      return false;
    }
    if (deliveryMethod.value == ParcelShipping.pickupPoint && destinationPickupPoint.value == null) {
      ShowToastDialog.showToast("Please choose the collection pickup point".tr);
      return false;
    }
    return true;
  }

  Future<void> bookNow() async {
    if (!validateFields()) return;

    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      distance.value = 0.0;

      if (isCityScope) {
        if (Constant.selectedMapType == 'osm') {
          await fetchRouteWithWaypoints([
            latlong.LatLng(senderLocation.value?.latitude ?? 0.0, senderLocation.value?.longitude ?? 0.0),
            latlong.LatLng(receiverLocation.value?.latitude ?? 0.0, receiverLocation.value?.longitude ?? 0.0),
          ]);
        } else {
          await fetchGoogleRouteWithWaypoints();
        }
      }
      // Intercity / intercountry (or no route found): straight-line distance,
      // only used by carriers priced on their per-km rate card.
      if (distance.value <= 0 && !isCityScope) {
        final double meters = Geolocator.distanceBetween(
          senderLocation.value!.latitude ?? 0.0,
          senderLocation.value!.longitude ?? 0.0,
          receiverLocation.value!.latitude ?? 0.0,
          receiverLocation.value!.longitude ?? 0.0,
        );
        distance.value = Constant.distanceType.toLowerCase() == "km" ? meters / 1000.0 : meters / 1609.34;
      }

      if (isCityScope && distance.value < 0.5) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Sender's location to receiver's location should be more than 1 km.".tr);
        return;
      }

      subTotal.value = isCityScope ? (distance.value * double.parse(selectedWeight!.deliveryCharge.toString())) : 0;
      final List<ParcelCarrierOption> options = await carrierOptions();
      ShowToastDialog.closeLoader();

      // Same city, home to home and no carrier to choose from: today's flow.
      if (isLegacyShape && options.length == 1 && options.first.carrier == null) {
        goToCart(option: options.first);
        return;
      }
      Get.to(() => const ParcelCarrierSelectionScreen(), arguments: {'controller': this, 'options': options});
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Something went wrong while booking.".tr);
      debugPrint("bookNow error: $e");
    }
  }

  /// Offers for this shipment (spec 4.2 step 5). Same city: the platform's
  /// drivers at today's price first, then eligible carriers. Other scopes:
  /// eligible carriers with a price for the route. Empty = not served.
  Future<List<ParcelCarrierOption>> carrierOptions() async {
    final ParcelPricingSettings settings = await ParcelShippingService.pricingSettings();
    final List<DeliveryCarrierModel> carriers = await ParcelShippingService.carriers();
    final double kg = offerWeightKg;
    final double km = Constant.distanceType.toLowerCase() == "km" ? distance.value : distance.value * 1.60934;
    final List<ParcelCarrierOption> options = [];
    if (isCityScope) {
      options.add(ParcelCarrierOption(carrier: null, quote: ParcelPricing.cityDefault(distance: distance.value, weightCategoryCharge: double.parse(selectedWeight!.deliveryCharge.toString()))));
    }
    final commission = Constant.sectionConstantModel?.adminCommision;
    final List<ParcelCarrierOption> carrierOffers = [];
    for (final carrier in carriers) {
      if (!carrier.isEligible(originRegionId: originRegionId, weightKg: kg)) continue;
      ParcelQuote? quote = ParcelPricing.carrierQuote(
        scope: scope.value,
        table: carrier.rateTable,
        card: carrier.rateCard,
        origin: originPlace,
        destination: destinationPlace,
        weightKg: kg,
        distanceKm: km,
        settings: settings,
      );
      if (quote == null) continue;
      if (settings.commissionAsExtra && commission?.isEnabled == true) {
        quote = quote.copyWith(
          commission: ParcelPricing.commissionOn(amount: quote.carrierPrice + quote.extraKgCharge, type: commission?.commissionType, value: double.tryParse(commission?.amount?.toString() ?? '')),
        );
      }
      carrierOffers.add(ParcelCarrierOption(carrier: carrier, quote: quote));
    }
    carrierOffers.sort((a, b) => a.quote.total.compareTo(b.quote.total));
    options.addAll(carrierOffers);
    return options;
  }

  /// Builds the order for [option] (quoteRequest = route not served) and opens checkout.
  void goToCart({ParcelCarrierOption? option, bool quoteRequest = false}) {
    DateTime senderPickup = isScheduled.value ? parseScheduledDateTime(scheduledDate.value, scheduledTime.value) : DateTime.now();

    // The fixed scope tax (intercity / intercountry) is platform revenue added
    // to the payable total at checkout: keep it out of subTotal so VAT, %
    // coupons, commission and the driver's credit never apply to it.
    final double scopeTax = quoteRequest ? 0.0 : (option?.quote.fixedTax ?? 0.0);
    ParcelOrderModel order = ParcelOrderModel(
      id: Constant.getUuid(),
      subTotal: (quoteRequest ? 0.0 : (option != null ? option.quote.total - scopeTax : subTotal.value)).toString(),
      parcelType: selectedCategory?.title ?? '',
      parcelCategoryID: selectedCategory?.id ?? '',
      note: senderNoteController.value.text,
      receiverNote: receiverNoteController.value.text,
      distance: distance.value.toStringAsFixed(4),
      parcelWeight: isCityScope && selectedWeight != null ? (selectedWeight?.title ?? '') : '${_kg(weightKg ?? 0)} kg',
      parcelWeightCharge: isCityScope ? selectedWeight?.deliveryCharge : null,
      sendToDriver: isScheduled.value == true ? false : true,
      senderPickupDateTime: Timestamp.fromDate(senderPickup),
      receiverPickupDateTime: Timestamp.fromDate(DateTime.now()),

      isSchedule: isScheduled.value,
      sourcePoint: G(
        geopoint: GeoPoint(senderLocation.value!.latitude ?? 0.0, senderLocation.value!.longitude ?? 0.0),
        geohash: Geoflutterfire().point(latitude: senderLocation.value!.latitude ?? 0.0, longitude: senderLocation.value!.longitude ?? 0.0).hash,
      ),
      destinationPoint: G(
        geopoint: GeoPoint(receiverLocation.value!.latitude ?? 0.0, receiverLocation.value!.longitude ?? 0.0),
        geohash: Geoflutterfire().point(latitude: receiverLocation.value!.latitude ?? 0.0, longitude: receiverLocation.value!.longitude ?? 0.0).hash,
      ),
      sender: LocationInformation(
        address: senderLocationController.value.text,
        name: senderNameController.value.text,
        phone: "(${senderCountryCodeController.value.text}) ${senderMobileController.value.text}",
        email: senderEmailController.value.text.trim(),
      ),
      receiver: LocationInformation(
        address: receiverLocationController.value.text,
        name: receiverNameController.value.text,
        phone: "(${receiverCountryCodeController.value.text}) ${receiverMobileController.value.text}",
        email: receiverEmailController.value.text.trim(),
      ),
      receiverLatLong: receiverLocation.value,
      senderLatLong: senderLocation.value,
      sectionId: Constant.sectionConstantModel?.id ?? '',
      taxSetting: Constant.orderProductTaxList,
      platformFee: Constant.platformFeeModel?.fee ?? '0.0',
      platformTax: Constant.platformTaxList,
    );

    // Shipping fields (tracking number / QR / pickup code are generated when
    // the order is placed).
    num? n(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.'));
    final num? l = n(lengthController.value), w = n(widthController.value), h = n(heightController.value);
    order
      ..shipmentType = shipmentType.value
      ..scope = scope.value
      ..origin = originPlace
      ..destination = destinationPlace
      ..pickupMethod = pickupMethod.value
      ..originPickupPointId = pickupMethod.value == ParcelShipping.pickupPoint ? originPickupPoint.value?.id : null
      ..deliveryMethod = deliveryMethod.value
      ..destinationPickupPointId = deliveryMethod.value == ParcelShipping.pickupPoint ? destinationPickupPoint.value?.id : null
      ..declaredValue = declaredValueController.value.text.trim().isEmpty ? null : declaredValueController.value.text.trim()
      ..dimensions = (l != null || w != null || h != null) ? {'l': l ?? 0, 'w': w ?? 0, 'h': h ?? 0} : null
      ..contentDescription = contentDescriptionController.value.text.trim().isEmpty ? null : contentDescriptionController.value.text.trim()
      ..weightKg = weightKg
      ..parcelScopeTax = scopeTax > 0 ? scopeTax : null
      ..carrierId = option?.carrier?.id
      ..carrierName = option?.carrier?.name
      ..quoteRequested = quoteRequest ? true : null
      ..regionId = originRegionId;
    if (quoteRequest) {
      order.status = ParcelShipping.quoteRequestedStatus;
      order.sendToDriver = false;
    } else if (option != null) {
      final q = option.quote;
      order.priceBreakdown = {
        'carrierPrice': q.carrierPrice,
        'extraKgCharge': q.extraKgCharge,
        'fixedTax': q.fixedTax,
        'commission': q.commission,
        'options': q.options,
        'total': q.total,
        'currency': RegionService.currencyForRecord(originRegionId)?.code ?? '',
        'source': q.source,
      };
    }
    // Dispatch geo-points follow where the parcel physically is: a driver
    // collects at the origin pickup point / delivers to the destination one.
    // senderLatLong / receiverLatLong keep the parties' own addresses.
    final PickupPointModel? from = pickupMethod.value == ParcelShipping.pickupPoint ? originPickupPoint.value : null;
    final PickupPointModel? to = deliveryMethod.value == ParcelShipping.pickupPoint ? destinationPickupPoint.value : null;
    if (from != null && from.hasLocation) {
      order.sourcePoint = G(geopoint: GeoPoint(from.latitude!, from.longitude!), geohash: Geoflutterfire().point(latitude: from.latitude!, longitude: from.longitude!).hash);
    }
    if (to != null && to.hasLocation) {
      order.destinationPoint = G(geopoint: GeoPoint(to.latitude!, to.longitude!), geohash: Geoflutterfire().point(latitude: to.latitude!, longitude: to.longitude!).hash);
    }

    debugPrint("Order Distance: ${distance.value}");
    debugPrint("Subtotal: ${subTotal.value}");
    debugPrint("Order JSON: ${order.toJson()}");

    Get.to(() => ParcelOrderConfirmationScreen(), arguments: {'parcelOrder': order, 'images': images});
  }

  static String _kg(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  DateTime parseScheduledDateTime(String dateStr, String timeStr) {
    try {
      final dateParts = dateStr.split('/');
      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final time = TimeOfDay(hour: int.parse(timeStr.split(':')[0]), minute: int.parse(timeStr.split(':')[1].split(' ')[0]));
      final isPM = timeStr.toLowerCase().contains('pm');
      final hour24 = isPM && time.hour < 12 ? time.hour + 12 : time.hour;

      return DateTime(year, month, day, hour24, time.minute);
    } catch (e) {
      debugPrint("Failed to parse scheduled date/time: $e");
      return DateTime.now();
    }
  }

  Future<void> fetchGoogleRouteWithWaypoints() async {
    final origin = '${senderLocation.value!.latitude},${senderLocation.value!.longitude}';
    final destination = '${receiverLocation.value!.latitude},${receiverLocation.value!.longitude}';
    final url = Uri.parse('https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=driving&key=${Constant.mapAPIKey}');

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final route = data['routes'][0];
        final legs = route['legs'] as List;
        num totalDistance = 0;
        num totalDuration = 0;
        for (var leg in legs) {
          totalDistance += leg['distance']['value'];
          totalDuration += leg['duration']['value'];
        }
        if (Constant.distanceType.toLowerCase() == "KM".toLowerCase()) {
          distance.value = totalDistance / 1000.0;
        } else {
          distance.value = totalDistance / 1609.34;
        }
        duration.value = (totalDuration / 60).round().toDouble();
      } else {
        debugPrint('Google Directions API Error: ${data['status']}');
      }
    } catch (e) {
      debugPrint("Google route fetch error: $e");
    }
  }

  Future<void> fetchRouteWithWaypoints(List<latlong.LatLng> points) async {
    final coordinates = points.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final dist = decoded['routes'][0]['distance'];
        final dur = decoded['routes'][0]['duration'];

        if (Constant.distanceType.toLowerCase() == "KM".toLowerCase()) {
          distance.value = dist / 1000.00;
        } else {
          distance.value = dist / 1609.34;
        }
        duration.value = (dur / 60).round().toDouble();
      } else {
        debugPrint("Failed to get route: ${response.body}");
      }
    } catch (e) {
      debugPrint("Route fetch error: $e");
    }
  }
}
