import 'package:customer/screen_ui/finance/fin_ds.dart';
import 'package:customer/service/finance_region_service.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/finance_region_rules.dart';
import 'package:customer/utils/region_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Spideli Finance where the customer's region does not offer it
/// ([FinanceRegionStatus.notOffered]), or where the app cannot tell the
/// region ([FinanceRegionStatus.unresolved]); [onRetry] resolves it again.
class FinanceRegionUnavailable extends StatelessWidget {
  final FinanceRegionPick pick;
  final VoidCallback onRetry;

  const FinanceRegionUnavailable({super.key, required this.pick, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final bool unresolved = pick.status == FinanceRegionStatus.unresolved;
    return FinScaffold(
      title: "Spideli Finance".tr,
      body: FinBody(children: [
        FinState.empty(
          unresolved ? Icons.location_searching_rounded : Icons.public_off_rounded,
          unresolved ? "We could not tell which region you are in.".tr : "Spideli Finance is not available in your region yet.".tr,
          message: unresolved
              ? "Choose your delivery location, then try again.".tr
              : "It will appear here as soon as it opens where you are.".tr,
          actionLabel: "Try again".tr,
          onAction: onRetry,
        ),
      ]),
    );
  }
}

/// The Finance region in use (its settings, limits and fees apply), on the
/// Profile tab; where several regions serve the customer's place, a tap
/// switches between them.
class FinanceRegionTile extends StatelessWidget {
  const FinanceRegionTile({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FinanceRegionPick>(
      stream: FinanceRegion.watch(),
      builder: (context, snap) {
        final pick = snap.data;
        final String? id = pick?.regionId;
        if (pick == null || id == null) return const SizedBox.shrink();
        final String currency = RegionService.currencyForRegion(id)?.code ?? '';
        final bool canSwitch = pick.choices.length > 1;
        return FinListTile(
          icon: Icons.public_rounded,
          iconTone: DsTone.brand,
          title: "Region".tr,
          subtitle: [FinanceRegion.nameOf(id), if (currency.isNotEmpty) currency].join(' · '),
          chevron: canSwitch,
          onTap: canSwitch ? () => _choose(pick) : null,
        );
      },
    );
  }

  static Future<void> _choose(FinanceRegionPick pick) async {
    final String? chosen = await finSheet<String>(
      title: "Region".tr,
      child: Builder(builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.sm),
              child: Text(
                "Several regions serve where you are. The services, limits and fees of the one you choose apply.".tr,
                style: DsTypography.caption.copyWith(color: DsColors.of(context).textSecondary),
              ),
            ),
            for (final id in pick.choices)
              FinListTile(
                icon: id == pick.regionId ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                iconTone: id == pick.regionId ? DsTone.brand : DsTone.neutral,
                title: FinanceRegion.nameOf(id),
                subtitle: RegionService.currencyForRegion(id)?.code,
                onTap: () => Get.back(result: id),
              ),
          ],
        );
      }),
    );
    if (chosen != null && chosen != pick.regionId) await FinanceRegion.choose(chosen);
  }
}
