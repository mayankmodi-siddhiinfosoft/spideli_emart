import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/cab_ride_options.dart';
import 'package:customer/models/cab_order_model.dart';
import 'package:customer/screen_ui/widgets/order_ui.dart';
import 'package:customer/themes/ds/ds.dart';
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

/// Lettered stop marker (A, B, …) that turns into a tick once reached.
class _StopBadge extends StatelessWidget {
  final String label;
  final bool reached;

  const _StopBadge({required this.label, this.reached = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final tone = reached ? c.tone(DsTone.success) : c.tone(DsTone.brand);
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tone.main, shape: BoxShape.circle),
      child: reached ? Icon(Icons.check_rounded, size: 14, color: tone.onMain) : Text(label, style: DsTypography.labelSm.copyWith(color: tone.onMain, fontSize: 12, height: 1)),
    );
  }
}

/// The green ring used for a pickup and the red pin used for a destination,
/// so every cab surface marks a route the same way.
class CabEndpointMarker extends StatelessWidget {
  final bool isPickup;
  final double size;

  const CabEndpointMarker({super.key, required this.isPickup, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    if (!isPickup) return Icon(Icons.place_rounded, size: size + 2, color: c.dangerStrong);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.successStrong, width: size / 4),
      ),
    );
  }
}

/// A pickup / destination row that shows the live text of [controller] (the
/// address the map picker wrote into it) and opens the picker on tap.
///
/// It listens to the [TextEditingController] itself, so an address set from
/// anywhere — a picker result, `clear()`, a restored ride — shows up at once.
class CabAddressRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isPickup;
  final VoidCallback? onTap;

  const CabAddressRow({super.key, required this.controller, required this.hint, required this.isPickup, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text.trim();
        final empty = text.isEmpty;
        final row = ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
            child: Row(
              children: [
                CabEndpointMarker(isPickup: isPickup),
                const DsGap(DsSpace.md),
                Expanded(
                  child: Text(empty ? hint : text, maxLines: 2, overflow: TextOverflow.ellipsis, style: empty ? t.body.withColor(c.textMuted) : t.bodyStrong),
                ),
                if (onTap != null) ...[const DsGap(DsSpace.sm), Icon(Icons.edit_location_alt_outlined, size: 18, color: c.textMuted)],
              ],
            ),
          ),
        );
        if (onTap == null) return Semantics(label: '$hint: ${empty ? '' : text}', child: row);
        return Semantics(
          button: true,
          label: '$hint: ${empty ? '' : text}',
          excludeSemantics: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap, borderRadius: DsRadius.brMd, child: row),
          ),
        );
      },
    );
  }
}

/// Pickup + destination in one outlined card, joined by a connector.
class CabRouteFields extends StatelessWidget {
  final Widget pickup;
  final Widget destination;

  const CabRouteFields({super.key, required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsCard.outlined(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          pickup,
          Padding(
            padding: const EdgeInsetsDirectional.only(start: DsSpace.md + 7),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 14,
                  decoration: BoxDecoration(color: c.border, borderRadius: DsRadius.brPill),
                ),
                const Spacer(),
              ],
            ),
          ),
          destination,
        ],
      ),
    );
  }
}

/// One label / amount line of a fare breakdown.
class CabBillRow extends StatelessWidget {
  final String label;
  final String value;

  /// Larger, primary-colored type for the total line.
  final bool emphasize;

  /// Red amount (discounts).
  final Color? valueColor;

  /// Suffix after the label, e.g. an applied coupon code.
  final String? labelSuffix;

  /// Renders the label underlined with an info icon (tap opens the split).
  final VoidCallback? onTap;

  const CabBillRow({super.key, required this.label, required this.value, this.emphasize = false, this.valueColor, this.labelSuffix, this.onTap});

  @override
  Widget build(BuildContext context) {
    // One shared bill row for every service: label left, amount right aligned
    // in tabular figures, total separated and heavier.
    if (emphasize) {
      return OrderTotalRow(label: label, value: value, divider: false, valueColor: valueColor);
    }
    return OrderMoneyRow(label: label, value: value, valueColor: valueColor, labelSuffix: labelSuffix, underline: onTap != null, onTap: onTap);
  }
}

/// Avatar, name, vehicle and rating of the assigned driver.
class CabDriverIdentity extends StatelessWidget {
  final String? name;
  final String? photoUrl;
  final Map<String, dynamic>? vehicle;
  final String rating;

