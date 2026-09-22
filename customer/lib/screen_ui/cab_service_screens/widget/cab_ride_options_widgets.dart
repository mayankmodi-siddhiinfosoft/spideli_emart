import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_ride_options.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/themes/app_them_data.dart';
import 'package:customer/themes/text_field_widget.dart';
import 'package:customer/utils/utils.dart';
import 'package:customer/widget/osm_map/map_picker_page.dart';
import 'package:customer/widget/osm_map/place_model.dart';
import 'package:customer/widget/place_picker/location_picker_screen.dart';
import 'package:customer/widget/place_picker/selected_location_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A place picked with the app's map picker (OSM or Google, like pickup /
/// destination).
typedef PickedPlace = ({String address, double lat, double lng});

Future<PickedPlace?> pickRidePlace() async {
  if (Constant.selectedMapType == 'osm') {
    final result = await Get.to(() => MapPickerPage());
    if (result is! PlaceModel) return null;
    return (address: result.address.toString(), lat: result.coordinates.latitude, lng: result.coordinates.longitude);
  }
  final value = await Get.to(LocationPickerScreen());
  if (value is! SelectedLocationModel || value.latLng == null) return null;
  return (address: Utils.formatAddress(selectedLocation: value), lat: value.latLng!.latitude, lng: value.latLng!.longitude);
}

Color _text(bool isDark) => isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;

Color _sub(bool isDark) => isDark ? AppThemeData.greyDark500 : AppThemeData.grey500;

Widget _stopBadge(String label, {bool reached = false}) {
  return CircleAvatar(
    radius: 12,
    backgroundColor: reached ? AppThemeData.success400 : AppThemeData.primary300,
    child: reached ? const Icon(Icons.check, size: 14, color: Colors.white) : Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
  );
}

/// Stops A, B, … between pickup and destination: add / remove / reorder
/// (spec 4.8). Every change recalculates the route and so the fare.
class CabStopsEditor extends StatelessWidget {
  final CabRideOptions controller;
  final bool isDark;

  const CabStopsEditor({super.key, required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stops = controller.stops;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < stops.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
                ),
                child: Row(
                  children: [
                    _stopBadge(CabRideOptions.stopLabel(i)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(stops[i].address, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppThemeData.mediumTextStyle(fontSize: 14, color: _text(isDark)))),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: "Move up".tr,
                      onPressed: i == 0 ? null : () => controller.moveStop(i, -1),
                      icon: const Icon(Icons.arrow_upward, size: 18),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: "Move down".tr,
                      onPressed: i == stops.length - 1 ? null : () => controller.moveStop(i, 1),
                      icon: const Icon(Icons.arrow_downward, size: 18),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: "Remove stop".tr,
                      onPressed: () => controller.removeStop(i),
                      icon: Icon(Icons.close, size: 18, color: AppThemeData.danger300),
                    ),
                  ],
                ),
              ),
            ),
          if (stops.length < CabRideOptions.maxStops)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () async {
                final place = await pickRidePlace();
                if (place != null) controller.addStop(place.address, place.lat, place.lng);
              },
              icon: Icon(Icons.add_location_alt_outlined, color: AppThemeData.primary300),
              label: Text(
                stops.isEmpty ? "Add a stop".tr : "${'Add stop'.tr} ${CabRideOptions.stopLabel(stops.length)}",
                style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: AppThemeData.primary300),
              ),
            ),
        ],
      );
    });
  }
}

/// Passengers, instructions, "written communication only" and "ride for
/// someone else" (spec 4.8 / 7.10), entered before booking.
class CabTripOptionsSection extends StatelessWidget {
  final CabRideOptions controller;
  final bool isDark;

  const CabTripOptionsSection({super.key, required this.controller, required this.isDark});

