import 'package:customer/controllers/order_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:customer/utils/order_history_limit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// "Choosing the period of history" (WEB spec 9), client point 12's second
/// half: a subscribed customer picks All time, one of the months they
/// actually have orders in, or a date span with both ends inclusive.
///
/// Entirely client side - the picker narrows orders that are already in
/// memory ([OrderController.renderOrders]) and never issues a new query. It
/// applies to every tab at once, and only entitled customers are offered it
/// ([OrderController.canChoosePeriod]).
class OrderPeriodBar extends StatelessWidget {
  final OrderController controller;

  /// Read inside the screen's tracked builder and handed down, so this widget
  /// never has to read an observable while it builds.
  final HistoryPeriod period;
  final List<DateTime> months;

  const OrderPeriodBar({super.key, required this.controller, required this.period, required this.months});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool narrowed = !period.isAll;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, 0),
      child: DsCard.outlined(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
        borderColor: narrowed ? c.brand : null,
        color: narrowed ? c.brandSoft : null,
        semanticLabel: "Choose period".tr,
        onTap: () => show(context, controller, period, months),
        child: Row(
          children: [
            Icon(Icons.event_note_outlined, size: 18, color: narrowed ? c.brandStrong : c.textMuted),
            const DsGap(DsSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Period".tr, style: DsTypography.overline.copyWith(color: c.textMuted)),
                  Text(period.label(), style: t.bodyStrong.copyWith(color: narrowed ? c.brandStrong : c.textPrimary)),
                ],
              ),
            ),
            if (narrowed)
              DsIconButton(
                icon: Icons.close_rounded,
                semanticLabel: "Show all time".tr,
                size: 34,
                onPressed: () => controller.setPeriod(const HistoryPeriod.all()),
              )
            else
              Icon(Icons.expand_more_rounded, size: 20, color: c.textMuted),
          ],
        ),
      ),
    );
  }

  /// Opens the picker. Applies the chosen period to every tab at once.
  static Future<void> show(BuildContext context, OrderController controller, HistoryPeriod period, List<DateTime> months) async {
    final HistoryPeriod? chosen = await DsBottomSheet.show<HistoryPeriod>(
      title: "Choose period".tr,
      subtitle: "Applies to every tab.".tr,
      child: _PeriodSheet(period: period, months: months),
    );
    if (chosen != null) controller.setPeriod(chosen);
  }
}

class _PeriodSheet extends StatefulWidget {
  final HistoryPeriod period;
  final List<DateTime> months;

  const _PeriodSheet({required this.period, required this.months});

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    if (widget.period.mode == HistoryPeriodMode.range) {
      _from = widget.period.from;
      _to = widget.period.to;
    }
  }

  void _pick(HistoryPeriod period) => Get.back<HistoryPeriod>(result: period);

  Future<void> _pickDay({required bool start}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = (start ? _from : _to) ?? now;
    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2015),
      lastDate: now,
      helpText: start ? "From".tr : "To".tr,
    );
    if (day == null) return;
    setState(() {
      if (start) {
        _from = day;
      } else {
        _to = day;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool allSelected = widget.period.isAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Option(label: "All time".tr, icon: Icons.all_inclusive_rounded, selected: allSelected, onTap: () => _pick(const HistoryPeriod.all())),
        if (widget.months.isNotEmpty) ...[
          const DsGap(DsSpace.lg),
          Text("By month".tr, style: DsTypography.overline.copyWith(color: c.textMuted)),
          const DsGap(DsSpace.sm),
          // Only months the customer has orders in - an empty month cannot be
          // chosen (WEB spec 9).
          ...widget.months.map(
            (m) => _Option(
              label: HistoryPeriod.monthLabel(m),
              icon: Icons.calendar_month_outlined,
              selected: widget.period.mode == HistoryPeriodMode.month && widget.period.month == m,
              onTap: () => _pick(HistoryPeriod.month(m)),
            ),
          ),
        ],
        const DsGap(DsSpace.lg),
        Text("By date".tr, style: DsTypography.overline.copyWith(color: c.textMuted)),
        const DsGap(DsSpace.sm),
        Row(
          children: [
            Expanded(child: _DayField(label: "From".tr, day: _from, onTap: () => _pickDay(start: true), onClear: _from == null ? null : () => setState(() => _from = null))),
            const DsGap(DsSpace.sm),
            Expanded(child: _DayField(label: "To".tr, day: _to, onTap: () => _pickDay(start: false), onClear: _to == null ? null : () => setState(() => _to = null))),
          ],
        ),
        const DsGap(DsSpace.sm),
        Text("Both days are included. One end on its own is enough.".tr, style: t.caption),
        const DsGap(DsSpace.md),
        // Nothing happens until Apply: a half-typed span cannot blank the list.
        DsButton.primary(
          label: "Apply".tr,
          icon: Icons.check_rounded,
          expand: true,
          onPressed: _from == null && _to == null ? null : () => _pick(HistoryPeriod.range(from: _from, to: _to)),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Option({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsCard.outlined(
      margin: const EdgeInsets.only(bottom: DsSpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
      borderColor: selected ? c.brand : null,
      color: selected ? c.brandSoft : null,
      semanticLabel: label,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? c.brandStrong : c.textMuted),
          const DsGap(DsSpace.md),
          Expanded(child: Text(label, style: DsTypography.bodyStrong.copyWith(color: selected ? c.brandStrong : c.textPrimary))),
          if (selected) Icon(Icons.check_circle_rounded, size: 18, color: c.brandStrong),
        ],
      ),
    );
  }
}

class _DayField extends StatelessWidget {
  final String label;
  final DateTime? day;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DayField({required this.label, required this.day, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsCard.outlined(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
      semanticLabel: label,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DsTypography.overline.copyWith(color: c.textMuted)),
                Text(
                  day == null ? "Any".tr : HistoryPeriod.dayLabel(day!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.bodyStrong.copyWith(color: day == null ? c.textMuted : c.textPrimary),
                ),
              ],
            ),
          ),
          if (onClear != null)
            DsIconButton(icon: Icons.backspace_outlined, semanticLabel: "Clear".tr, size: 32, onPressed: onClear)
          else
            Icon(Icons.calendar_today_outlined, size: 16, color: c.textMuted),
        ],
      ),
    );
  }
}