  const CabDriverIdentity({super.key, required this.name, required this.photoUrl, required this.vehicle, required this.rating});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final v = vehicle;
    final vType = v?['vehicleType']?.toString() ?? '';
    final brand = v?['carBrand']?.toString() ?? '';
    final carModel = v?['carModel']?.toString() ?? '';
    final plate = v?['carPlateNumber']?.toString() ?? '';
    final car = "$brand $carModel".trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsAvatar(imageUrl: photoUrl ?? '', name: name, size: 56, ring: true),
        const DsGap(DsSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name ?? '', style: t.titleSm),
              if (v != null) ...[
                if (vType.isNotEmpty || car.isNotEmpty) ...[
                  const DsGap(DsSpace.xxs),
                  Text([if (vType.isNotEmpty) vType, if (car.isNotEmpty) car].join(' · '), style: t.bodySm),
                ],
                if (plate.isNotEmpty) ...[const DsGap(DsSpace.sm), DsBadge(label: plate.toUpperCase(), style: DsBadgeStyle.outline)],
              ],
            ],
          ),
        ),
        const DsGap(DsSpace.sm),
        DsBadge(label: rating, tone: DsTone.warning, icon: Icons.star_rounded),
      ],
    );
  }
}

/// Bottom-sheet frame used by the map screens: DS sheet surface, top radius
/// and a grab handle, so every panel over the map matches.
class CabSheetShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CabSheetShell({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.sm, DsSpace.lg, DsSpace.lg)});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: DsRadius.sheetTop,
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: c.isDark ? 0.4 : 0.10),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: DsSpace.md),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// Floating control over a map (back, recenter): always readable on tiles.
class CabMapButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  const CabMapButton({super.key, required this.icon, required this.semanticLabel, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: DsShadows.md(context)),
      child: DsIconButton(icon: icon, semanticLabel: semanticLabel, variant: DsIconButtonVariant.outlined, color: c.textPrimary, onPressed: onPressed),
    );
  }
}

/// Pickup → destination rail: origin ring, connector, destination pin. Used
/// by the ride history rows and the ride detail screen.
class CabRouteRail extends StatelessWidget {
  final String source;
  final String destination;

  /// Extra widget shown next to the pickup line (e.g. a status chip).
  final Widget? sourceTrailing;

  const CabRouteRail({super.key, required this.source, required this.destination, this.sourceTrailing});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.successStrong, width: 3),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(color: c.border, borderRadius: DsRadius.brPill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Icon(Icons.place_rounded, size: 16, color: c.dangerStrong),
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(source, style: t.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    if (sourceTrailing != null) ...[const DsGap(DsSpace.sm), sourceTrailing!],
                  ],
                ),
                const DsGap(DsSpace.md),
                Container(height: 1, color: c.divider),
                const DsGap(DsSpace.md),
                Text(destination, style: t.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small labelled block used by the read-only ride summaries.
class _ExtraSection extends StatelessWidget {
  final String title;
  final Widget body;

  const _ExtraSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.dsText.overline),
          const DsGap(DsSpace.xs),
          body,
        ],
      ),
    );
  }
}

/// Stops A, B, … between pickup and destination: add / remove / reorder
/// (spec 4.8). Every change recalculates the route and so the fare.
class CabStopsEditor extends StatelessWidget {
  final CabRideOptions controller;

