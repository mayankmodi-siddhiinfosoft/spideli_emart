import 'package:driver/constant/constant.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/themes/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// CabCar details from the ride document (spec 4.8 / 9.1, APP-CONTRACT):
/// written-communication badge, rider booked for someone else, passengers,
/// instructions, stops in order (with "Reached" when [onStopReached] is set)
/// and, for history, the cancellation reason. Every block is hidden when its
/// field is absent, so rides without these fields look exactly as before.
class CabRideExtras extends StatelessWidget {
  final CabOrderModel order;
  final bool isDark;

  /// When set, the next unreached stop shows a "Reached" button.
  final void Function(int index)? onStopReached;

  /// Show `cancelReason` (history screens).
  final bool showCancellation;

  const CabRideExtras({super.key, required this.order, required this.isDark, this.onStopReached, this.showCancellation = false});

  static bool hasContent(CabOrderModel order, {bool showCancellation = false}) {
    return order.writtenCommunicationOnly == true ||
        order.isForSomeoneElse ||
        order.hasPassengers ||
        (order.instructions?.trim().isNotEmpty ?? false) ||
        (order.stops?.isNotEmpty ?? false) ||
        (showCancellation && _hasCancellation(order));
  }

  /// A ride rejected by one driver goes back to dispatch and may later be
  /// completed by another, so the reason is shown only on a ride that ended
  /// cancelled / rejected.
  static bool _hasCancellation(CabOrderModel order) =>
      (order.cancelReason?.isNotEmpty ?? false) && [Constant.orderCancelled, Constant.orderRejected, Constant.driverRejected].contains(order.status);

  Color get _label =>isDark ? AppThemeData.grey300 : AppThemeData.grey600;

  Color get _value => isDark ? AppThemeData.grey50 : AppThemeData.grey900;

  @override
  Widget build(BuildContext context) {
    if (!hasContent(order, showCancellation: showCancellation)) return const SizedBox();
    final children = <Widget>[];

    if (order.writtenCommunicationOnly == true) {
      children.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppThemeData.warning50, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppThemeData.warning300)),
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline, size: 18, color: AppThemeData.warning400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Written communication only - contact the customer by chat, do not call".tr,
                style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 13, color: AppThemeData.grey900),
              ),
            ),
          ],
        ),
      ));
    }

    if (order.isForSomeoneElse) {
      children.add(_section(
        "Rider (booked for someone else)".tr,
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.riderName != null) Text(order.riderName!, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 15, color: _value)),
                  if (order.riderPhone != null) Text(order.riderPhone!, style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 13, color: _label)),
                ],
              ),
            ),
            if (order.riderPhone != null && order.writtenCommunicationOnly != true)
              _roundIcon(Icons.call_outlined, () => Constant.makePhoneCall(order.riderPhone!)),
            if (order.riderPhone != null) ...[
              const SizedBox(width: 8),
              _roundIcon(Icons.sms_outlined, () => launchUrl(Uri(scheme: 'sms', path: order.riderPhone!))),
            ],
          ],
        ),
      ));
    }

    if (order.hasPassengers) {
      children.add(_row("Passengers".tr, "${order.adults} ${'adults'.tr}, ${order.children} ${'children'.tr}"));
    }

    if (order.instructions?.trim().isNotEmpty ?? false) {
      children.add(_section("Instructions".tr, Text(order.instructions!.trim(), style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: _value))));
    }

    final stops = order.orderedStops;
    if (stops.isNotEmpty) {
      final nextIndex = stops.indexWhere((s) => s['reached'] != true);
      children.add(_section(
        "Stops".tr,
        Column(
          children: List.generate(stops.length, (i) {
            final stop = stops[i];
            final reached = stop['reached'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: reached ? AppThemeData.success400 : AppThemeData.primary50,
                    child: reached
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text("${i + 1}", style: TextStyle(fontSize: 12, fontFamily: AppThemeData.semiBold, color: AppThemeData.primary300)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stop['address']?.toString() ?? '',
                      style: TextStyle(
                        fontFamily: AppThemeData.medium,
                        fontSize: 14,
                        color: reached ? _label : _value,
                        decoration: reached ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (!reached && onStopReached != null && i == nextIndex)
                    TextButton(
                      style: TextButton.styleFrom(backgroundColor: AppThemeData.primary300, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      onPressed: () => onStopReached!(i),
                      child: Text("Reached".tr),
                    ),
                ],
              ),
            );
          }),
        ),
      ));
    }

    if (showCancellation && _hasCancellation(order)) {
      final by = order.cancelledBy == 'driver'
          ? "by driver".tr
          : order.cancelledBy == 'customer'
              ? "by customer".tr
              : '';
      children.add(_section("${'Cancellation reason'.tr} $by".trim(), Text(order.cancelReason!, style: TextStyle(fontFamily: AppThemeData.medium, fontSize: 14, color: AppThemeData.danger300))));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
        ],
      ),
    );
  }

  Widget _section(String title, Widget body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 13, color: _label)),
        const SizedBox(height: 4),
        body,
      ],
    );
  }

  Widget _row(String title, String value) {
    return Row(
      children: [
        Expanded(child: Text(title, style: TextStyle(fontFamily: AppThemeData.regular, fontSize: 16, color: _label))),
        Text(value, style: TextStyle(fontFamily: AppThemeData.semiBold, fontSize: 16, color: _value)),
      ],
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1, color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
            borderRadius: BorderRadius.circular(120),
          ),
        ),
        child: Icon(icon, size: 20, color: AppThemeData.primary300),
      ),
    );
  }
}
