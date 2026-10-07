import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Constant;
import 'package:driver/app/rental_service/widget/rental_proposal_card.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/models/rental_order_model.dart';
import 'package:driver/services/audio_player_service.dart';
import 'package:driver/services/dispatch_offer_rules.dart';
import 'package:driver/services/incoming_offer_service.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:driver/utils/region_service.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The incoming-order dialog (D3): one dispatch offer over whatever screen is
/// open, its summary read live from Firestore, Accept / Reject and the
/// countdown of `driverOrderAcceptRejectDuration`. It cannot be dismissed;
/// it closes itself once the offer is answered, expired or withdrawn
/// (cancelled, re-dispatched), whichever screen or device did it, or once it
/// has no countdown any more (a rental whose counter-offer now waits for the
/// customer: it stays on the rental home's cards).
class IncomingOfferDialog extends StatefulWidget {
  final String orderId;

  const IncomingOfferDialog({super.key, required this.orderId});

  @override
  State<IncomingOfferDialog> createState() => _IncomingOfferDialogState();
}

class _IncomingOfferDialogState extends State<IncomingOfferDialog> {
  Timer? _tick;
  DateTime _now = DateTime.now();
  bool _closing = false;
  final List<Worker> _workers = [];

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _workers.add(ever(IncomingOfferService.offers, (_) => _closeWhenGone()));
    _workers.add(ever(IncomingOfferService.handled, (_) => _closeWhenGone()));
    // The alert rings while the offer waits. Held: a module screen that
    // stops the shared player for its own offers no longer silences it.
    unawaited(AudioPlayerService.hold());
    WidgetsBinding.instance.addPostFrameCallback((_) => _closeWhenGone());
  }

  void _closeWhenGone() {
    if (_closing || !mounted || IncomingOfferService.isDialogOffer(widget.orderId)) return;
    _closing = true;
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    // A reason sheet may sit above the dialog: the dialog leaves without
    // taking the sheet with it.
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final Worker w in _workers) {
      w.dispose();
    }
    unawaited(AudioPlayerService.release());
    IncomingOfferService.dialogClosed(widget.orderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(DsSpace.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: DsLayout.contentMax),
          child: SingleChildScrollView(
            child: Obx(() {
              final IncomingOffer? offer = IncomingOfferService.offers[widget.orderId];
              final bool answering = IncomingOfferService.answering.contains(widget.orderId);
              if (offer == null) return const SizedBox.shrink();
              return OfferRequestCard(offer: offer, now: _now, accepting: answering);
            }),
          ),
        ),
      ),
    );
  }
}

/// A [DsRequestCard] for an order waiting for this driver's answer, in the
/// dialog or on a module home. A dispatch offer carries its countdown.
class OfferRequestCard extends StatelessWidget {
  final IncomingOffer offer;
  final DateTime now;
  final bool accepting;
  final EdgeInsetsGeometry? margin;

  const OfferRequestCard({super.key, required this.offer, required this.now, this.accepting = false, this.margin});

  static String _title(DispatchKind kind) {
    switch (kind) {
      case DispatchKind.delivery:
        return "New Order".tr;
      case DispatchKind.cab:
        return "New ride request".tr;
      case DispatchKind.parcel:
        return "New parcel request".tr;
      case DispatchKind.rental:
        return "New rental request".tr;
    }
  }

  static DsSection _section(DispatchKind kind) {
    switch (kind) {
      case DispatchKind.delivery:
        return DsSection.delivery;
      case DispatchKind.cab:
        return DsSection.cab;
      case DispatchKind.parcel:
        return DsSection.parcel;
      case DispatchKind.rental:
        return DsSection.rental;
    }
  }

  static String _kindLabel(DispatchKind kind) {
    switch (kind) {
      case DispatchKind.delivery:
        return "Delivery".tr;
      case DispatchKind.cab:
        return "Cab".tr;
      case DispatchKind.parcel:
        return "Parcel".tr;
      case DispatchKind.rental:
        return "Rental".tr;
    }
  }

  /// The customer's price proposal on a rental (spec 4.9), answered right
  /// here — Accept / Reject / Counter — before the booking itself can be
  /// accepted (the booking's Accept refuses while it is pending). Null for
  /// any other order.
  Widget? _proposal(BuildContext context) {
    if (offer.kind != DispatchKind.rental) return null;
    final dynamic proposal = offer.order['priceProposal'];
    if (proposal is! Map) return null;
    String? text(dynamic v) => v?.toString();
    final RentalOrderModel booking = RentalOrderModel()
      ..id = offer.orderId
      ..regionId = text(offer.order['regionId'])
      ..subTotal = text(offer.order['subTotal'])
      ..listedPrice = text(offer.order['listedPrice'])
      ..priceProposal = Map<String, dynamic>.from(proposal);
    return RentalProposalCard(order: booking, isDark: context.dsIsDark);
  }

