import 'package:driver/constant/constant.dart';
import 'package:driver/models/cab_order_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/address_format.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// CabCar details from the ride document (spec 4.8 / 9.1, APP-CONTRACT):
/// written-communication badge, rider booked for someone else, passengers,
/// instructions and stops in order (with "Reached" when [onStopReached] is
/// set). Every block is hidden when its field is absent, so rides without
/// these fields look exactly as before. Who cancelled and why is shown by
/// `CancellationBlock` on the details screen.
class CabRideExtras extends StatelessWidget {
  final CabOrderModel order;

  /// Kept for call-site compatibility; colors now come from `context.dsColors`.
  final bool isDark;

  /// When set, the next unreached stop shows a "Reached" button.
  final void Function(int index)? onStopReached;

  const CabRideExtras({super.key, required this.order, required this.isDark, this.onStopReached});

  static bool hasContent(CabOrderModel order) {
    return order.writtenCommunicationOnly == true ||
        order.isForSomeoneElse ||
        order.hasPassengers ||
        (order.instructions?.trim().isNotEmpty ?? false) ||
        (order.stops?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (!hasContent(order)) return const SizedBox();
    final c = context.dsColors;
    final t = context.dsText;
    final children = <Widget>[];

    if (order.writtenCommunicationOnly == true) {
      children.add(DsInlineAlert(
        tone: DsTone.warning,
        icon: Icons.chat_bubble_outline_rounded,
        message: "Written communication only - contact the customer by chat, do not call".tr,
      ));
    }

    if (order.isForSomeoneElse) {
      children.add(_section(
        context,
        "Rider (booked for someone else)".tr,
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.riderName != null) Text(order.riderName!, style: t.titleSm.withColor(c.textPrimary)),
                  if (order.riderPhone != null) Text(order.riderPhone!, style: t.bodySm.withColor(c.textSecondary).tabular),
                ],
              ),
            ),
            if (order.riderPhone != null && order.writtenCommunicationOnly != true)
              DsIconButton(
                icon: Icons.call_outlined,
                semanticLabel: "Call rider".tr,
                variant: DsIconButtonVariant.outlined,
                onPressed: () => Constant.makePhoneCall(order.riderPhone!),
              ),
            if (order.riderPhone != null) ...[
              const DsGap(DsSpace.sm),
              DsIconButton(
                icon: Icons.sms_outlined,
                semanticLabel: "Send SMS to rider".tr,
                variant: DsIconButtonVariant.outlined,
                onPressed: () => launchUrl(Uri(scheme: 'sms', path: order.riderPhone!)),
              ),
            ],
          ],
        ),
      ));
    }

    if (order.hasPassengers) {
      children.add(DsInfoRow(label: "Passengers".tr, value: "${order.adults} ${'adults'.tr}, ${order.children} ${'children'.tr}"));
    }

    if (order.instructions?.trim().isNotEmpty ?? false) {
      children.add(_section(context, "Instructions".tr, Text(order.instructions!.trim(), style: t.body.withColor(c.textPrimary))));
    }

    final stops = order.orderedStops;
    if (stops.isNotEmpty) {
      final nextIndex = stops.indexWhere((s) => s['reached'] != true);
      children.add(_section(
        context,
        "Stops".tr,
        Column(
          children: List.generate(stops.length, (i) {
            final stop = stops[i];
            final reached = stop['reached'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: reached ? c.successSoft : c.brandSoft, shape: BoxShape.circle),
                    child: reached
                        ? Icon(Icons.check_rounded, size: 15, color: c.successStrong)
                        : Text("${i + 1}", style: t.labelSm.withColor(c.brandStrong)),
                  ),
                  const DsGap(DsSpace.md),
                  Expanded(
                    child: Text(
                      // 02#18: a geocoded stop can carry a baked-in "null" part.
                      AddressFormat.clean(stop['address']),
                      style: reached ? t.body.withColor(c.textMuted).strike : t.body.withColor(c.textPrimary),
                    ),
                  ),
                  if (!reached && onStopReached != null && i == nextIndex) ...[
                    const DsGap(DsSpace.sm),
                    DsButton.tonal(label: "Reached".tr, size: DsButtonSize.sm, onPressed: () => onStopReached!(i)),
                  ],
                ],
              ),
            );
          }),
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++)
            Padding(padding: const EdgeInsets.only(bottom: DsSpace.sm), child: DsFadeSlideIn(index: i, child: children[i])),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget body) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.overline.withColor(c.textMuted)),
        const DsGap(DsSpace.xs),
        body,
      ],
    );
  }
}
