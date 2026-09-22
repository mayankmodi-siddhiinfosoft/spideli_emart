import 'package:datetime_picker_formfield_new/datetime_picker_formfield.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:vendor/app/add_restaurant_screen/widgets/form_media_widgets.dart';
import 'package:vendor/app/offer_screens/widgets/coupon_ticket.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/controller/add_edit_coupon_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

class AddEditOfferScreen extends StatelessWidget {
  const AddEditOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AddEditCouponController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final isPercent = controller.selectCouponType.value == "Percentage" || controller.selectCouponType.value == "Percent";
        return DsScaffold(
          title: Get.arguments == null ? "Create Offer".tr : "Edit Offer".tr,
          maxContentWidth: null,
          body: controller.isLoading.value
              ? const DsResponsive(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(DsSpace.lg),
                    child: Column(children: [DsSkeletonCard(height: 130), DsGap(DsSpace.lg), DsSkeletonForm(fields: 5)]),
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
                          _LivePreview(controller: controller, isPercent: isPercent),
                          const DsGap(DsSpace.lg),
                          // ── Artwork ─────────────────────────────────────
                          DsFormSection(
                            title: "Offer image".tr,
                            icon: Icons.image_outlined,
                            children: [
                              AnimatedSwitcher(
                                duration: DsMotion.of(context, DsMotion.base),
                                child: controller.images.isEmpty
                                    ? FormUploadZone(
                                        key: const ValueKey('zone'),
                                        title: "Choose a image and upload here".tr,
                                        caption: "JPEG, PNG".tr,
                                        buttonLabel: "Brows Image".tr,
                                        icon: Icons.add_photo_alternate_outlined,
                                        onPressed: () async {
                                          buildBottomSheet(context, controller);
                                        },
                                      )
                                    : Row(
                                        key: const ValueKey('thumbs'),
                                        children: [
                                          for (int index = 0; index < controller.images.length; index++)
                                            Padding(
                                              padding: const EdgeInsetsDirectional.only(end: DsSpace.sm),
                                              child: FormMediaThumb(
                                                size: 96,
                                                onRemove: () {
                                                  controller.images.removeAt(index);
                                                },
                                                child: FormPickedImage(source: controller.images[index], width: 96, height: 96),
                                              ),
                                            ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("JPEG, PNG".tr, style: t.caption),
                                                const DsGap(DsSpace.sm),
                                                DsButton.tonal(
                                                  label: "Brows Image".tr,
                                                  icon: Icons.swap_horiz_rounded,
                                                  size: DsButtonSize.sm,
                                                  onPressed: () async {
                                                    buildBottomSheet(context, controller);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                          // ── Coupon details ──────────────────────────────
                          DsFormSection(
                            title: "Coupon details".tr,
                            icon: Icons.confirmation_number_outlined,
                            children: [
                              FormInput(label: 'Title'.tr, controller: controller.titleController.value, hint: 'Title'.tr, maxLength: 30, prefixIcon: Icons.title_rounded),
                              FormInput(label: 'Coupon Code'.tr, controller: controller.couponCodeController.value, hint: 'Coupon Code'.tr, prefixIcon: Icons.qr_code_rounded, bottomSpacing: 0),
                            ],
                          ),
                          // ── Discount ────────────────────────────────────
                          DsFormSection(
                            title: 'Select Coupon Type'.tr,
                            icon: Icons.discount_outlined,
                            children: [
                              DsSegmentedTabs(
                                segments: [
                                  DsSegment('Fix Price'.tr, icon: Icons.payments_outlined),
                                  DsSegment('Percentage'.tr, icon: Icons.percent_rounded),
                                ],
                                index: isPercent ? 1 : 0,
                                onChanged: (i) {
                                  if (i == 0) {
                                    controller.selectCouponType.value = "Fix Price";
                                  } else {
                                    controller.selectCouponType.value = "Percentage";
                                  }
                                },
                              ),
                              const DsGap(DsSpace.lg),
                              FormInput(
                                controller: controller.priceController.value,
                                hint: 'Enter price'.tr,
                                keyboardType: TextInputType.number,
                                bottomSpacing: 0,
                                prefix: FormAffix(
                                  controller.selectCouponType.value == "Percentage" || controller.selectCouponType.value == "Percent" ? "%" : "${Constant.currencyModel!.symbol}".tr,
                                ),
                              ),
                            ],
                          ),
                          // ── Validity & visibility ───────────────────────
                          DsFormSection(
                            title: 'Expires at'.tr,
                            icon: Icons.event_available_outlined,
                            children: [
                              DateTimeField(
                                format: DateFormat("MMM dd, yyyy"),
                                controller: controller.selectDateController.value,
                                textInputAction: TextInputAction.done,
                                style: t.bodyStrong,
                                decoration: DsInputDecoration.of(
                                  context,
                                  hint: "Select date".tr,
                                  prefixIcon: Icons.calendar_month_outlined,
                                  suffix: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                                ),
                                onShowPicker: (context, currentValue) {
                                  return showDatePicker(
                                    context: context,
                                    firstDate: DateTime.now(), // ✅ only today & future
                                    initialDate: currentValue ?? DateTime.now(), // ✅ reopen with last selected
                                    lastDate: DateTime(2100),
                                  );
                                },
                              ),
                              const DsGap(DsSpace.lg),
                              FormSwitchTile(
                                title: "Active".tr,
                                icon: Icons.toggle_on_outlined,
                                tone: DsTone.success,
                                value: controller.isActive.value,
                                onChanged: (value) {
                                  controller.isActive.value = value;
                                },
                              ),
                              const DsGap(DsSpace.sm),
                              FormSwitchTile(
                                title: "Public".tr,
                                icon: Icons.public_rounded,
                                tone: DsTone.info,
                                value: controller.isPublic.value,
                                onChanged: (value) {
                                  controller.isPublic.value = value;
                                },
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
              label: "Save Coupon".tr,
              icon: Icons.check_rounded,
              expand: true,
              size: DsButtonSize.lg,
              onPressed: () async {
                controller.saveCoupon();
              },
            ),
          ),
        );
      },
    );
  }

  Future buildBottomSheet(BuildContext context, AddEditCouponController controller) {
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

/// Ticket preview that follows the form as the vendor types (display only).
class _LivePreview extends StatelessWidget {
  final AddEditCouponController controller;
  final bool isPercent;
  const _LivePreview({required this.controller, required this.isPercent});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller.titleController.value,
        controller.couponCodeController.value,
        controller.priceController.value,
        controller.selectDateController.value,
      ]),
      builder: (context, _) {
        final price = controller.priceController.value.text.trim();
        String headline;
        if (price.isEmpty) {
          headline = isPercent ? "% ${"Off".tr}" : "${Constant.currencyModel?.symbol ?? ''} ${"Off".tr}";
        } else if (isPercent) {
          headline = "$price % ${"Off".tr}";
        } else {
          String amount;
          try {
            amount = Constant.amountShow(amount: price);
          } catch (_) {
            amount = price;
          }
          headline = "$amount ${"Off".tr}";
        }
        final code = controller.couponCodeController.value.text.trim();
        final title = controller.titleController.value.text.trim();
        final date = controller.selectDateController.value.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpace.sm, left: DsSpace.xs),
              child: Text("Preview".tr.toUpperCase(), style: t.overline),
            ),
            CouponTicket(
              stubGradient: controller.isActive.value ? null : DsGradients.tone(context, DsTone.neutral),
              stub: AnimatedSwitcher(
                duration: DsMotion.of(context, DsMotion.fast),
                child: CouponStubLabel(key: ValueKey(headline), text: headline, icon: isPercent ? Icons.percent_rounded : Icons.payments_outlined),
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (controller.images.isNotEmpty) ...[
                        ClipRRect(borderRadius: DsRadius.brSm, child: FormPickedImage(source: controller.images.first, width: 40, height: 40)),
                        const DsGap(DsSpace.sm),
                      ],
                      Expanded(
                        child: Text(title.isEmpty ? 'Title'.tr : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: title.isEmpty ? t.titleSm.withColor(c.textMuted) : t.titleSm),
                      ),
                    ],
                  ),
                  const DsGap(DsSpace.sm),
                  DottedBorder(
                    options: RoundedRectDottedBorderOptions(radius: const Radius.circular(DsRadius.sm), dashPattern: const [5, 4], color: c.brand.withValues(alpha: 0.6)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                      decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brSm),
                      child: Text(
                        code.isEmpty ? 'Coupon Code'.tr : code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.label.copyWith(color: c.brandStrong, letterSpacing: 1.1),
                      ),
                    ),
                  ),
                  const DsGap(DsSpace.sm),
                  Wrap(
                    spacing: DsSpace.xs,
                    runSpacing: DsSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (date.isNotEmpty) DsBadge(label: date, tone: DsTone.neutral, icon: Icons.event_outlined, small: true),
                      DsBadge(label: "Active".tr, tone: controller.isActive.value ? DsTone.success : DsTone.neutral, small: true),
                      if (controller.isPublic.value) DsBadge(label: "Public".tr, tone: DsTone.info, icon: Icons.public_rounded, small: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
