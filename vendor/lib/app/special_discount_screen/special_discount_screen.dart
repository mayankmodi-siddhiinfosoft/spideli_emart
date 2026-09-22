import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/special_discount_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class SpecialDiscountScreen extends StatelessWidget {
  const SpecialDiscountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: SpecialDiscountController(),
      builder: (controller) {
        return DsScaffold(
          title: "Special Discounts".tr,
          maxContentWidth: null,
          body: controller.isLoading.value
              ? const DsResponsive(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(DsSpace.lg),
                    child: Column(children: [DsSkeletonCard(height: 120), DsGap(DsSpace.lg), DsSkeletonCard(height: 56), DsGap(DsSpace.lg), DsSkeletonForm(fields: 4)]),
                  ),
                )
              : _SpecialDiscountBody(controller: controller, selectTime: _selectTime),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save Details".tr,
              icon: Icons.check_rounded,
              expand: true,
              size: DsButtonSize.lg,
              onPressed: () async {
                bool isEmptyField = false;
                for (var element in controller.specialDiscount) {
                  var emptyList = element.timeslot!.where(
                    (element) => element.discount!.isEmpty || element.from!.isEmpty || element.to!.isEmpty || (element.type == "percentage" && double.parse(element.discount.toString()) > 100),
                  );
                  if (element.timeslot!.isNotEmpty && emptyList.isNotEmpty && !isEmptyField) {
                    ShowToastDialog.showToast("Please enter valid details".tr);
                    isEmptyField = true;
                    continue;
                  }
                }

                if (!isEmptyField) {
                  controller.saveSpecialOffer();
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future<TimeOfDay?> _selectTime(BuildContext context) async {
    FocusScope.of(context).requestFocus(FocusNode()); //remove focus
    final TimeOfDay? newTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (newTime != null) {
      return newTime;
    }
    return null;
  }
}

/// Holds only the selected day tab (view state) and repaints after a time
/// is written into the model.
class _SpecialDiscountBody extends StatefulWidget {
  final SpecialDiscountController controller;
  final Future<TimeOfDay?> Function(BuildContext context) selectTime;
  const _SpecialDiscountBody({required this.controller, required this.selectTime});

  @override
  State<_SpecialDiscountBody> createState() => _SpecialDiscountBodyState();
}

class _SpecialDiscountBodyState extends State<_SpecialDiscountBody> {
  int _day = 0;

  SpecialDiscountController get controller => widget.controller;

  // DsObserve tracks isSpecialSwitched / specialDiscount read in this child's
  // build (the parent GetX cannot); setState still drives the day tab.
  @override
  Widget build(BuildContext context) => DsObserve(builder: _build);

  Widget _build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    if (controller.specialDiscount.isEmpty) {
      return DsEmptyState(icon: Icons.local_offer_outlined, title: "Special Discounts".tr);
    }
    final index = _day.clamp(0, controller.specialDiscount.length - 1);
    final day = controller.specialDiscount[index];
    final slots = day.timeslot!;
    int totalRules = 0;
    for (final d in controller.specialDiscount) {
      totalRules += d.timeslot?.length ?? 0;
    }

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: DsResponsive(
        padded: true,
        child: Padding(
          padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Master switch hero ───────────────────────────────────
              DsFadeSlideIn(
                child: DsCard.gradient(
                  padding: const EdgeInsets.all(DsSpace.lg),
                  child: Row(
                    children: [
                      DsIconWell(icon: Icons.percent_rounded, onBrand: true, size: 52, circle: true),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Special Discount amount".tr, style: t.titleSm.withColor(Colors.white)),
                            const DsGap(DsSpace.xs),
                            Text(
                              "$totalRules ${"Discount".tr} · ${controller.specialDiscount.where((e) => (e.timeslot ?? []).isNotEmpty).length}/7",
                              style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: controller.isSpecialSwitched.value,
                        activeTrackColor: Colors.white.withValues(alpha: 0.35),
                        activeThumbColor: Colors.white,
                        onChanged: (value) {
                          controller.isSpecialSwitched.value = value;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const DsGap(DsSpace.lg),
              // ── Day selector ─────────────────────────────────────────
              DsFadeSlideIn(
                index: 1,
                child: DsSegmentedTabs(
                  scrollable: true,
                  index: index,
                  onChanged: (i) => setState(() => _day = i),
                  segments: [for (final d in controller.specialDiscount) DsSegment("${d.day}".tr, count: (d.timeslot?.isNotEmpty ?? false) ? d.timeslot!.length : null)],
                ),
              ),
              AnimatedOpacity(
                duration: DsMotion.of(context, DsMotion.base),
                opacity: controller.isSpecialSwitched.value ? 1 : 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DsSectionHeader(
                      title: "${day.day}".tr,
                      icon: Icons.event_outlined,
                      trailing: DsButton.tonal(
                        label: "Add".tr,
                        icon: Icons.add_rounded,
                        size: DsButtonSize.sm,
                        onPressed: () {
                          controller.addValue(index);
                        },
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: DsMotion.of(context, DsMotion.base),
                      switchInCurve: DsMotion.standard,
                      child: slots.isEmpty
                          ? DsCard.outlined(
                              key: ValueKey('empty_$index'),
                              child: DsEmptyState(
                                compact: true,
                                icon: Icons.sell_outlined,
                                title: "No discounts for this day".tr,
                                actionLabel: "Add".tr,
                                actionIcon: Icons.add_rounded,
                                onAction: () {
                                  controller.addValue(index);
                                },
                              ),
                            )
                          : Column(
                              key: ValueKey('day_$index'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (int indexTimeSlot = 0; indexTimeSlot < slots.length; indexTimeSlot++)
                                  DsFadeSlideIn(
                                    index: indexTimeSlot,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: DsSpace.md),
                                      child: _rule(context, c, t, index, indexTimeSlot),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rule(BuildContext context, DsColors c, DsTextTheme t, int index, int indexTimeSlot) {
    final slot = controller.specialDiscount[index].timeslot![indexTimeSlot];
    final isDineIn = slot.discountType == "dinein";
    return DsCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Accent rail
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: DecoratedBox(decoration: BoxDecoration(gradient: DsGradients.tone(context, isDineIn ? DsTone.info : DsTone.brand))),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.lg, DsSpace.md, DsSpace.md, DsSpace.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    DsIconWell(icon: isDineIn ? Icons.restaurant_rounded : Icons.delivery_dining_rounded, tone: isDineIn ? DsTone.info : DsTone.brand, size: 36),
                    const DsGap(DsSpace.sm),
                    Expanded(child: Text("${"Discount".tr} ${indexTimeSlot + 1}", style: t.label)),
                    DsBadge(label: (isDineIn ? "Dine-In Discount" : "Delivery Discount").tr, tone: isDineIn ? DsTone.info : DsTone.brand, small: true),
                  ],
                ),
                const DsGap(DsSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: _TimeChip(
                        value: slot.from!.isEmpty ? null : slot.from.toString(),
                        placeholder: 'Start Time'.tr,
                        onTap: () async {
                          TimeOfDay? startTime = await widget.selectTime(context);
                          controller.specialDiscount[index].timeslot![indexTimeSlot].from = DateFormat('HH:mm')
                              .format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, startTime!.hour, startTime.minute));
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                      child: Icon(Icons.arrow_forward_rounded, size: 18, color: c.textMuted),
                    ),
                    Expanded(
                      child: _TimeChip(
                        value: slot.to!.isEmpty ? null : slot.to.toString(),
                        placeholder: 'End Time'.tr,
                        onTap: () async {
                          TimeOfDay? endTimeOfDay = await widget.selectTime(context);

                          if (endTimeOfDay != null) {
                            DateTime endTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, endTimeOfDay.hour, endTimeOfDay.minute);
                            DateTime time = DateFormat("HH:mm").parse(controller.specialDiscount[index].timeslot![indexTimeSlot].from.toString());
                            DateTime startTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, time.hour, time.minute);

                            if (startTime.isAfter(endTime)) {
                              ShowToastDialog.showToast("Please select Valid Time".tr);
                            } else {
                              if (endTimeOfDay.format(context).toString() == "12:00 AM") {
                                controller.specialDiscount[index].timeslot![indexTimeSlot].to = DateFormat('HH:mm')
                                    .format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59));
                              } else {
                                controller.specialDiscount[index].timeslot![indexTimeSlot].to = DateFormat('HH:mm')
                                    .format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, endTimeOfDay.hour, endTimeOfDay.minute));
                              }
                            }
                          }
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: ValueKey('discount_${index}_$indexTimeSlot'),
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.next,
                        initialValue: controller.specialDiscount[index].timeslot![indexTimeSlot].discount,
                        onChanged: (text) {
                          controller.specialDiscount[index].timeslot![indexTimeSlot].discount = text;
                        },
                        keyboardType: TextInputType.number,
                        style: t.titleSm.tabular,
                        cursorColor: c.brand,
                        decoration: DsInputDecoration.of(
                          context,
                          hint: 'Discount'.tr,
                          prefixIcon: Icons.sell_outlined,
                          suffix: Padding(
                            padding: const EdgeInsetsDirectional.only(end: DsSpace.md),
                            child: Text(
                              controller.specialDiscount[index].timeslot![indexTimeSlot].type == "percentage" ? "%" : "${Constant.currencyModel!.symbol}".tr,
                              style: t.titleSm.withColor(c.brandStrong),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const DsGap(DsSpace.sm),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('unit_${index}_${indexTimeSlot}_${slot.type}'),
                        isExpanded: true,
                        dropdownColor: c.surfaceRaised,
                        borderRadius: DsRadius.brMd,
                        hint: Text('Select Type'.tr, style: t.body.withColor(c.textMuted)),
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                        decoration: DsInputDecoration.of(context),
                        initialValue: controller.specialDiscount[index].timeslot![indexTimeSlot].type == "amount" ? Constant.currencyModel!.symbol : "%",
                        onChanged: (value) {
                          controller.changeValue(index, indexTimeSlot, value == Constant.currencyModel!.symbol! ? "amount" : "percentage");
                          // if (value == Constant.currencyModel!.symbol!) {
                          //   controller.specialDiscount[index].timeslot![indexTimeSlot].type = "amount";
                          // } else {
                          //   controller.specialDiscount[index].timeslot![indexTimeSlot].type = "percentage";
                          // }
                          controller.update();
                        },
                        style: t.bodyStrong,
                        items: controller.type.map((item) {
                          return DropdownMenuItem<String>(value: item, child: Text(item.tr.toString()));
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const DsGap(DsSpace.md),
                DropdownButtonFormField<String>(
                  key: ValueKey('kind_${index}_${indexTimeSlot}_${slot.discountType}'),
                  isExpanded: true,
                  hint: Text('Select Type'.tr, style: t.body.withColor(c.textMuted)),
                  dropdownColor: c.surfaceRaised,
                  borderRadius: DsRadius.brMd,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                  decoration: DsInputDecoration.of(context, prefixIcon: isDineIn ? Icons.restaurant_outlined : Icons.delivery_dining_outlined),
                  initialValue: controller.specialDiscount[index].timeslot![indexTimeSlot].discountType == "dinein" ? "Dine-In Discount" : "Delivery Discount",
                  onChanged: (value) {
                    if (value == "Dine-In Discount") {
                      controller.specialDiscount[index].timeslot![indexTimeSlot].discountType = "dinein";
                    } else {
                      controller.specialDiscount[index].timeslot![indexTimeSlot].discountType = "delivery";
                    }
                    controller.update();
                    if (mounted) setState(() {});
                  },
                  style: t.bodyStrong,
                  items: controller.discountType.map((item) {
                    return DropdownMenuItem<String>(value: item.tr, child: Text(item.toString().tr));
                  }).toList(),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: c.dangerStrong, minimumSize: const Size(48, 44)),
                    onPressed: () {
                      controller.remove(index, indexTimeSlot);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text("Remove Discount".tr, style: t.labelSm.withColor(c.dangerStrong)),
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

class _TimeChip extends StatelessWidget {
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  const _TimeChip({required this.value, required this.placeholder, required this.onTap});

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
        color: has ? c.brandSoft : c.surfaceAlt,
        borderRadius: DsRadius.brSm,
        child: InkWell(
          borderRadius: DsRadius.brSm,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: has ? c.brandStrong : c.textMuted),
                const DsGap(DsSpace.sm),
                Expanded(
                  child: Text(value ?? placeholder, maxLines: 1, overflow: TextOverflow.ellipsis, style: has ? t.titleSm.tabular.withColor(c.brandStrong) : t.body.withColor(c.textMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