  Widget _counter(String title, int value, VoidCallback? onMinus, VoidCallback onPlus) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppThemeData.semiBoldTextStyle(fontSize: 15, color: _text(isDark)))),
          IconButton.outlined(visualDensity: VisualDensity.compact, onPressed: onMinus, icon: const Icon(Icons.remove, size: 18)),
          SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: AppThemeData.boldTextStyle(fontSize: 16, color: _text(isDark)))),
          IconButton.outlined(visualDensity: VisualDensity.compact, onPressed: onPlus, icon: const Icon(Icons.add, size: 18)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
          border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Trip options".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: _sub(isDark))),
            const SizedBox(height: 6),
            _counter("Adults".tr, controller.adults.value, controller.adults.value > 1 ? controller.decrementAdults : null, controller.incrementAdults),
            _counter("Children".tr, controller.children.value, controller.children.value > 0 ? controller.decrementChildren : null, controller.incrementChildren),
            const SizedBox(height: 8),
            TextFieldWidget(title: "Instructions for the driver".tr, hintText: "e.g. gate code, luggage, where to wait".tr, controller: controller.instructionsController, maxLine: 3),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeTrackColor: AppThemeData.primary300,
              value: controller.writtenCommunicationOnly.value,
              onChanged: (value) => controller.writtenCommunicationOnly.value = value,
              title: Text("I can only communicate in writing".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: _text(isDark))),
              subtitle: Text("The driver will contact you by chat instead of calling".tr, style: AppThemeData.regularTextStyle(fontSize: 12, color: _sub(isDark))),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeTrackColor: AppThemeData.primary300,
              value: controller.rideForSomeoneElse.value,
              onChanged: (value) => controller.rideForSomeoneElse.value = value,
              title: Text("Book this ride for someone else".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: _text(isDark))),
              subtitle: Text("You pay for the ride".tr, style: AppThemeData.regularTextStyle(fontSize: 12, color: _sub(isDark))),
            ),
            if (controller.rideForSomeoneElse.value) ...[
              TextFieldWidget(title: "Rider's name".tr, hintText: "Full name".tr, controller: controller.riderNameController),
              TextFieldWidget(
                title: "Rider's phone number".tr,
                hintText: "Phone number".tr,
                controller: controller.riderPhoneController,
                textInputType: TextInputType.phone,
                prefix: CountryCodePicker(
                  onInit: (value) {
                    if (controller.riderCountryCodeController.text.isEmpty) {
                      controller.riderCountryCodeController.text = value?.dialCode ?? '';
                      controller.riderCountryISOCodeController.text = value?.code ?? '';
                    }
                  },
                  onChanged: (value) {
                    controller.riderCountryCodeController.text = value.dialCode ?? '';
                    controller.riderCountryISOCodeController.text = value.code ?? '';
                  },
                  initialSelection:
                      controller.riderCountryISOCodeController.text.isNotEmpty
                          ? controller.riderCountryISOCodeController.text
                          : (Constant.defaultCountryCode.isNotEmpty ? Constant.defaultCountryCode : null),
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  textStyle: TextStyle(fontSize: 15, color: _text(isDark)),
                  dialogTextStyle: TextStyle(fontSize: 16, color: _text(isDark)),
                  searchStyle: TextStyle(fontSize: 16, color: _text(isDark)),
                  dialogBackgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
                ),
              ),
              TextFieldWidget(title: "Rider's email (optional)".tr, hintText: "Email".tr, controller: controller.riderEmailController, textInputType: TextInputType.emailAddress),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Your driver cancelled — finding another driver": the driver cancelled an
/// accepted ride and it went back to dispatch (not a final cancellation).
class DriverCancelledBanner extends StatelessWidget {
  final CabOrderModel order;

  const DriverCancelledBanner({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    if (!order.isDriverCancelledRedispatch) return const SizedBox.shrink();
    final reason = order.lastDriverRejection?['reason']?.toString().trim() ?? '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppThemeData.warning50, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemeData.warning300)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppThemeData.warning400, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Your driver cancelled — finding another driver".tr, style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: AppThemeData.grey900)),
                if (reason.isNotEmpty) Text(reason, style: AppThemeData.regularTextStyle(fontSize: 12, color: AppThemeData.grey600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only CabCar extras of a ride: stops progress (from `stops[i].reached`),
/// passengers, instructions, written-only, rider and, for history, the
/// cancellation reason. Hidden when the ride has none of them.
class CabRideExtrasView extends StatelessWidget {
  final CabOrderModel order;
  final bool isDark;
  final bool showCancellation;

  const CabRideExtrasView({super.key, required this.order, required this.isDark, this.showCancellation = false});

  bool get _hasCancellation =>
      (order.cancelReason?.isNotEmpty ?? false) && [Constant.orderCancelled, Constant.orderRejected].contains(order.status);

  Widget _section(String title, Widget body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(title, style: AppThemeData.regularTextStyle(fontSize: 13, color: _sub(isDark))), const SizedBox(height: 4), body],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = order.orderedStops;
    final instructions = order.instructions?.trim() ?? '';
    final children = <Widget>[];

    if (stops.isNotEmpty) {
      final reachedCount = stops.where((s) => s['reached'] == true).length;
      children.add(
        _section(
          "${'Stops'.tr} ($reachedCount/${stops.length} ${'reached'.tr})",
          Column(
            children: List.generate(stops.length, (i) {
              final reached = stops[i]['reached'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    _stopBadge(CabRideOptions.stopLabel(i), reached: reached),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stops[i]['address']?.toString() ?? '',
                        style: AppThemeData.mediumTextStyle(fontSize: 14, color: reached ? _sub(isDark) : _text(isDark), decoration: reached ? TextDecoration.lineThrough : null),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      );
    }
    if (order.hasPassengers) {
      children.add(_section("Passengers".tr, Text("${order.adults} ${'adults'.tr}, ${order.children} ${'children'.tr}", style: AppThemeData.semiBoldTextStyle(fontSize: 14, color: _text(isDark)))));
    }
    if (instructions.isNotEmpty) {
      children.add(_section("Instructions".tr, Text(instructions, style: AppThemeData.mediumTextStyle(fontSize: 14, color: _text(isDark)))));
    }
    if (order.writtenCommunicationOnly == true) {
      children.add(_section("Communication".tr, Text("Written communication only".tr, style: AppThemeData.mediumTextStyle(fontSize: 14, color: _text(isDark)))));
    }
    if (order.isForSomeoneElse) {
      children.add(
        _section(
          "Rider (booked for someone else)".tr,
          Text([order.riderName, order.riderPhone, order.riderEmail].whereType<String>().join(' · '), style: AppThemeData.mediumTextStyle(fontSize: 14, color: _text(isDark))),
        ),
      );
    }
    if (showCancellation && _hasCancellation) {
      final by = order.cancelledBy == 'driver' ? "by driver".tr : (order.cancelledBy == 'customer' ? "by you".tr : '');
      children.add(_section("${'Cancellation reason'.tr} $by".trim(), Text(order.cancelReason!, style: AppThemeData.mediumTextStyle(fontSize: 14, color: AppThemeData.danger300))));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
        border: Border.all(color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// Read-only list of the stops chosen for the ride being booked (the confirm
/// step; stops are edited on the location step, where the fare is computed).
class CabStopsSummary extends StatelessWidget {
  final CabRideOptions controller;
  final bool isDark;

  const CabStopsSummary({super.key, required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Stops".tr, style: AppThemeData.boldTextStyle(fontSize: 14, color: _sub(isDark))),
          const SizedBox(height: 4),
          for (int i = 0; i < controller.stops.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  _stopBadge(CabRideOptions.stopLabel(i)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(controller.stops[i].address, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppThemeData.mediumTextStyle(fontSize: 14, color: _text(isDark)))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