  const CabStopsEditor({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Obx(() {
      final stops = controller.stops;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < stops.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.sm),
              child: DsCard.outlined(
                padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.sm, DsSpace.xs, DsSpace.sm),
                radius: DsRadius.md,
                child: Row(
                  children: [
                    _StopBadge(label: CabRideOptions.stopLabel(i)),
                    const DsGap(DsSpace.md),
                    Expanded(
                      child: Text(stops[i].address, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                    ),
                    DsIconButton(icon: Icons.arrow_upward_rounded, semanticLabel: "Move up".tr, size: 32, onPressed: i == 0 ? null : () => controller.moveStop(i, -1)),
                    DsIconButton(icon: Icons.arrow_downward_rounded, semanticLabel: "Move down".tr, size: 32, onPressed: i == stops.length - 1 ? null : () => controller.moveStop(i, 1)),
                    DsIconButton(icon: Icons.close_rounded, semanticLabel: "Remove stop".tr, size: 32, color: c.dangerStrong, onPressed: () => controller.removeStop(i)),
                  ],
                ),
              ),
            ),
          if (stops.length < CabRideOptions.maxStops)
            DsButton.ghost(
              label: stops.isEmpty ? "Add a stop".tr : "${'Add stop'.tr} ${CabRideOptions.stopLabel(stops.length)}",
              icon: Icons.add_location_alt_outlined,
              size: DsButtonSize.sm,
              onPressed: () async {
                final place = await pickRidePlace();
                if (place != null) controller.addStop(place.address, place.lat, place.lng);
              },
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

  const CabTripOptionsSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Obx(
      () => DsCard.outlined(
        padding: const EdgeInsets.all(DsSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: c.brandStrong),
                const DsGap(DsSpace.sm),
                Text("Trip options".tr, style: context.dsText.titleSm),
              ],
            ),
            const DsGap(DsSpace.md),
            _PassengerCounter(title: "Adults".tr, value: controller.adults.value, onMinus: controller.adults.value > 1 ? controller.decrementAdults : null, onPlus: controller.incrementAdults),
            _PassengerCounter(
              title: "Children".tr,
              value: controller.children.value,
              onMinus: controller.children.value > 0 ? controller.decrementChildren : null,
              onPlus: controller.incrementChildren,
            ),
            const DsGap(DsSpace.md),
            TextFieldWidget(title: "Instructions for the driver".tr, hintText: "e.g. gate code, luggage, where to wait".tr, controller: controller.instructionsController, maxLine: 3),
            const DsGap(DsSpace.sm),
            _OptionSwitch(
              title: "I can only communicate in writing".tr,
              subtitle: "The driver will contact you by chat instead of calling".tr,
              value: controller.writtenCommunicationOnly.value,
              onChanged: (value) => controller.writtenCommunicationOnly.value = value,
            ),
            _OptionSwitch(
              title: "Book this ride for someone else".tr,
              subtitle: "You pay for the ride".tr,
              value: controller.rideForSomeoneElse.value,
              onChanged: (value) => controller.rideForSomeoneElse.value = value,
            ),
            AnimatedSize(
              duration: DsMotion.of(context, DsMotion.base),
              curve: DsMotion.emphasized,
              alignment: Alignment.topCenter,
              child: controller.rideForSomeoneElse.value
                  ? Padding(
                      padding: const EdgeInsets.only(top: DsSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFieldWidget(title: "Rider's name".tr, hintText: "Full name".tr, controller: controller.riderNameController),
                          const DsGap(DsSpace.md),
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
                              initialSelection: controller.riderCountryISOCodeController.text.isNotEmpty
                                  ? controller.riderCountryISOCodeController.text
                                  : (Constant.defaultCountryCode.isNotEmpty ? Constant.defaultCountryCode : null),
                              showCountryOnly: false,
                              showOnlyCountryWhenClosed: false,
                              alignLeft: false,
                              textStyle: DsTypography.bodyStrong.copyWith(color: c.textPrimary),
                              dialogTextStyle: DsTypography.body.copyWith(color: c.textPrimary),
                              searchStyle: DsTypography.body.copyWith(color: c.textPrimary),
                              dialogBackgroundColor: c.surfaceRaised,
                            ),
                          ),
                          const DsGap(DsSpace.md),
                          TextFieldWidget(title: "Rider's email (optional)".tr, hintText: "Email".tr, controller: controller.riderEmailController, textInputType: TextInputType.emailAddress),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minus / value / plus row for the passenger counts.
class _PassengerCounter extends StatelessWidget {
  final String title;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;

  const _PassengerCounter({required this.title, required this.value, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xxs),
      child: Row(
        children: [
          Expanded(child: Text(title, style: t.bodyStrong)),
          DsIconButton(icon: Icons.remove_rounded, semanticLabel: "$title −", variant: DsIconButtonVariant.outlined, size: 36, onPressed: onMinus),
          SizedBox(
            width: 44,
            child: Text('$value', textAlign: TextAlign.center, style: t.titleSm.tabular),
          ),
          DsIconButton(icon: Icons.add_rounded, semanticLabel: "$title +", variant: DsIconButtonVariant.outlined, size: 36, onPressed: onPlus),
        ],
      ),
    );
  }
}

/// Title + explanation with a trailing switch.
class _OptionSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionSwitch({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeTrackColor: c.brand,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: t.bodyStrong),
      subtitle: Text(subtitle, style: t.caption),
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
    final headline = "Your driver cancelled — finding another driver".tr;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: DsInlineAlert(tone: DsTone.warning, title: reason.isEmpty ? null : headline, message: reason.isEmpty ? headline : reason),
    );
  }
}

/// Read-only CabCar extras of a ride: stops progress (from `stops[i].reached`),
/// passengers, instructions, written-only, rider and, for history, the
/// cancellation reason. Hidden when the ride has none of them.
class CabRideExtrasView extends StatelessWidget {
  final CabOrderModel order;
  final bool showCancellation;

  const CabRideExtrasView({super.key, required this.order, this.showCancellation = false});

  bool get _hasCancellation => (order.cancelReason?.isNotEmpty ?? false) && [Constant.orderCancelled, Constant.orderRejected].contains(order.status);

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final stops = order.orderedStops;
    final instructions = order.instructions?.trim() ?? '';
    final children = <Widget>[];

    if (stops.isNotEmpty) {
      final reachedCount = stops.where((s) => s['reached'] == true).length;
      children.add(
        _ExtraSection(
          title: "${'Stops'.tr} ($reachedCount/${stops.length} ${'reached'.tr})",
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpace.sm),
                child: DsProgressBar(value: reachedCount / stops.length, tone: DsTone.success, height: 6),
              ),
              ...List.generate(stops.length, (i) {
                final reached = stops[i]['reached'] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                  child: Row(
                    children: [
                      _StopBadge(label: CabRideOptions.stopLabel(i), reached: reached),
                      const DsGap(DsSpace.md),
                      Expanded(child: Text(stops[i]['address']?.toString() ?? '', style: reached ? t.bodyStrong.withColor(c.textMuted).strike : t.bodyStrong)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }
    if (order.hasPassengers) {
      children.add(
        _ExtraSection(
          title: "Passengers".tr,
          body: Wrap(
            spacing: DsSpace.sm,
            runSpacing: DsSpace.sm,
            children: [
              DsBadge(label: "${order.adults} ${'adults'.tr}", icon: Icons.person_rounded, tone: DsTone.brand),
              DsBadge(label: "${order.children} ${'children'.tr}", icon: Icons.child_care_rounded, tone: DsTone.info),
            ],
          ),
        ),
      );
    }
    if (instructions.isNotEmpty) {
      children.add(
        _ExtraSection(
          title: "Instructions".tr,
          body: Text(instructions, style: t.bodyStrong),
        ),
      );
    }
    if (order.writtenCommunicationOnly == true) {
      children.add(
        _ExtraSection(
          title: "Communication".tr,
          body: DsBadge(label: "Written communication only".tr, icon: Icons.chat_bubble_outline_rounded, tone: DsTone.info),
        ),
      );
    }
    if (order.isForSomeoneElse) {
      children.add(
        _ExtraSection(
          title: "Rider (booked for someone else)".tr,
          body: Text([order.riderName, order.riderPhone, order.riderEmail].whereType<String>().join(' · '), style: t.bodyStrong),
        ),
      );
    }
    if (showCancellation && _hasCancellation) {
      final by = order.cancelledBy == 'driver' ? "by driver".tr : (order.cancelledBy == 'customer' ? "by you".tr : '');
      children.add(
        _ExtraSection(
          title: "${'Cancellation reason'.tr} $by".trim(),
          body: DsInlineAlert(tone: DsTone.danger, message: order.cancelReason!),
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.sm),
      child: DsCard.outlined(
        padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xs),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

/// Read-only list of the stops chosen for the ride being booked (the confirm
/// step; stops are edited on the location step, where the fare is computed).
class CabStopsSummary extends StatelessWidget {
  final CabRideOptions controller;

  const CabStopsSummary({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Stops".tr, style: t.overline),
          const DsGap(DsSpace.sm),
          for (int i = 0; i < controller.stops.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
              child: Row(
                children: [
                  _StopBadge(label: CabRideOptions.stopLabel(i)),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Text(controller.stops[i].address, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Logo asset for a payment gateway name (`PaymentGateway.x.name`). Unknown
/// values fall back to the RazorPay logo, matching the previous chain of
/// conditionals on the booking screens.
String cabGatewayAsset(String method) {
  const assets = <String, String>{
    'wallet': "assets/images/ic_wallet.png",
    'cod': "assets/images/ic_cash.png",
    'stripe': "assets/images/stripe.png",
    'paypal': "assets/images/paypal.png",
    'payStack': "assets/images/paystack.png",
    'mercadoPago': "assets/images/mercado-pago.png",
    'flutterWave': "assets/images/flutterwave_logo.png",
    'payFast': "assets/images/payfast.png",
    'razorpay': "assets/images/razorpay.png",
    'midTrans': "assets/images/midtrans.png",
    'orangeMoney': "assets/images/orange_money.png",
    'xendit': "assets/images/xendit.png",
  };
  return assets[method] ?? "assets/images/razorpay.png";
}

/// Square logo tile for a payment gateway. An empty [image] renders the
/// neutral placeholder used before a method is chosen.
class CabGatewayLogo extends StatelessWidget {
  final String image;
  final String method;
  final double size;
  final bool selected;

  const CabGatewayLogo({super.key, required this.image, required this.method, this.size = 44, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: DsRadius.brSm,
        border: Border.all(color: selected ? c.brand : c.border),
        color: c.surface,
      ),
      child: image.isEmpty ? const SizedBox.shrink() : Padding(padding: EdgeInsets.all(method == "payFast" ? 0 : DsSpace.sm), child: Image.asset(image)),
    );
  }
}
