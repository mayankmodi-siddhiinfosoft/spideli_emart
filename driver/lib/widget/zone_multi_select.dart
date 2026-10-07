import 'package:driver/models/zone_model.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Several zones at once (report Doc 43): a delivery company picks every zone
/// it serves. Presentational only — the caller reads its observables and
/// passes the values in.
class ZoneMultiSelect extends StatelessWidget {
  final List<ZoneModel> zones;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;

  const ZoneMultiSelect({super.key, required this.zones, required this.selectedIds, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${'Zones selected'.tr}: ${selectedIds.where((id) => zones.any((z) => z.id == id)).length}",
          style: t.caption.withColor(c.textMuted),
        ),
        const DsGap(DsSpace.sm),
        Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.sm,
          children: [
            for (final zone in zones)
              if (zone.id != null)
                FilterChip(
                  label: Text(zone.name ?? zone.id!),
                  selected: selectedIds.contains(zone.id),
                  onSelected: (_) => onToggle(zone.id!),
                  selectedColor: c.brandSoft,
                  checkmarkColor: c.brandStrong,
                ),
          ],
        ),
      ],
    );
  }
}
