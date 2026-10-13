import 'package:customer/utils/platform_fee_charge.dart';
import 'package:customer/service/parcel_receiver_sms.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:customer/models/vendor_model.dart';
import 'package:customer/utils/address_format.dart';
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

  /// `settings/ParcelPricing` (only `commissionAsExtra` is still read), read
  /// when the customer asks for a price ([bookNow]).
  ParcelPricingSettings pricingSettings = const ParcelPricingSettings();

  /// `regions/{R}.parcelPricing` of the primary region R (the platform
  /// option), read when the customer asks for a price ([bookNow]). Unset
  /// until then / when the admin has not saved the region: no divisor,
  /// charges 0, fixed charges 0.
  RegionParcelPricing regionPricing = const RegionParcelPricing();

  /// `regions/{id}.parcelPricing` of every candidate region
  /// ([originRegionCandidates]): a carrier is priced in the first candidate
  /// it serves.
  Map<String, RegionParcelPricing> candidateRegionPricing = const {};

  static num? _dimension(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.'));

  num? get lengthCm => _dimension(lengthController.value);
  num? get widthCm => _dimension(widthController.value);
  num? get heightCm => _dimension(heightController.value);

  /// Some, but not all three, of the dimensions are filled in.
  bool get hasPartialDimensions {
    final List<String> sides = [lengthController.value.text, widthController.value.text, heightController.value.text].map((e) => e.trim()).toList();
    return sides.any((e) => e.isNotEmpty) && sides.any((e) => e.isEmpty);
  }

  /// The parcel's PHYSICAL weight: the entered kg, else (same city) the upper
  /// limit of the selected weight band (its `maxKg`, else the number in its
  /// title; the open top band: its `minKg`).
  double get actualWeightKg {
    final double? kg = weightKg;
    if (kg != null && kg > 0) return kg;
    if (!isCityScope) return 0;
    final ParcelWeightModel? w = selectedWeight;
    return w?.maxKg ?? ParcelPricing.categoryMaxKg(w?.title) ?? w?.minKg ?? 0;
  }

  /// `parcel_weight` as pricing bands (`delivery_charge` is a string there).
  List<ParcelBand<ParcelWeightModel>> get weightBands => parcelWeight.map(_band).toList();

  static ParcelBand<ParcelWeightModel> _band(ParcelWeightModel w) =>
      ParcelBand<ParcelWeightModel>(source: w, title: w.title, minKg: w.minKg, maxKg: w.maxKg, charge: parcelNumber(w.deliveryCharge) ?? 0);

  /// The band the no-carrier (default) price of the last [carrierOptions] used.
  ParcelWeightModel? chargedWeight;

  double get chargedWeightCharge => parcelNumber(chargedWeight?.deliveryCharge) ?? 0;

  /// The order's candidate regions, in order of preference
  /// ([ParcelPricing.orderRegionCandidates]): every existing region of the
  /// zones around the sender, else the sender's country's regions, else the
  /// customer's. Decides the carriers offered, their prices and currency.
  List<String> get originRegionCandidates => ParcelPricing.orderRegionCandidates(
        senderZones: RegionService.zoneRegionListsAt(senderLocation.value?.latitude, senderLocation.value?.longitude),
        allZones: RegionService.publishedZoneRegionLists,
        // A zone may still list a deleted region; with no region data at all
        // (not loaded / none configured) nothing is dropped.
        exists: RegionService.hasRegions ? (id) => RegionService.regionById(id) != null : null,
        countryRegions: RegionService.regionIdsForCountry(senderCountryCode.value),
        customerRegion: RegionService.customerRegionId,
      );

  /// The primary region R (first candidate): the platform option's prices and
  /// currency, the pickup points. A carrier option carries its own region
  /// ([ParcelCarrierOption.regionId]).
  String? get originRegionId {
    final List<String> candidates = originRegionCandidates;
    return candidates.isEmpty ? null : candidates.first;
  }

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
      if (placemarks.isEmpty) return;
      final place = placemarks.first;
      // Placemark fields are nullable: interpolating one that the geocoder did
      // not return printed the four characters "null" into the sender address
      // (report #17). Same fields, same order, through formatAddressLine.
      final address = formatAddressLine([place.name, place.subLocality, place.locality, place.administrativeArea, place.postalCode, place.country]);

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
    } else if (ParcelReceiverSms.validationError(countryCode: receiverCountryCodeController.value.text, mobile: receiverMobileController.value.text) != null) {
      // The receiver's number must carry a usable country code: it is stored
      // apart (`receiverCountryCode`) and is what the receiver SMS dials.
      ShowToastDialog.showToast(ParcelReceiverSms.validationError(countryCode: receiverCountryCodeController.value.text, mobile: receiverMobileController.value.text)!.tr);
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
    } else if (hasPartialDimensions) {
      // The volumetric weight needs all three sides: a half-filled size would
      // silently price on the weight alone.
      ShowToastDialog.showToast("Please enter the length, width and height, or leave all three empty".tr);
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
    // A point picked before the address changed may belong to another region:
    // only published points of the order's region are offered (spec 3.5).
    bool outOfRegion(PickupPointModel? p, String? regionId) => p != null && (regionId ?? '').isNotEmpty && !p.offeredIn(regionId!);
    if (pickupMethod.value == ParcelShipping.pickupPoint && (originPickupPoint.value == null || outOfRegion(originPickupPoint.value, originRegionId))) {
      ShowToastDialog.showToast("Please choose the drop-off pickup point".tr);
      return false;
    }
    if (deliveryMethod.value == ParcelShipping.pickupPoint && (destinationPickupPoint.value == null || outOfRegion(destinationPickupPoint.value, destinationRegionId ?? originRegionId))) {
      ShowToastDialog.showToast("Please choose the collection pickup point".tr);
      return false;
    }
    return true;
  }

  Future<void> bookNow() async {
    if (!validateFields()) return;

    ShowToastDialog.showLoader("Please wait...".tr);
    try {
      // R and its currency need the regions / zones / currencies loaded (the
      // parcel screens can be opened before anything else read them).
      await RegionService.ensureLoaded();
      distance.value = 0.0;
      pricingSettings = await ParcelShippingService.pricingSettings();
      final List<String> candidates = originRegionCandidates;
      final List<RegionParcelPricing> pricings = await Future.wait(candidates.map(ParcelShippingService.regionParcelPricing));
      candidateRegionPricing = {for (int i = 0; i < candidates.length; i++) candidates[i]: pricings[i]};
      regionPricing = candidates.isEmpty ? const RegionParcelPricing() : candidateRegionPricing[candidates.first]!;
      chargedWeight = null;

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

      final List<ParcelCarrierOption> options = await carrierOptions();
      subTotal.value = isCityScope ? (distance.value * chargedWeightCharge) : 0;
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

  /// Offers for this shipment (app-spec-parcel-pricing section 6). Same city:
  /// the platform's drivers at the default setting (distance x the band of the
  /// chargeable weight) first, then the eligible carriers on their rate card.
  /// Other scopes: the eligible carriers. Empty = not served (quote request).
  /// Every amount is in the currency of the option's region
  /// ([ParcelCarrierOption.regionId]): the primary region R for the platform,
  /// the first candidate region a carrier serves for that carrier.
  Future<List<ParcelCarrierOption>> carrierOptions() async {
    final ParcelPricingSettings settings = pricingSettings;
    final RegionParcelPricing region = regionPricing;
    final List<String> candidates = originRegionCandidates;
    final String? regionId = candidates.isEmpty ? null : candidates.first;
    final List<DeliveryCarrierModel> carriers = await ParcelShippingService.carriers();

    // Carriers' per-km prices are per km, whatever the app's distance unit.
    final double km = Constant.distanceType.toLowerCase() == "km" ? distance.value : distance.value * 1.60934;
    final List<ParcelCarrierOption> options = [];

    if (isCityScope) {
      final ParcelWeightModel? selected = selectedWeight;
      final ParcelQuote? quote = ParcelPricing.defaultQuote<ParcelWeightModel>(
        scope: scope.value,
        // Today's same-city price: the distance in the app's unit x the band.
        distance: distance.value,
        actualKg: actualWeightKg,
        lengthCm: lengthCm,
        widthCm: widthCm,
        heightCm: heightCm,
        pickupMethod: pickupMethod.value,
        deliveryMethod: deliveryMethod.value,
        bands: weightBands,
        selected: selected == null ? null : _band(selected),
        region: region,
      );
      if (quote != null) {
        chargedWeight = ParcelPricing.bandFor<ParcelWeightModel>(weightBands, quote.chargeableKg ?? 0, selected: selected == null ? null : _band(selected))?.source;
        options.add(ParcelCarrierOption(carrier: null, quote: quote, regionId: regionId));
      }
    }

    final commission = Constant.sectionConstantModel?.adminCommision;
    final List<ParcelCarrierOption> carrierOffers = ParcelCarrierOption.carrierOffers(
      carriers: carriers,
      candidates: candidates,
      regionPricing: candidateRegionPricing,
      scope: scope.value,
      distanceKm: km,
      actualKg: actualWeightKg,
      lengthCm: lengthCm,
      widthCm: widthCm,
      heightCm: heightCm,
      pickupMethod: pickupMethod.value,
      deliveryMethod: deliveryMethod.value,
      adjust: settings.commissionAsExtra && commission?.isEnabled == true
          ? (quote) => quote.copyWith(
              commission: ParcelPricing.commissionOn(amount: quote.carrierPrice + quote.extraKgCharge, type: commission?.commissionType, value: double.tryParse(commission?.amount?.toString() ?? '')),
            )
          : null,
    );
    options.addAll(carrierOffers);
    return options;
  }

  /// Builds the order for [option] (quoteRequest = route not served) and opens checkout.
  void goToCart({ParcelCarrierOption? option, bool quoteRequest = false}) {
    DateTime senderPickup = isScheduled.value ? parseScheduledDateTime(scheduledDate.value, scheduledTime.value) : DateTime.now();

    // The fixed charge (intercity / intercountry) and the door / pickup-point
    // options are added to the payable total at checkout, on top of subTotal
    // (the base price): VAT, % coupons, commission and the driver's credit
    // never apply to them (app-spec-parcel-pricing step 6).
    final double scopeTax = quoteRequest ? 0.0 : (option?.quote.fixedTax ?? 0.0);
    final String? orderRegionId = option?.regionId ?? originRegionId;
    ParcelOrderModel order = ParcelOrderModel(
      id: Constant.getUuid(),
      subTotal: (quoteRequest ? 0.0 : (option != null ? option.quote.subTotal : subTotal.value)).toString(),
      parcelType: selectedCategory?.title ?? '',
      parcelCategoryID: selectedCategory?.id ?? '',
      note: senderNoteController.value.text,
      receiverNote: receiverNoteController.value.text,
      distance: distance.value.toStringAsFixed(4),
      // Same city: the category actually charged (moved up when the weight or
      // the dimensions exceed the one picked - doc point 42).
      parcelWeight: isCityScope && option?.carrier == null && chargedWeight != null ? (chargedWeight?.title ?? '') : '${_kg(weightKg ?? actualWeightKg)} kg',
      parcelWeightCharge: isCityScope && option?.carrier == null ? chargedWeight?.deliveryCharge : null,
      // For carrier company orders, do NOT dispatch directly to drivers.
      // The order is received by the Company Owner first, who assigns it.
      sendToDriver: option?.carrier != null ? false : (isScheduled.value == true ? false : true),
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
      // As charged: nothing while the admin has the fee disabled.
      platformFee: PlatformFeeCharge.current().feeField,
      platformTax: PlatformFeeCharge.current().taxes,
    );

    // The receiver as flat fields (app-spec-parcel-sms.md), next to the
    // `receiver` map: the national number and the dialling code apart, so the
    // SMS trigger and an edit screen never have to parse "(+237) 6...".
    order
      ..receiverName = receiverNameController.value.text.trim()
      ..receiverPhone = ParcelReceiverSms.nationalNumber(receiverMobileController.value.text, countryCode: receiverCountryCodeController.value.text)
      ..receiverCountryCode = ParcelReceiverSms.dialCode(receiverCountryCodeController.value.text);

    // Shipping fields (tracking number / QR / pickup code are generated when
    // the order is placed).
    final num? l = lengthCm, w = widthCm, h = heightCm;
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
      ..carrierOwnerId = option?.carrier?.ownerId
      ..quoteRequested = quoteRequest ? true : null
      // The option's own region (a carrier: the region it is priced in).
      ..regionId = orderRegionId;
    if (quoteRequest) {
      order.status = ParcelShipping.quoteRequestedStatus;
      order.sendToDriver = false;
    } else if (option != null) {
      // app-spec-parcel-pricing section 7. `total` and `smsCharge` are
      // completed at checkout (what the customer actually pays).
      order.priceBreakdown = option.quote.breakdown(currency: RegionService.currencyForRecord(orderRegionId)?.code ?? '');
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
