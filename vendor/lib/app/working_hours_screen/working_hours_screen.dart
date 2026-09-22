import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/working_hours_controller.dart';
import 'package:vendor/models/vendor_model.dart';
import 'package:vendor/themes/ds/ds.dart';

class WorkingHoursScreen extends StatelessWidget {
  const WorkingHoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: WorkingHoursController(),
      builder: (controller) {
        return DsScaffold(
          title: "Working Hours".tr,
          maxContentWidth: null,
          body: controller.isLoading.value
              ? const DsResponsive(
                  maxWidth: DsLayout.wideMax,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(DsSpace.lg),
                    child: Column(children: [DsSkeletonCard(height: 170), DsGap(DsSpace.lg), DsSkeletonList(itemCount: 5)]),
                  ),
                )
              // Local rebuild after a time is picked (the picked value is
              // written straight into the model, as before). DsObserve tracks
              // workingHours read in here so "+" / Remove Time re-render.
              : StatefulBuilder(
                  builder: (context, refresh) => DsObserve(
                    builder: (context) {
                      final days = <Widget>[];
                      for (int index = 0; index < controller.workingHours.length; index++) {
                        days.add(_dayCard(context, controller, index, () => refresh(() {})));
                      }
                      return SingleChildScrollView(
                        child: DsResponsive(
                          maxWidth: DsLayout.wideMax,
                          padded: true,
                          child: Padding(
                            padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DsFadeSlideIn(child: _WeekOverview(hours: controller.workingHours)),
                                DsSectionHeader(title: "Weekly schedule".tr, icon: Icons.calendar_view_week_rounded),
                                DsAdaptiveGrid(
                                  minItemWidth: 340,
                                  maxColumns: 2,
                                  equalHeight: false,
                                  children: [for (int i = 0; i < days.length; i++) DsFadeSlideIn(index: i + 1, child: days[i])],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save Details".tr,
              icon: Icons.check_rounded,
              expand: true,
              size: DsButtonSize.lg,
              onPressed: () async {
                bool isEmptyField = false;
                for (var element in controller.workingHours) {
                  var emptyList = element.timeslot!.where((element) => element.from!.isEmpty || element.to!.isEmpty);
                  if (element.timeslot!.isNotEmpty && emptyList.isNotEmpty && !isEmptyField) {
                    ShowToastDialog.showToast("Please enter valid details".tr);
                    isEmptyField = true;
                    continue;
                  }
                }

                if (!isEmptyField) {
                  controller.saveWorkingHours();
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _dayCard(BuildContext context, WorkingHoursController controller, int index, VoidCallback refresh) {
    final c = context.dsColors;
    final t = context.dsText;
    final day = "${controller.workingHours[index].day}";
    final slots = controller.workingHours[index].timeslot!;
    final isOpen = slots.isNotEmpty;
    return DsCard(
      padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.sm, DsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isOpen ? c.brand : c.surfaceAlt,
                  borderRadius: DsRadius.brMd,
                ),
                child: Text(
                  _abbr(day.tr),
                  style: t.labelSm.withColor(isOpen ? c.onBrand : c.textSecondary),
                ),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(day.tr, style: t.titleSm),
                    const DsGap(2),
                    DsBadge(
                      label: isOpen ? "Open".tr : "Closed".tr,
                      tone: isOpen ? DsTone.success : DsTone.neutral,
                      icon: isOpen ? Icons.schedule_rounded : Icons.do_not_disturb_on_outlined,
                      small: true,
                    ),
                  ],
                ),
              ),
              DsIconButton(
                icon: Icons.add_rounded,
                semanticLabel: "Add".tr,
                variant: DsIconButtonVariant.brand,
                onPressed: () {
                  controller.addValue(index);
                },
              ),
            ],
          ),
          AnimatedSize(
            duration: DsMotion.of(context, DsMotion.base),
            curve: DsMotion.standard,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int indexTimeSlot = 0; indexTimeSlot < slots.length; indexTimeSlot++)
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpace.md, right: DsSpace.sm),
                    child: _slot(context, controller, index, indexTimeSlot, refresh),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, WorkingHoursController controller, int index, int indexTimeSlot, VoidCallback refresh) {
    final c = context.dsColors;
    final slot = controller.workingHours[index].timeslot![indexTimeSlot];
    return Container(
      padding: const EdgeInsets.all(DsSpace.sm),
      decoration: BoxDecoration(color: c.surfaceAlt.withValues(alpha: c.isDark ? 0.5 : 0.6), borderRadius: DsRadius.brMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  icon: Icons.wb_sunny_outlined,
                  value: slot.from!.isEmpty ? null : slot.from.toString(),
                  placeholder: 'Start Time'.tr,
                  onTap: () async {
                    TimeOfDay? startTime = await _selectTime(context);
                    controller.workingHours[index].timeslot![indexTimeSlot].from = DateFormat(
                      'HH:mm',
                    ).format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, startTime!.hour, startTime.minute));
                    refresh();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                child: Icon(Icons.arrow_forward_rounded, size: 18, color: c.textMuted),
              ),
              Expanded(
                child: _TimeTile(
                  icon: Icons.nightlight_outlined,
                  value: slot.to!.isEmpty ? null : slot.to.toString(),
                  placeholder: 'End Time'.tr,
                  onTap: () async {
                    TimeOfDay? endTimeOfDay = await _selectTime(context);

                    if (endTimeOfDay != null) {
                      DateTime endTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, endTimeOfDay.hour, endTimeOfDay.minute);
                      DateTime time = DateFormat("HH:mm").parse(controller.workingHours[index].timeslot![indexTimeSlot].from.toString());
                      DateTime startTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, time.hour, time.minute);

                      if (startTime.isAfter(endTime)) {
                        ShowToastDialog.showToast("Please select Valid Time".tr);
                      } else {
                        if (endTimeOfDay.format(context).toString() == "12:00 AM") {
                          controller.workingHours[index].timeslot![indexTimeSlot].to = DateFormat(
                            'HH:mm',
                          ).format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59));
                        } else {
                          controller.workingHours[index].timeslot![indexTimeSlot].to = DateFormat(
                            'HH:mm',
                          ).format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, endTimeOfDay.hour, endTimeOfDay.minute));
                        }
                      }
                    }
                    refresh();
                  },
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.xs),
          Row(
            children: [
              const DsGap(DsSpace.xs),
              Expanded(child: _DayBar(from: slot.from, to: slot.to)),
              const DsGap(DsSpace.sm),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: c.dangerStrong, minimumSize: const Size(48, 40), padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm)),
                onPressed: () {
                  controller.remove(index, indexTimeSlot);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text("Remove Time".tr, style: DsTypography.labelSm.copyWith(color: c.dangerStrong)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _abbr(String day) => day.length <= 3 ? day : day.substring(0, 3);

  Future<TimeOfDay?> _selectTime(BuildContext context) async {
    FocusScope.of(context).requestFocus(FocusNode()); //remove focus
    final TimeOfDay? newTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (newTime != null) {
      return newTime;
    }
    return null;
  }
}

/// Minutes since midnight for "HH:mm", or null.
int? _minutes(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// Tappable start / end time chip.
class _TimeTile extends StatelessWidget {
  final IconData icon;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  const _TimeTile({required this.icon, required this.value, required this.placeholder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final has = value != null;
    return Semantics(
      button: true,
      label: has ? '$placeholder $value' : placeholder,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        borderRadius: DsRadius.brSm,
        child: InkWell(
          borderRadius: DsRadius.brSm,
          onTap: onTap,
          child: AnimatedContainer(
            duration: DsMotion.of(context, DsMotion.fast),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
            decoration: BoxDecoration(borderRadius: DsRadius.brSm, border: Border.all(color: has ? c.brand.withValues(alpha: 0.45) : c.border)),
            child: Row(
              children: [
                Icon(icon, size: 18, color: has ? c.brandStrong : c.textMuted),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: has ? t.titleSm.tabular : t.body.withColor(c.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 24-hour track with the open window highlighted.
class _DayBar extends StatelessWidget {
  final String? from;
  final String? to;
  const _DayBar({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final a = _minutes(from);
    final b = _minutes(to);
    final start = (a ?? 0) / 1440.0;
    final end = (b ?? (a ?? 0)) / 1440.0;
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: c.border, borderRadius: DsRadius.brPill))),
              if (a != null)
                AnimatedPositioned(
                  duration: DsMotion.of(context, DsMotion.slow),
                  curve: DsMotion.emphasized,
                  left: w * start,
                  width: (w * (end - start)).clamp(6.0, w).toDouble(),
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.brand(context), borderRadius: DsRadius.brPill)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Hero overview: one column per day showing its opening hours on a
/// 24-hour scale, plus totals.
class _WeekOverview extends StatelessWidget {
  final List<WorkingHours> hours;
  const _WeekOverview({required this.hours});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    int openDays = 0;
    int totalMinutes = 0;
    for (final d in hours) {
      if ((d.timeslot ?? []).isNotEmpty) openDays++;
      for (final s in d.timeslot ?? <Timeslot>[]) {
        final a = _minutes(s.from);
        final b = _minutes(s.to);
        if (a != null && b != null && b > a) totalMinutes += b - a;
      }
    }
    return DsCard.gradient(
      gradient: DsGradients.deep(context),
      padding: const EdgeInsets.all(DsSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Working Hours".tr, style: t.overline.withColor(Colors.white.withValues(alpha: 0.75))),
                    const DsGap(DsSpace.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DsAnimatedCounter(value: totalMinutes ~/ 60, style: t.metricLg.withColor(Colors.white)),
                        const DsGap(DsSpace.xs),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text("hrs / week".tr, style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.8))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              DsBadge(label: "$openDays/7 ${"Open".tr}", tone: DsTone.success, style: DsBadgeStyle.solid, icon: Icons.storefront_rounded, small: true),
            ],
          ),
          const DsGap(DsSpace.lg),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < hours.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        children: [
                          Expanded(child: _DayColumn(slots: hours[i].timeslot ?? const [])),
                          const DsGap(DsSpace.xs),
                          Text(
                            WorkingHoursScreen._abbr("${hours[i].day}".tr),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: t.labelSm.withColor(Colors.white.withValues(alpha: (hours[i].timeslot ?? []).isEmpty ? 0.5 : 0.95)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final List<Timeslot> slots;
  const _DayColumn({required this.slots});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cons) {
        final h = cons.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: DsRadius.brSm)),
            ),
            for (final s in slots)
              if (_minutes(s.from) != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: h * (_minutes(s.from)! / 1440.0),
                  height: (h * (((_minutes(s.to) ?? _minutes(s.from)!) - _minutes(s.from)!) / 1440.0)).clamp(4.0, h).toDouble(),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: DsMotion.of(context, DsMotion.slower),
                    curve: DsMotion.emphasized,
                    builder: (context, v, _) => Opacity(
                      opacity: v,
                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: DsRadius.brXs)),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