  /// The amount in the record's currency; the bare number while no currency
  /// is loaded yet (the app opened straight from a push).
  String _amount(String value, String? regionId) {
    try {
      return Constant.amountShow(currency: RegionService.currencyForRecord(regionId), amount: value);
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final OfferSummary s = offer.summary;
    final String section = Constant.sectionNameFromId(s.sectionId);
    final bool freelance = (Constant.userModel?.vendorID ?? '').isEmpty;

    String? fare;
    String? fareCaption;
    switch (s.kind) {
      case DispatchKind.delivery:
        // As on the delivery card: the charge is shown to a freelance driver.
        if (freelance && s.fare != null) {
          fare = _amount(s.fare!, s.regionId);
          fareCaption = "Delivery Charge".tr;
        }
      case DispatchKind.parcel:
        if (s.fare != null) {
          fare = _amount(s.fare!, s.regionId);
          fareCaption = "Amount".tr;
        }
      case DispatchKind.rental:
        if (s.fare != null) {
          fare = _amount(s.fare!, s.regionId);
          fareCaption = s.scheduledAt == null ? "Amount".tr : Constant.timestampToDateTime(Timestamp.fromDate(s.scheduledAt!));
        }
      case DispatchKind.cab:
        break;
    }

    final List<DsRouteStop> stops = [
      DsRouteStop(
        kind: DsStopKind.pickup,
        label: s.pickupLabel.isEmpty ? "Pickup".tr : s.pickupLabel,
        address: s.pickupAddress.isEmpty ? '—' : s.pickupAddress,
      ),
      if (s.kind != DispatchKind.rental)
        DsRouteStop(
          kind: DsStopKind.drop,
          label: s.kind == DispatchKind.delivery
              ? "${'Deliver to the'.tr} · ${s.dropLabel}"
              : (s.dropLabel.isEmpty ? "Destination".tr : s.dropLabel),
          address: s.dropAddress.isEmpty ? '—' : s.dropAddress,
        ),
    ];

    final double? computedKm = Utils.distanceKm(s.pickupLat, s.pickupLng, s.dropLat, s.dropLng);
    final double? storedKm = double.tryParse(s.distance ?? '');
    final double? km = storedKm ?? computedKm;
    final List<DsTripMetric> metrics = [
      if (s.kind != DispatchKind.rental)
        DsTripMetric(icon: Icons.route_rounded, value: km == null ? '—' : "${km.toStringAsFixed(2)} ${Constant.distanceType}", label: "Trip Distance".tr),
      if ((double.tryParse(s.tip ?? '') ?? 0) > 0) DsTripMetric(icon: Icons.volunteer_activism_outlined, value: _amount(s.tip!, s.regionId), label: "Tips".tr),
      if (s.rideType != null) DsTripMetric(icon: Icons.local_taxi_rounded, value: s.rideType!, label: "Ride Type".tr),
      if (s.weight != null) DsTripMetric(icon: Icons.scale_outlined, value: s.weight!, label: "Weight".tr),
      if (s.packageName != null) DsTripMetric(icon: Icons.inventory_2_outlined, value: s.packageName!, label: "Package Details:".tr),
      if (s.includedDistance != null) DsTripMetric(icon: Icons.route_rounded, value: "${s.includedDistance} ${Constant.distanceType}", label: "Including Distance:".tr),
      if (s.includedHours != null) DsTripMetric(icon: Icons.schedule_rounded, value: "${s.includedHours} Hr", label: "Including Duration:".tr),
    ];

    final Duration left = offer.remaining(now);
    return DsRequestCard(
      margin: margin,
      title: _title(s.kind),
      section: _section(s.kind),
      sectionLabel: section.isEmpty ? _kindLabel(s.kind) : section,
      fare: fare,
      fareCaption: fareCaption,
      stops: stops,
      metrics: metrics.take(4).toList(),
      extra: _proposal(context),
      countdown: offer.timed ? OfferTiming.fractionLeft(offer.start, IncomingOfferService.windowSeconds, now) : null,
      countdownLabel: offer.timed ? OfferTiming.label(left) : null,
      accepting: accepting,
      acceptLabel: "Accept".tr,
      rejectLabel: "Reject".tr,
      onAccept: accepting ? null : () => IncomingOfferService.accept(offer.orderId),
      onReject: accepting ? null : () => IncomingOfferService.reject(offer.orderId),
    );
  }
}

/// The orders of [kind] waiting for this driver's answer, as request cards
/// at the top of a module home (parcel, rental). Nothing when there is none.
class PendingOfferCards extends StatefulWidget {
  final DispatchKind kind;
  final EdgeInsetsGeometry padding;

  const PendingOfferCards({super.key, required this.kind, this.padding = EdgeInsets.zero});

  @override
  State<PendingOfferCards> createState() => _PendingOfferCardsState();
}

class _PendingOfferCardsState extends State<PendingOfferCards> {
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Only the countdown moves; a tick costs a rebuild of a few cards.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && IncomingOfferService.offers.values.any((o) => o.kind == widget.kind && o.timed)) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<IncomingOffer> list = IncomingOfferService.offersOf(widget.kind);
      final Set<String> answering = IncomingOfferService.answering.toSet();
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Requests waiting for you".tr, style: context.dsText.labelSm),
            const DsGap(DsSpace.sm),
            for (final IncomingOffer offer in list)
              OfferRequestCard(
                offer: offer,
                now: _now,
                accepting: answering.contains(offer.orderId),
                margin: const EdgeInsets.only(bottom: DsSpace.md),
              ),
          ],
        ),
      );
    });
  }
}
