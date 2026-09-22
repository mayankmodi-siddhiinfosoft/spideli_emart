import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/app/add_restaurant_screen/widgets/form_media_widgets.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/theme_controller.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:vendor/controller/add_advertisement_controller.dart';
import 'package:vendor/models/advertisement_model.dart';
import 'package:vendor/utils/network_image_widget.dart';
import 'package:vendor/widget/video_widget.dart';

class AddAdvertisementScreen extends StatelessWidget {
  const AddAdvertisementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
      init: AddAdvertisementController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final isVideo = controller.selectedAdvertisementType.value == 'Video Promotion';
        return DsScaffold(
          title: "Your Advertisement".tr,
          maxContentWidth: null,
          body: controller.isLoading.value
              ? const DsResponsive(
                  child: SingleChildScrollView(padding: EdgeInsets.all(DsSpace.lg), child: DsSkeletonForm(fields: 6)),
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
                          // ── Campaign ────────────────────────────────────
                          DsFormSection(
                            title: 'Campaign details'.tr,
                            icon: Icons.campaign_outlined,
                            children: [
                              FormInput(label: 'Advertisement Title (Default)'.tr, controller: controller.advertisementTitleController.value, hint: 'Enter Title here'.tr, prefixIcon: Icons.title_rounded),
                              FormInput(label: 'Description:'.tr, controller: controller.descriptionController.value, maxLines: 5, hint: 'Enter the description'.tr, bottomSpacing: 0),
                            ],
                          ),
                          // ── Format ──────────────────────────────────────
                          DsFormSection(
                            title: "Advertisement Type".tr,
                            subtitle: controller.selectedAdvertisementType.value.isEmpty ? 'Select Type'.tr : null,
                            icon: Icons.dashboard_customize_outlined,
                            children: [
                              DsAdaptiveGrid(
                                minItemWidth: 140,
                                maxColumns: 2,
                                children: [
                                  for (final name in controller.advertisementType)
                                    _TypeOption(
                                      label: name.toString(),
                                      icon: name.contains('Video') ? Icons.smart_display_outlined : Icons.storefront_outlined,
                                      selected: controller.selectedAdvertisementType.value == name,
                                      onTap: () {
                                        controller.selectedAdvertisementType.value = name;
                                        controller.update();
                                      },
                                    ),
                                ],
                              ),
                              AnimatedSize(
                                duration: DsMotion.of(context, DsMotion.base),
                                alignment: Alignment.topCenter,
                                child: Visibility(
                                  visible: controller.selectedAdvertisementType.value != 'Video Promotion',
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: DsSpace.lg),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        DsFieldLabel("Show Review & Ratings".tr),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _CheckTile(
                                                label: "Review".tr,
                                                icon: Icons.rate_review_outlined,
                                                value: controller.isReviewSelected.value,
                                                onChanged: (bool? value) {
                                                  controller.isReviewSelected.value = value!;
                                                },
                                              ),
                                            ),
                                            const DsGap(DsSpace.sm),
                                            Expanded(
                                              child: _CheckTile(
                                                label: "Ratings".tr,
                                                icon: Icons.star_outline_rounded,
                                                value: controller.isRatingsSelected.value,
                                                onChanged: (bool? value) {
                                                  controller.isRatingsSelected.value = value!;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // ── Schedule ────────────────────────────────────
                          DsFormSection(
                            title: 'Validity:'.tr,
                            icon: Icons.date_range_outlined,
                            children: [
                              FormInput(
                                readOnly: true,
                                onTap: () {
                                  dateValidityPicker(context, controller, isDark);
                                },
                                controller: controller.validityController.value,
                                hint: 'Select the date durations'.tr,
                                prefixIcon: Icons.calendar_month_outlined,
                                suffix: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                                bottomSpacing: 0,
                              ),
                            ],
                          ),
                          // ── Creative ────────────────────────────────────
                          DsFormSection(
                            title: "Upload Related Files".tr,
                            icon: Icons.perm_media_outlined,
                            children: [
                              if (!isVideo)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 116,
                                          height: 116,
                                          child: controller.profileImage.value.path.isEmpty && controller.profileImageString.value == ''
                                              ? _EmptySlot(
                                                  icon: Icons.account_circle_outlined,
                                                  onTap: () {
                                                    buildProfileBottomSheet(context, controller);
                                                  },
                                                )
                                              : FormMediaThumb(
                                                  size: 116,
                                                  onRemove: () {
                                                    controller.profileImageString.value = '';
                                                    controller.profileImage.value = XFile('');
                                                  },
                                                  child: controller.profileImage.value.runtimeType == XFile && controller.profileImageString.value == ''
                                                      ? Image.file(File(controller.profileImage.value.path), fit: BoxFit.cover, width: 116, height: 116)
                                                      : NetworkImageWidget(imageUrl: controller.profileImageString.value, fit: BoxFit.cover, width: 116, height: 116),
                                                ),
                                        ),
                                        const DsGap(DsSpace.lg),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("Profile Image (Ratio - 1:1)".tr, style: t.label),
                                              const DsGap(DsSpace.xs),
                                              Text("Supports: PNG, JPG, JPEG, WEBP".tr, style: t.caption),
                                              const DsGap(DsSpace.md),
                                              DsButton.tonal(
                                                label: "Brows Image".tr,
                                                icon: Icons.add_photo_alternate_outlined,
                                                size: DsButtonSize.sm,
                                                onPressed: () async {
                                                  buildProfileBottomSheet(context, controller);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const DsGap(DsSpace.lg),
                                    controller.coverImage.value.path.isEmpty && controller.coverImageString.value == ''
                                        ? FormUploadZone(
                                            title: "Upload Cover (Ratio - 2:1)".tr,
                                            caption: "Supports: PNG, JPG, JPEG, WEBP".tr,
                                            buttonLabel: "Brows Image".tr,
                                            icon: Icons.panorama_outlined,
                                            onPressed: () async {
                                              buildCoverBottomSheet(context, controller);
                                            },
                                          )
                                        : AspectRatio(
                                            aspectRatio: 2 / 1,
                                            child: _FilledMedia(
                                              onRemove: () {
                                                controller.coverImageString.value = '';
                                                controller.coverImage.value = XFile('');
                                              },
                                              child: controller.coverImage.value.runtimeType == XFile && controller.coverImageString.value == ''
                                                  ? Image.file(File(controller.coverImage.value.path), fit: BoxFit.cover)
                                                  : NetworkImageWidget(imageUrl: controller.coverImageString.value, fit: BoxFit.cover),
                                            ),
                                          ),
                                  ],
                                ),
                              if (controller.selectedAdvertisementType.value == 'Video Promotion')
                                controller.thumbnailFile.value.path.isEmpty && controller.thumbnailFileString.value == ''
                                    ? FormUploadZone(
                                        title: "Upload Video (Ratio - 2:1)".tr,
                                        caption: "Supports: Mp4 and Webm".tr,
                                        buttonLabel: "Upload Video".tr,
                                        icon: Icons.video_library_outlined,
                                        onPressed: () async {
                                          onCameraClick(context, controller);
                                        },
                                      )
                                    : AspectRatio(
                                        aspectRatio: 2 / 1,
                                        child: _FilledMedia(
                                          onRemove: () {
                                            controller.thumbnailFileString.value = '';
                                            controller.thumbnailFile.value = XFile('');
                                          },
                                          child: LayoutBuilder(
                                            builder: (context, cons) => controller.thumbnailFile.value.runtimeType == XFile && controller.thumbnailFileString.value == ''
                                                ? VideoAdvWidget(width: cons.maxWidth, url: File(controller.thumbnailFile.value.path))
                                                : VideoAdvWidget(width: cons.maxWidth, url: controller.thumbnailFileString.value),
                                          ),
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
            child: Row(
              children: [
                if (controller.advertisementModel.value.id == null) ...[
                  Expanded(
                    child: DsButton.secondary(
                      label: "Reset".tr,
                      icon: Icons.restart_alt_rounded,
                      expand: true,
                      onPressed: () async {
                        controller.reset();
                      },
                    ),
                  ),
                  const DsGap(DsSpace.md),
                ],
                Expanded(
                  flex: 2,
                  child: DsButton.primary(
                    label: controller.advertisementModel.value.id != null ? "Edit & Save".tr : "Submit".tr,
                    icon: Icons.send_rounded,
                    expand: true,
                    onPressed: () async {
                      AdvertisementModel? model = await controller.saveAdvDetails();
                      if (model?.id != null) {
                        if (controller.advertisementModel.value.id == null || controller.isCopy.value == true) {
                          Get.back(result: "Save");
                        } else {
                          Get.back(result: true);
                          Get.back(result: true);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future buildProfileBottomSheet(BuildContext context, AddAdvertisementController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return MediaSourceSheet(
              onCamera: () => controller.profilePickFile(source: ImageSource.camera),
              onGallery: () => controller.profilePickFile(source: ImageSource.gallery),
            );
          },
        );
      },
    );
  }

  Future buildCoverBottomSheet(BuildContext context, AddAdvertisementController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return MediaSourceSheet(
              onCamera: () => controller.coverPickFile(source: ImageSource.camera),
              onGallery: () => controller.coverPickFile(source: ImageSource.gallery),
            );
          },
        );
      },
    );
  }
}

/// Selectable format card (Store / Video promotion).
class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: DsCard.outlined(
        onTap: onTap,
        semanticLabel: label,
        color: selected ? c.brandSoft : null,
        borderColor: selected ? c.brand : null,
        padding: const EdgeInsets.all(DsSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DsIconWell(icon: icon, tone: selected ? DsTone.brand : DsTone.neutral, size: 40),
                const Spacer(),
                AnimatedSwitcher(
                  duration: DsMotion.of(context, DsMotion.fast),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selected),
                    color: selected ? c.brand : c.borderStrong,
                  ),
                ),
              ],
            ),
            const DsGap(DsSpace.md),
            Text(label, style: selected ? t.label.withColor(c.brandStrong) : t.label),
          ],
        ),
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _CheckTile({required this.label, required this.icon, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Material(
      color: value ? c.brandSoft : c.surfaceAlt,
      borderRadius: DsRadius.brMd,
      child: InkWell(
        borderRadius: DsRadius.brMd,
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsetsDirectional.only(start: DsSpace.md, end: DsSpace.xs),
          child: Row(
            children: [
              Icon(icon, size: 18, color: value ? c.brandStrong : c.textMuted),
              const DsGap(DsSpace.sm),
              Expanded(child: Text(label, style: t.label)),
              Checkbox(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _EmptySlot({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Material(
      color: c.surfaceAlt,
      borderRadius: DsRadius.brLg,
      child: InkWell(
        borderRadius: DsRadius.brLg,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: DsRadius.brLg, border: Border.all(color: c.borderStrong)),
          child: Center(child: Icon(icon, size: 40, color: c.textMuted)),
        ),
      ),
    );
  }
}

class _FilledMedia extends StatelessWidget {
  final Widget child;
  final VoidCallback onRemove;
  const _FilledMedia({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return ClipRRect(
      borderRadius: DsRadius.brLg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          PositionedDirectional(
            top: DsSpace.xs,
            end: DsSpace.xs,
            child: DsIconButton(icon: Icons.delete_outline_rounded, semanticLabel: 'Delete'.tr, variant: DsIconButtonVariant.filled, color: c.dangerStrong, size: 36, onPressed: onRemove),
          ),
        ],
      ),
    );
  }
}

String prettyDuration(double duration) {
  var seconds = duration / 1000.round();
  return '$seconds';
}

Future dateValidityPicker(BuildContext context, AddAdvertisementController controller, bool isDarkMode) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) {
      final c = context.dsColors;
      return DsSheet(
        title: 'Validity:'.tr,
        actions: Row(
          children: [
            Expanded(
              child: DsButton.secondary(
                label: "Cancel".tr,
                expand: true,
                onPressed: () async {
                  Get.back();
                  controller.validityController.value.text = '';
                },
              ),
            ),
            const DsGap(DsSpace.md),
            Expanded(
              child: DsButton.primary(
                label: "Apply".tr,
                expand: true,
                onPressed: () async {
                  Get.back();
                  controller.selectValidityDate();
                },
              ),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.sm, DsSpace.md, 0),
        child: SizedBox(
          height: 330,
          child: SfDateRangePicker(
            backgroundColor: c.surfaceRaised,
            headerStyle: DateRangePickerHeaderStyle(backgroundColor: c.surfaceRaised, textStyle: DsTypography.titleSm.copyWith(color: c.textPrimary)),
            monthViewSettings: DateRangePickerMonthViewSettings(viewHeaderStyle: DateRangePickerViewHeaderStyle(textStyle: DsTypography.labelSm.copyWith(color: c.textMuted))),
            monthCellStyle: DateRangePickerMonthCellStyle(
              textStyle: DsTypography.body.copyWith(color: c.textPrimary),
              disabledDatesTextStyle: DsTypography.body.copyWith(color: c.textDisabled),
              todayTextStyle: DsTypography.label.copyWith(color: c.brandStrong),
            ),
            selectionColor: c.brand,
            startRangeSelectionColor: c.brand,
            endRangeSelectionColor: c.brand,
            rangeSelectionColor: c.brandSoft,
            todayHighlightColor: c.brand,
            selectionTextStyle: DsTypography.label.copyWith(color: c.onBrand),
            rangeTextStyle: DsTypography.body.copyWith(color: c.textPrimary),
            onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
              if (args.value is PickerDateRange) {
                controller.startValidityDate.value = args.value.startDate;
                controller.endValidityDate.value = args.value.endDate;
              }
            },
            selectionMode: DateRangePickerSelectionMode.range,
            minDate: DateTime.now(),
            maxDate: DateTime.now().add(Duration(days: 5 * 365)),
            initialSelectedRange: PickerDateRange(controller.startValidityDate.value, controller.endValidityDate.value),
          ),
        ),
      );
    },
  );
}

final ImagePicker imagePickerForVideo = ImagePicker();

void onCameraClick(BuildContext context, AddAdvertisementController controller) {
  final action = CupertinoActionSheet(
    message: Text('Send Video'.tr, style: TextStyle(fontSize: 15.0)),
    actions: <Widget>[
      CupertinoActionSheetAction(
        isDefaultAction: false,
        onPressed: () async {
          Navigator.pop(context);
          XFile? galleryVideo = await imagePickerForVideo.pickVideo(source: ImageSource.gallery);
          if (galleryVideo != null) {
            controller.thumbnailFile.value = XFile('');
            controller.thumbnailFile.value = galleryVideo;
          }
        },
        child: Text('Choose Video File'.tr),
      ),
    ],
    cancelButton: CupertinoActionSheetAction(
      child: Text('Cancel'.tr),
      onPressed: () {
        Navigator.pop(context);
      },
    ),
  );
  showCupertinoModalPopup(context: context, builder: (context) => action);
}
