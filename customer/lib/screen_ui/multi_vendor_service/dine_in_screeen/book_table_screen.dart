import 'package:customer/constant/constant.dart';
import 'package:customer/controllers/dine_in_restaurant_details_controller.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Archetype E — booking wizard on one page: party size, day, time slot,
/// occasion, who is booking and a note, with "Book Now" pinned to the bottom.
class BookTableScreen extends StatelessWidget {
  const BookTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DineInRestaurantDetailsController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final int guests = controller.noOfQuantity.value;
        final String selectedOccasion = controller.selectedOccasion.value;
        final bool firstVisit = controller.firstVisit.value;

        return DsScaffold(
          maxContentWidth: DsLayout.contentMax,
          appBar: DsAppBar(title: "Book Table".tr),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Book Now".tr,
              icon: Icons.event_available_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () async {
                controller.orderBook();
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.lg, DsSpace.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: DsFadeSlideIn.stagger([
                // ---------- party size ----------
                DsCard(
                  child: Row(
                    children: [
                      DsIconWell(icon: Icons.groups_rounded, tone: DsTone.brand),
                      const DsGap(DsSpace.md),
                      Expanded(child: Text("Numbers of Guests".tr, style: t.titleSm)),
                      const DsGap(DsSpace.md),
                      Container(
                        decoration: BoxDecoration(borderRadius: DsRadius.brPill, border: Border.all(color: c.border)),
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DsIconButton(
                              icon: Icons.remove,
                              semanticLabel: "Numbers of Guests".tr,
                              size: 34,
                              onPressed: () {
                                if (controller.noOfQuantity.value != 1) {
                                  controller.noOfQuantity.value -= 1;
                                }
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                              child: Text("$guests", maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSm.tabular),
                            ),
                            DsIconButton(
                              icon: Icons.add,
                              semanticLabel: "Numbers of Guests".tr,
                              size: 34,
                              color: c.brandStrong,
                              onPressed: () {
                                controller.noOfQuantity.value += 1;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------- day + slot ----------
                const DsGap(DsSpace.md),
                DsCard(
                  padding: const EdgeInsets.all(DsSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("When are you visiting?".tr, style: t.titleSm),
                      const DsGap(DsSpace.md),
                      SizedBox(
                        height: 104,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          physics: const BouncingScrollPhysics(),
                          itemCount: controller.dateList.length,
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: DsSpace.sm),
                              child: DsPressable(
                                onTap: () {
                                  controller.selectedDate.value = controller.dateList[index].date;
                                  controller.timeSet(controller.dateList[index].date);
                                },
                                // Selection is observable and this builder runs
                                // lazily, so it keeps its own observer.
                                child: Obx(() {
                                  final bool selected = controller.selectedDate.value == controller.dateList[index].date;
                                  return AnimatedContainer(
                                    duration: DsMotion.of(context, DsMotion.fast),
                                    width: 104,
                                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.md),
                                    decoration: BoxDecoration(
                                      color: selected ? c.brandSoft : c.surface,
                                      borderRadius: DsRadius.brMd,
                                      border: Border.all(color: selected ? c.brand : c.border, width: selected ? 1.6 : 1),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          Constant.calculateDifference(controller.dateList[index].date.toDate()) == 0
                                              ? "Today".tr
                                              : Constant.calculateDifference(controller.dateList[index].date.toDate()) == 1
                                              ? "Tomorrow".tr
                                              : DateFormat('EEE').format(controller.dateList[index].date.toDate()),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.caption.withColor(selected ? c.brandStrong : c.textMuted),
                                        ),
                                        Text(
                                          DateFormat('d MMM').format(controller.dateList[index].date.toDate()).toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: t.titleSm.tabular.withColor(selected ? c.brandStrong : c.textPrimary),
                                        ),
                                        const DsGap(DsSpace.xs),
                                        DsBadge(label: "${controller.dateList[index].discountPer}%".tr, tone: DsTone.brand, style: DsBadgeStyle.solid, small: true),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),
                      ),
                      const DsGap(DsSpace.lg),
                      Text("Select time slot and scroll to see offers".tr, style: t.titleSm),
                      const DsGap(DsSpace.md),
                      Container(
                        padding: const EdgeInsets.all(DsSpace.sm),
                        decoration: BoxDecoration(borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
                        child: Wrap(
                          spacing: DsSpace.sm,
                          runSpacing: DsSpace.sm,
                          children: <Widget>[
                            ...controller.timeSlotList.map((timeSlotList) {
                              final String label = DateFormat('hh:mm a').format(timeSlotList.time!);
                              final bool selected = controller.selectedTimeSlot.value == label;
                              return DsPressable(
                                onTap: () {
                                  controller.selectedTimeSlot.value = DateFormat('hh:mm a').format(timeSlotList.time!);
                                  controller.selectedTimeDiscount.value = timeSlotList.discountPer!;
                                  controller.selectedTimeDiscountType.value = timeSlotList.discountType!;
                                },
                                semanticLabel: label,
                                child: AnimatedContainer(
                                  duration: DsMotion.of(context, DsMotion.fast),
                                  constraints: const BoxConstraints(minHeight: 40),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
                                  decoration: BoxDecoration(
                                    color: selected ? c.brand : c.surfaceAlt,
                                    borderRadius: DsRadius.brPill,
                                  ),
                                  child: Text(label, style: t.label.tabular.withColor(selected ? c.onBrand : c.textSecondary)),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------- occasion ----------
                const DsGap(DsSpace.xl),
                Row(
                  children: [
                    Expanded(child: Text("Special Occasion".tr, style: t.titleSm)),
                    DsButton.ghost(
                      label: "Clear".tr,
                      size: DsButtonSize.sm,
                      onPressed: () {
                        controller.selectedOccasion.value = "";
                      },
                    ),
                  ],
                ),
                const DsGap(DsSpace.sm),
                DsCard(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < controller.occasionList.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                          title: Text(controller.getLocalizedOccasion(controller.occasionList[i]), style: t.bodyLg),
                          leading: Radio<String>(
                            visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                            value: controller.occasionList[i],
                            groupValue: selectedOccasion,
                            onChanged: (value) {
                              controller.selectedOccasion.value = value!;
                            },
                          ),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                        title: Text('Is this your first visit?'.tr, style: t.bodyLg),
                        leading: Checkbox(
                          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                          value: firstVisit,
                          onChanged: (value) {
                            controller.firstVisit.value = value!;
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------- who is booking ----------
                const DsGap(DsSpace.xl),
                Text("Personal Details".tr, style: t.titleSm),
                const DsGap(DsSpace.sm),
                DsCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      DsAvatar(imageUrl: Constant.userModel!.profilePictureURL.toString(), name: Constant.userModel!.fullName(), size: 50, ring: true),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Constant.userModel!.fullName(), style: t.titleSm),
                            const DsGap(DsSpace.xxs),
                            Text("${Constant.userModel!.email}", style: t.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------- notes ----------
                const DsGap(DsSpace.xl),
                DsTextField(
                  label: "Additional Requests".tr,
                  controller: controller.additionRequestController.value,
                  hint: 'Add message here....'.tr,
                  maxLines: 5,
                  bottomSpacing: 0,
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
