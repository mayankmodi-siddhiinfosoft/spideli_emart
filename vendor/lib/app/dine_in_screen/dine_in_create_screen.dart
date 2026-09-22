import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:vendor/app/add_restaurant_screen/widgets/form_media_widgets.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/dine_in_create_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class DineInCreateScreen extends StatelessWidget {
  const DineInCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: DineInCreateController(),
      builder: (controller) {
        final t = context.dsText;
        return DsScaffold(
          title: "Add Dine in".tr,
          maxContentWidth: null,
          body: controller.isLoading.value
              ? const DsResponsive(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(DsSpace.lg),
                    child: Column(children: [DsSkeletonCard(height: 96), DsGap(DsSpace.lg), DsSkeletonForm(fields: 4)]),
                  ),
                )
              : SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: DsResponsive(
                    padded: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: DsFadeSlideIn.stagger([
                          // ── Availability hero ───────────────────────────
                          AnimatedContainer(
                            duration: DsMotion.of(context, DsMotion.slow),
                            curve: DsMotion.standard,
                            padding: const EdgeInsets.all(DsSpace.lg),
                            decoration: BoxDecoration(
                              borderRadius: DsRadius.brXl,
                              gradient: controller.active.value ? DsGradients.brand(context) : DsGradients.tone(context, DsTone.neutral),
                              boxShadow: controller.active.value ? DsShadows.glow(context) : DsShadows.sm(context),
                            ),
                            child: Row(
                              children: [
                                DsIconWell(icon: Icons.table_restaurant_rounded, onBrand: true, size: 52, circle: true),
                                const DsGap(DsSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Add Dine in".tr, style: t.overline.withColor(Colors.white.withValues(alpha: 0.8))),
                                      const DsGap(DsSpace.xs),
                                      Text("Active".tr, style: t.title.withColor(Colors.white)),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: controller.active.value,
                                  activeTrackColor: Colors.white.withValues(alpha: 0.35),
                                  activeThumbColor: Colors.white,
                                  onChanged: (value) {
                                    controller.active.value = value;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const DsGap(DsSpace.lg),
                          // ── Photos ──────────────────────────────────────
                          DsFormSection(
                            title: "Dine-in photos".tr,
                            icon: Icons.photo_library_outlined,
                            trailing: controller.images.isEmpty ? null : DsBadge(label: '${controller.images.length}', tone: DsTone.brand, small: true),
                            children: [
                              FormUploadZone(
                                title: "Choose a image and upload here".tr,
                                caption: "JPEG, PNG".tr,
                                buttonLabel: "Brows Image".tr,
                                icon: Icons.add_a_photo_outlined,
                                compact: controller.images.isNotEmpty,
                                minHeight: controller.images.isEmpty ? 160 : 0,
                                onPressed: () async {
                                  buildBottomSheet(context, controller);
                                },
                              ),
                              if (controller.images.isNotEmpty) const DsGap(DsSpace.md),
                              if (controller.images.isNotEmpty)
                                SizedBox(
                                  height: 88,
                                  child: ListView.separated(
                                    itemCount: controller.images.length,
                                    scrollDirection: Axis.horizontal,
                                    separatorBuilder: (_, _) => const DsGap(DsSpace.sm),
                                    itemBuilder: (context, index) {
                                      return DsFadeSlideIn(
                                        index: index,
                                        offset: const Offset(12, 0),
                                        child: FormMediaThumb(
                                          size: 88,
                                          onRemove: () {
                                            controller.images.removeAt(index);
                                          },
                                          child: FormPickedImage(source: controller.images[index], width: 88, height: 88),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                          // ── Pricing ─────────────────────────────────────
                          DsFormSection(
                            title: 'Price (approx for 2 per.)'.tr,
                            icon: Icons.people_alt_outlined,
                            children: [
                              FormInput(
                                controller: controller.priceController.value,
                                hint: 'Enter price for 2 per.'.tr,
                                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                textInputAction: TextInputAction.done,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                prefix: FormAffix("${Constant.currencyModel!.symbol}".tr),
                                bottomSpacing: 0,
                              ),
                            ],
                          ),
                          // ── Timing ──────────────────────────────────────
                          DsFormSection(
                            title: 'Timing'.tr,
                            icon: Icons.schedule_rounded,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _ClockTile(
                                      controller: controller.startDateController.value,
                                      placeholder: '6:00 AM',
                                      icon: Icons.wb_twilight_rounded,
                                      onTap: () async {
                                        TimeOfDay? pickedTime = await showTimePicker(initialTime: TimeOfDay.now(), context: context);

                                        if (pickedTime != null) {
                                          controller.startDateController.value.text = pickedTime.format(context); //set the value
                                        }
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm),
                                    child: DsIconWell(icon: Icons.arrow_forward_rounded, tone: DsTone.neutral, size: 32, circle: true),
                                  ),
                                  Expanded(
                                    child: _ClockTile(
                                      controller: controller.endDateDateController.value,
                                      placeholder: '9:00 PM',
                                      icon: Icons.nights_stay_outlined,
                                      onTap: () async {
                                        TimeOfDay? pickedTime = await showTimePicker(initialTime: TimeOfDay.now(), context: context);
                                        if (pickedTime != null) {
                                          controller.endDateDateController.value.text = pickedTime.format(context);

                                          DateTime startDate = DateFormat("hh:mm a").parse(controller.startDateController.value.text.toString());
                                          DateTime endDate = DateFormat("hh:mm a").parse(controller.endDateDateController.value.text.toString());

                                          if (endDate.isAfter(startDate)) {
                                            controller.isTimeValid.value = true;
                                          } else {
                                            controller.isTimeValid.value = false;
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedSize(
                                duration: DsMotion.of(context, DsMotion.base),
                                alignment: Alignment.topCenter,
                                child: controller.isTimeValid.value
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: DsSpace.md),
                                        child: DsInlineAlert(tone: DsTone.warning, message: "Please select Valid Time".tr),
                                      ),
                              ),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
          bottomBar: DsStickyBar(
            child: DsButton.primary(
              label: "Save Details".tr,
              icon: Icons.check_rounded,
              expand: true,
              size: DsButtonSize.lg,
              onPressed: () async {
                if (controller.priceController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please Enter Price".tr);
                } else if (controller.startDateController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please select start time".tr);
                } else if (controller.endDateDateController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please select end time".tr);
                } else {
                  controller.saveDetails();
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future buildBottomSheet(BuildContext context, DineInCreateController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return MediaSourceSheet(
              onCamera: () => controller.pickFile(source: ImageSource.camera),
              onGallery: () => controller.pickFile(source: ImageSource.gallery),
            );
          },
        );
      },
    );
  }
}

/// Large tappable clock face showing the time held in [controller].
class _ClockTile extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;

  const _ClockTile({required this.controller, required this.placeholder, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final has = controller.text.isNotEmpty;
        return Semantics(
          button: true,
          label: has ? controller.text : placeholder,
          excludeSemantics: true,
          child: DsCard.outlined(
            onTap: onTap,
            borderColor: has ? c.brand.withValues(alpha: 0.5) : null,
            padding: const EdgeInsets.all(DsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: has ? c.brandStrong : c.textMuted),
                const DsGap(DsSpace.sm),
                AnimatedSwitcher(
                  duration: DsMotion.of(context, DsMotion.fast),
                  child: Text(
                    has ? controller.text : placeholder,
                    key: ValueKey(controller.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: has ? t.title.tabular : t.title.withColor(c.textDisabled),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
