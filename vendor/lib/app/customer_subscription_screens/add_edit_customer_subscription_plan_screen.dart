import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/add_edit_customer_subscription_plan_controller.dart';
import 'package:vendor/controller/customer_subscription_controller.dart';
import 'package:vendor/models/vendor_subscription_plan_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/utils/network_image_widget.dart';

/// Create / edit a Customer Subscription plan (sold by this store to its own customers).
class AddEditCustomerSubscriptionPlanScreen extends StatelessWidget {
  const AddEditCustomerSubscriptionPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AddEditCustomerSubscriptionPlanController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        const periods = [
          AddEditCustomerSubscriptionPlanController.periodMonthly,
          AddEditCustomerSubscriptionPlanController.periodAnnual,
          AddEditCustomerSubscriptionPlanController.periodCustom,
        ];
        return DsScaffold(
          title: controller.isEdit ? "Edit Customer Subscription Plan".tr : "Create Customer Subscription Plan".tr,
          body: DsAsync(
            isLoading: controller.isLoading.value,
            skeleton: const DsSkeletonForm(fields: 6),
            builder: (context) {
              final l = context.dsLayout;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.md, l.gutter, DsSpace.xxl),
                child: DsResponsive(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: DsFadeSlideIn.stagger([
                      // ---------------------------------------------- Photo
                      DsFormSection(
                        title: "Choose a image and upload here".tr,
                        icon: Icons.image_outlined,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: DsSpace.lg),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DottedBorder(
                                    options: RoundedRectDottedBorderOptions(
                                      radius: const Radius.circular(DsRadius.md),
                                      dashPattern: const [6, 6, 6, 6],
                                      color: c.borderStrong,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xl),
                                      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SvgPicture.asset('assets/icons/ic_folder.svg'),
                                          const DsGap(DsSpace.sm),
                                          Text("JPEG, PNG".tr, style: t.caption),
                                          const DsGap(DsSpace.md),
                                          DsButton.tonal(
                                            label: "Brows Image".tr,
                                            icon: Icons.upload_rounded,
                                            size: DsButtonSize.sm,
                                            onPressed: () async {
                                              buildBottomSheet(context, controller);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                AnimatedSize(
                                  duration: DsMotion.of(context, DsMotion.base),
                                  curve: DsMotion.standard,
                                  child: controller.images.isEmpty
                                      ? const SizedBox()
                                      : Padding(
                                          padding: const EdgeInsetsDirectional.only(start: DsSpace.md),
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: DsRadius.brMd,
                                                child: controller.images.first is XFile
                                                    ? Image.file(File(controller.images.first.path), fit: BoxFit.cover, width: 104, height: 104)
                                                    : NetworkImageWidget(
                                                        imageUrl: controller.images.first.toString(),
                                                        fit: BoxFit.cover,
                                                        width: 104,
                                                        height: 104,
                                                      ),
                                              ),
                                              PositionedDirectional(
                                                top: -6,
                                                end: -6,
                                                child: DsIconButton(
                                                  icon: Icons.close_rounded,
                                                  semanticLabel: 'Remove'.tr,
                                                  variant: DsIconButtonVariant.filled,
                                                  size: 28,
                                                  color: c.danger,
                                                  onPressed: () {
                                                    controller.images.clear();
                                                  },
                                                ),
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
                      // ---------------------------------------------- Plan details
                      DsFormSection(
                        title: "Plan".tr,
                        icon: Icons.card_membership_outlined,
                        children: [
                          DsTextField(label: 'Title'.tr, controller: controller.titleController.value, hint: 'e.g. Daily Bread — Monthly'.tr, maxLength: 60),
                          DsTextField(label: 'Description'.tr, controller: controller.descriptionController.value, hint: 'Description'.tr, maxLines: 4),
                          DsTextField(
                            label: 'Price'.tr,
                            controller: controller.priceController.value,
                            hint: 'Enter price'.tr,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            prefix: Padding(
                              padding: const EdgeInsetsDirectional.only(start: DsSpace.lg, end: DsSpace.sm),
                              child: Text(Constant.currencyModel?.symbol ?? '', style: t.titleSm.withColor(c.textPrimary)),
                            ),
                          ),
                          DsFieldLabel('Billing period'.tr),
                          DsSegmentedTabs(
                            segments: [DsSegment("Monthly".tr), DsSegment("Annual".tr), DsSegment("Custom".tr)],
                            index: periods.indexOf(controller.selectedPeriod.value).clamp(0, periods.length - 1),
                            onChanged: (i) => controller.selectedPeriod.value = periods[i],
                          ),
                          const DsGap(DsSpace.lg),
                          AnimatedSize(
                            duration: DsMotion.of(context, DsMotion.base),
                            curve: DsMotion.standard,
                            alignment: Alignment.topCenter,
                            child: controller.selectedPeriod.value == AddEditCustomerSubscriptionPlanController.periodCustom
                                ? DsTextField(
                                    label: 'Number of days'.tr,
                                    controller: controller.daysController.value,
                                    hint: 'e.g. 7'.tr,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    prefixIcon: Icons.calendar_today_outlined,
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                      // ---------------------------------------------- Schedule
                      _scheduleSection(context, controller),
                      // ---------------------------------------------- Status
                      DsCard.outlined(
                        margin: const EdgeInsets.only(bottom: DsSpace.lg),
                        padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.sm),
                        child: Row(
                          children: [
                            DsIconWell(
                              icon: controller.isEnable.value ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              tone: controller.isEnable.value ? DsTone.success : DsTone.neutral,
                              size: 40,
                            ),
                            const DsGap(DsSpace.md),
                            Expanded(child: Text("Enabled".tr, style: t.titleSm)),
                            Switch(
                              value: controller.isEnable.value,
                              onChanged: (value) {
                                controller.isEnable.value = value;
                              },
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save Plan".tr,
              icon: Icons.check_rounded,
              size: DsButtonSize.lg,
              expand: true,
              onPressed: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                controller.savePlan();
              },
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ Delivery schedule

  Widget _sectionTitle(BuildContext context, String text, {String? subtitle}) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: t.label.withColor(c.textPrimary)),
          if (subtitle != null) ...[const DsGap(DsSpace.xxs), Text(subtitle, style: t.caption)],
        ],
      ),
    );
  }

  Widget _scheduleSection(BuildContext context, AddEditCustomerSubscriptionPlanController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    final isWeekly = controller.frequency.value == VendorSubscriptionPlanModel.frequencyWeekly;
    InputDecoration fieldDecoration(String hint) => DsInputDecoration.of(
      context,
      hint: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 14),
    );
    final inputStyle = t.bodyStrong.withColor(c.textPrimary);

    return DsFormSection(
      title: "Delivery schedule".tr,
      icon: Icons.local_shipping_outlined,
      children: [
        _sectionTitle(context, "Items per delivery".tr, subtitle: "What one delivery contains, e.g. Baguette × 2".tr),
        ...controller.itemRows.map(
          (row) => Padding(
            key: ObjectKey(row),
            padding: const EdgeInsets.only(bottom: DsSpace.sm),
            child: DsFadeSlideIn(
              offset: const Offset(0, 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: row.nameController,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: c.brand,
                      style: inputStyle,
                      decoration: fieldDecoration("Item name".tr),
                    ),
                  ),
                  const DsGap(DsSpace.sm),
                  Expanded(
                    child: TextField(
                      controller: row.quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      cursorColor: c.brand,
                      textAlign: TextAlign.center,
                      style: inputStyle,
                      decoration: fieldDecoration("Qty".tr),
                    ),
                  ),
                  DsIconButton(
                    icon: Icons.remove_circle_outline_rounded,
                    semanticLabel: "Remove item".tr,
                    color: c.dangerStrong,
                    onPressed: () => controller.removeItemRow(row),
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsButton.tonal(label: "Add item".tr, icon: Icons.add_rounded, size: DsButtonSize.sm, onPressed: controller.addItemRow),
        ),
        const DsGap(DsSpace.xl),
        _sectionTitle(context, "Frequency".tr),
        DsSegmentedTabs(
          segments: [
            DsSegment("Daily".tr, icon: Icons.today_rounded),
            DsSegment("Weekly".tr, icon: Icons.date_range_rounded),
          ],
          index: isWeekly ? 1 : 0,
          onChanged: (i) => i == 0
              ? controller.setFrequency(VendorSubscriptionPlanModel.frequencyDaily)
              : controller.setFrequency(VendorSubscriptionPlanModel.frequencyWeekly),
        ),
        const DsGap(DsSpace.xl),
        _sectionTitle(context, "Delivery days".tr, subtitle: isWeekly ? "Pick the one day of the week to deliver".tr : "Untick the days without delivery".tr),
        Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.sm,
          children: VendorSubscriptionPlanModel.weekdays.map((day) {
            final selected = controller.deliveryDays.contains(day);
            return _DayChip(label: CustomerSubscriptionController.shortDay(day), selected: selected, onTap: () => controller.toggleDay(day));
          }).toList(),
        ),
        const DsGap(DsSpace.xl),
        _sectionTitle(context, "Delivery time slot".tr),
        Row(
          children: [
            Expanded(child: _timeField(context, "From".tr, controller.slotFrom)),
            const DsGap(DsSpace.md),
            Expanded(child: _timeField(context, "To".tr, controller.slotTo)),
          ],
        ),
        const DsGap(DsSpace.lg),
      ],
    );
  }

  Widget _timeField(BuildContext context, String label, RxString value) {
    final c = context.dsColors;
    final t = context.dsText;
    return Material(
      color: c.surfaceAlt,
      borderRadius: DsRadius.brMd,
      child: InkWell(
        borderRadius: DsRadius.brMd,
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: AddEditCustomerSubscriptionPlanController.parseTime(value.value) ?? const TimeOfDay(hour: 7, minute: 0),
            builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
          );
          if (picked != null) value.value = AddEditCustomerSubscriptionPlanController.formatTime(picked);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: c.brand),
                const DsGap(DsSpace.sm),
                Text("$label ", style: t.bodySm.withColor(c.textSecondary)),
                Expanded(
                  child: Text(
                    value.value.isEmpty ? "--:--" : value.value,
                    textAlign: TextAlign.end,
                    style: t.titleSm.tabular.withColor(value.value.isEmpty ? c.textMuted : c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future buildBottomSheet(BuildContext context, AddEditCustomerSubscriptionPlanController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DsSheet(
          title: "Please Select".tr,
          child: Row(
            children: [
              Expanded(
                child: _SourceTile(
                  icon: Icons.camera_alt_rounded,
                  label: "Camera".tr,
                  onTap: () => controller.pickFile(source: ImageSource.camera),
                ),
              ),
              const DsGap(DsSpace.md),
              Expanded(
                child: _SourceTile(
                  icon: Icons.photo_library_rounded,
                  label: "Gallery".tr,
                  onTap: () => controller.pickFile(source: ImageSource.gallery),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Round weekday toggle used for delivery days.
class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: DsPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: DsMotion.of(context, DsMotion.base),
          curve: DsMotion.standard,
          constraints: const BoxConstraints(minWidth: 52, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.brand : c.surface,
            borderRadius: DsRadius.brPill,
            border: Border.all(color: selected ? c.brand : c.border),
            boxShadow: selected ? DsShadows.glow(context) : null,
          ),
          child: Text(label, style: t.label.withColor(selected ? c.onBrand : c.textPrimary)),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DsCard.outlined(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(vertical: DsSpace.xl, horizontal: DsSpace.md),
      child: Column(
        children: [
          DsIconWell(icon: icon, size: 52, circle: true),
          const DsGap(DsSpace.sm),
          Text(label, style: context.dsText.label),
        ],
      ),
    );
  }
}
