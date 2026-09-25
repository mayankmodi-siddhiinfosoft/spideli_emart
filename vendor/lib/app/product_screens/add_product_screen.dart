import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendor/models/brands_model.dart';
import 'package:vendor/constant/constant.dart';
import 'package:vendor/constant/show_toast_dialog.dart';
import 'package:vendor/controller/add_product_controller.dart';
import 'package:vendor/models/attributes_model.dart';
import 'package:vendor/models/product_model.dart';
import 'package:vendor/models/vendor_category_model.dart';
import 'package:vendor/themes/ds/ds.dart';
import 'package:vendor/themes/text_field_widget.dart';
import 'package:vendor/utils/fire_store_utils.dart';
import 'package:vendor/widget/animated_border_container.dart';
import 'package:vendor/widget/dimensions.dart';

/// Add / edit product (archetype D – form / wizard).
///
/// One long form split into five wizard steps (Media, Details, Pricing,
/// Options, Extras). A sticky step header shows where the user is and jumps
/// to a step on tap; a sticky save bar shows form completion. Every field,
/// validation and the save flow are unchanged.
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // Presentation-only state for the wizard header.
  final ScrollController _formScrollController = ScrollController();
  final List<GlobalKey> _stepKeys = List.generate(5, (_) => GlobalKey());
  final GlobalKey _viewportKey = GlobalKey();
  final ValueNotifier<int> _activeStep = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _formScrollController.addListener(_syncActiveStep);
  }

  @override
  void dispose() {
    _formScrollController.removeListener(_syncActiveStep);
    _formScrollController.dispose();
    _activeStep.dispose();
    super.dispose();
  }

  List<String> get _stepLabels => ['Media'.tr, 'Details'.tr, 'Pricing'.tr, 'Options'.tr, 'Extras'.tr];

  /// Highlights the step whose section is at the top of the viewport.
  void _syncActiveStep() {
    if (!_formScrollController.hasClients) return;
    final RenderObject? viewportObject = _viewportKey.currentContext?.findRenderObject();
    if (viewportObject is! RenderBox || !viewportObject.attached) return;
    final double top = viewportObject.localToGlobal(Offset.zero).dy + 120;
    int active = 0;
    for (int i = 0; i < _stepKeys.length; i++) {
      final RenderObject? box = _stepKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy <= top) active = i;
    }
    final ScrollPosition position = _formScrollController.position;
    if (position.maxScrollExtent > 0 && position.pixels >= position.maxScrollExtent - 4) active = _stepKeys.length - 1;
    if (_activeStep.value != active) _activeStep.value = active;
  }

  void _jumpToStep(int index) {
    final BuildContext? stepContext = _stepKeys[index].currentContext;
    if (stepContext == null) return;
    _activeStep.value = index;
    Scrollable.ensureVisible(stepContext, duration: DsMotion.of(context, DsMotion.slow), curve: DsMotion.emphasized, alignment: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GetX(
      init: AddProductController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        final bool isDark = c.isDark;

        // Completion (display only): image, title, description, category, price, quantity.
        final bool hasImage = controller.images.isNotEmpty;
        final bool hasCategory = controller.selectedProductCategory.value.id != null;
        final List<TextEditingController> trackedFields = [
          controller.productTitleController.value,
          controller.productDescriptionController.value,
          controller.regularPriceController.value,
          controller.productQuantityController.value,
        ];
        double completion() {
          int done = (hasImage ? 1 : 0) + (hasCategory ? 1 : 0);
          for (final field in trackedFields) {
            if (field.text.trim().isNotEmpty) done++;
          }
          return done / (trackedFields.length + 2);
        }

        return DsScaffold(
          title: controller.productModel.value.id == null ? "Add Product".tr : "Edit product".tr,
          maxContentWidth: null,
          body: controller.isLoading.value
              ? const DsResponsive(child: DsSkeletonForm(fields: 7))
              : Column(
                  children: [
                    _WizardHeader(
                      labels: _stepLabels,
                      activeStep: _activeStep,
                      onStepTap: _jumpToStep,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: _viewportKey,
                        controller: _formScrollController,
                        padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.huge),
                        child: DsResponsive(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ───────────── Step 1 · Media ─────────────
                              KeyedSubtree(
                                key: _stepKeys[0],
                                child: DsFadeSlideIn(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _StepHeading(index: 0, total: 5, title: 'Media'.tr),
                                      DsInlineAlert(
                                        tone: DsTone.warning,
                                        icon: Icons.percent_rounded,
                                        message:
                                            "Product prices include a 15% admin commission. For instance, a \$100 product will cost \$115 for the customer. 15% will be applied automatically.".tr,
                                      ),
                                      const DsGap(DsSpace.lg),
                                      DsFormSection(
                                        title: 'Product images'.tr,
                                        subtitle: "JPEG, PNG".tr,
                                        icon: Icons.photo_camera_back_outlined,
                                        children: [
                                          DottedBorder(
                                            options: RoundedRectDottedBorderOptions(
                                              radius: const Radius.circular(DsRadius.md),
                                              color: c.borderStrong,
                                              strokeWidth: 1.4,
                                              dashPattern: const [6, 4],
                                              padding: EdgeInsets.zero,
                                            ),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.xxl),
                                              decoration: BoxDecoration(color: c.surfaceAlt.withValues(alpha: 0.6), borderRadius: DsRadius.brMd),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const DsIconWell(icon: Icons.cloud_upload_outlined, size: 56, circle: true),
                                                  const DsGap(DsSpace.md),
                                                  Text("Choose a image and upload here".tr, textAlign: TextAlign.center, style: t.label),
                                                  const DsGap(DsSpace.xs),
                                                  Text("JPEG, PNG".tr, style: t.caption),
                                                  const DsGap(DsSpace.lg),
                                                  DsButton.tonal(
                                                    label: "Brows Image".tr,
                                                    icon: Icons.add_photo_alternate_outlined,
                                                    size: DsButtonSize.sm,
                                                    onPressed: () async {
                                                      buildBottomSheet(context, controller);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const DsGap(DsSpace.md),
                                          controller.images.isEmpty
                                              ? const SizedBox()
                                              : Padding(
                                                  padding: const EdgeInsets.only(bottom: DsSpace.md),
                                                  child: Wrap(
                                                    spacing: DsSpace.sm,
                                                    runSpacing: DsSpace.sm,
                                                    children: List.generate(controller.images.length, (index) {
                                                      return _imageThumb(controller, index);
                                                    }),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ───────────── Step 2 · Details ─────────────
                              KeyedSubtree(
                                key: _stepKeys[1],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _StepHeading(index: 1, total: 5, title: 'Details'.tr),
                                    DsFormSection(
                                      title: 'Basic details'.tr,
                                      icon: Icons.edit_note_rounded,
                                      trailing: Constant.openAIStatus == false
                                          ? null
                                          : _aiButton(() {
                                              if (controller.productTitleController.value.text.trim().isEmpty) {
                                                ShowToastDialog.showToast("Please enter product title to generate".tr);
                                                return;
                                              }
                                              controller.generateTitleAndDescription();
                                            }),
                                      children: [
                                        AnimatedBorderContainer(
                                          padding: controller.isTitleGenerated.value
                                              ? const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeLarge)
                                              : EdgeInsets.zero,
                                          isLoading: controller.isTitleGenerated.value,
                                          color: c.surface,
                                          child: Column(
                                            children: [
                                              TextFieldWidget(title: 'Product Title'.tr, controller: controller.productTitleController.value, hintText: 'Enter product title'.tr),
                                              TextFieldWidget(
                                                title: 'Product Description'.tr,
                                                controller: controller.productDescriptionController.value,
                                                hintText: 'Enter short description here....'.tr,
                                                maxLine: 5,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    DsFormSection(
                                      title: 'Category & variants'.tr,
                                      subtitle: "Attributes and Prices".tr,
                                      icon: Icons.category_outlined,
                                      trailing: Constant.openAIStatus == false
                                          ? null
                                          : _aiButton(() {
                                              if (controller.productTitleController.value.text.trim().isEmpty) {
                                                ShowToastDialog.showToast("Please enter product title to generate".tr);
                                                return;
                                              }
                                              if (controller.productDescriptionController.value.text.trim().isEmpty) {
                                                ShowToastDialog.showToast("Please enter product description to generate".tr);
                                                return;
                                              }
                                              controller.generateVariationData();
                                            }),
                                      children: [
                                        AnimatedBorderContainer(
                                          padding: controller.generateVariationDataGenerated.value
                                              ? const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeLarge)
                                              : EdgeInsets.zero,
                                          isLoading: controller.generateVariationDataGenerated.value,
                                          color: c.surface,
                                          child: _categoryAndAttributes(controller, isDark),
                                        ),
                                        const DsGap(DsSpace.md),
                                      ],
                                    ),
                                    Visibility(
                                      visible: Constant.selectedSection != null && Constant.selectedSection!.serviceTypeFlag == "ecommerce-service",
                                      child: DsFormSection(
                                        title: 'Brand & type'.tr,
                                        icon: Icons.sell_outlined,
                                        children: [
                                          DsFieldLabel("Brand".tr),
                                          DropdownButtonFormField<BrandsModel>(
                                            hint: Text('Select brand'.tr, style: t.body.withColor(c.textMuted)),
                                            dropdownColor: c.surfaceRaised,
                                            borderRadius: DsRadius.brMd,
                                            isExpanded: true,
                                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                                            decoration: DsInputDecoration.of(context),
                                            initialValue: controller.selectedBrands.value.id == null ? null : controller.selectedBrands.value,
                                            onChanged: (value) {
                                              controller.selectedBrands.value = value!;
                                              controller.update();
                                            },
                                            style: t.bodyStrong,
                                            items: controller.brandsList.map((item) {
                                              return DropdownMenuItem<BrandsModel>(value: item, child: Text(item.title.toString()));
                                            }).toList(),
                                          ),
                                          const DsGap(DsSpace.lg),
                                          Constant.selectedSection != null && Constant.selectedSection!.serviceTypeFlag == "ecommerce-service"
                                              ? _digitalProduct(controller)
                                              : const SizedBox(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ───────────── Step 3 · Pricing ─────────────
                              KeyedSubtree(
                                key: _stepKeys[2],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _StepHeading(index: 2, total: 5, title: 'Pricing'.tr),
                                    DsFormSection(
                                      title: 'Price & stock'.tr,
                                      icon: Icons.payments_outlined,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: TextFieldWidget(
                                                title: 'Regular Price'.tr,
                                                controller: controller.regularPriceController.value,
                                                hintText: 'Enter Regular Price'.tr,
                                                textInputAction: TextInputAction.done,
                                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                                textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                                prefix: _currencyPrefix("${Constant.currencyModel!.symbol}".tr),
                                              ),
                                            ),
                                            const DsGap(DsSpace.md),
                                            Expanded(
                                              child: TextFieldWidget(
                                                title: 'Discounted Price'.tr,
                                                controller: controller.discountedPriceController.value,
                                                hintText: 'Enter Discounted Price'.tr,
                                                textInputAction: TextInputAction.done,
                                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                                textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                                prefix: _currencyPrefix("${Constant.currencyModel!.symbol}".tr),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Live price preview
                                        Container(
                                          padding: const EdgeInsets.all(DsSpace.md),
                                          decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brMd),
                                          child: Row(
                                            children: [
                                              Icon(Icons.visibility_outlined, size: 18, color: c.brandStrong),
                                              const DsGap(DsSpace.sm),
                                              Expanded(child: Text("Your item Price will be display like this. ".tr, style: t.bodySm.withColor(c.textPrimary))),
                                              const DsGap(DsSpace.sm),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    (controller.discountPrice.value == 0.0
                                                            ? Constant.amountShow(amount: "0.0")
                                                            : Constant.amountShow(amount: controller.discountPrice.value.toString()))
                                                        .tr,
                                                    style: t.titleSm.withColor(c.brandStrong).tabular,
                                                  ),
                                                  Text(Constant.amountShow(amount: controller.regularPrice.value.toString()), style: t.caption.strike),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const DsGap(DsSpace.xl),
                                        TextFieldWidget(
                                          title: 'Quantity'.tr,
                                          controller: controller.productQuantityController.value,
                                          hintText: 'Enter Quantity'.tr,
                                          textInputAction: TextInputAction.done,
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9-.]'))],
                                          textInputType: TextInputType.text,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: DsSpace.md),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.all_inclusive_rounded, size: 16, color: c.warningStrong),
                                              const DsGap(DsSpace.sm),
                                              Expanded(child: Text("-1 to your product quantity is unlimited".tr, style: t.caption.withColor(c.warningStrong))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    DsFormSection(
                                      title: 'Sale type & wholesale'.tr,
                                      icon: Icons.storefront_outlined,
                                      children: [_buildWholesaleSection(controller, isDark), const DsGap(DsSpace.md)],
                                    ),
                                  ],
                                ),
                              ),

                              // ───────────── Step 4 · Options ─────────────
                              KeyedSubtree(
                                key: _stepKeys[3],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _StepHeading(index: 3, total: 5, title: 'Options'.tr),
                                    Constant.selectedSection!.isProductDetails == false
                                        ? const SizedBox()
                                        : DsFormSection(
                                            title: "About Cal., Grams, prot.& Fats".tr,
                                            icon: Icons.local_dining_outlined,
                                            children: [
                                              AnimatedBorderContainer(
                                                padding: controller.generateIngredientsGenerated.value
                                                    ? const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeLarge)
                                                    : EdgeInsets.zero,
                                                isLoading: controller.generateIngredientsGenerated.value,
                                                color: c.surface,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Expanded(
                                                          child: TextFieldWidget(
                                                            title: 'Calories'.tr,
                                                            controller: controller.caloriesController.value,
                                                            hintText: 'Enter Calories'.tr,
                                                            textInputAction: TextInputAction.done,
                                                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                                            textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                                          ),
                                                        ),
                                                        const DsGap(DsSpace.md),
                                                        Expanded(
                                                          child: TextFieldWidget(
                                                            title: 'Grams'.tr,
                                                            controller: controller.gramsController.value,
                                                            hintText: 'Enter Grams'.tr,
                                                            textInputAction: TextInputAction.done,
                                                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                                            textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Expanded(
                                                          child: TextFieldWidget(
                                                            title: 'Protein'.tr,
                                                            controller: controller.proteinController.value,
                                                            hintText: 'Enter Protein'.tr,
                                                            textInputAction: TextInputAction.done,
                                                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                                            textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                                          ),
                                                        ),
                                                        const DsGap(DsSpace.md),
                                                        Expanded(
                                                          child: TextFieldWidget(
                                                            title: 'Fats'.tr,
                                                            controller: controller.fatsController.value,
                                                            hintText: 'Enter Fats'.tr,
                                                            textInputAction: TextInputAction.done,
                                                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                                            textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                    if (Constant.selectedSection?.isProductDetails == true)
                                      DsFormSection(
                                        title: "Product Type and Takeaway options".tr,
                                        icon: Icons.eco_outlined,
                                        children: [
                                          _switchTile(
                                            label: "Pure veg.".tr,
                                            icon: Icons.eco_rounded,
                                            tone: DsTone.success,
                                            value: controller.isPureVeg.value,
                                            onChanged: (value) {
                                              if (controller.isNonVeg.value == true) {
                                                controller.isPureVeg.value = value;
                                              }
                                              if (controller.isPureVeg.value == true) {
                                                controller.isNonVeg.value = false;
                                              }
                                            },
                                          ),
                                          Divider(height: 1, color: c.divider),
                                          _switchTile(
                                            label: "Non veg.".tr,
                                            icon: Icons.set_meal_outlined,
                                            tone: DsTone.danger,
                                            value: controller.isNonVeg.value,
                                            onChanged: (value) {
                                              if (controller.isPureVeg.value == true) {
                                                controller.isNonVeg.value = value;
                                              }

                                              if (controller.isNonVeg.value == true) {
                                                controller.isPureVeg.value = false;
                                              }
                                            },
                                          ),
                                          const DsGap(DsSpace.sm),
                                        ],
                                      ),

                                    // The separate 'Enable Takeaway option' switch is replaced by the
                                    // Delivery / Takeaway choice below, which writes the same field.
                                    DsFormSection(
                                      title: "Available for".tr,
                                      icon: Icons.local_shipping_outlined,
                                      children: [_buildFulfilmentSection(controller, isDark), const DsGap(DsSpace.md)],
                                    ),
                                  ],
                                ),
                              ),

                              // ───────────── Step 5 · Extras ─────────────
                              KeyedSubtree(
                                key: _stepKeys[4],
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _StepHeading(index: 4, total: 5, title: "Specifications and Addons".tr),
                                    DsFormSection(
                                      title: "Specifications".tr,
                                      icon: Icons.list_alt_rounded,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (Constant.openAIStatus != false)
                                            _aiButton(() {
                                              if (controller.productTitleController.value.text.trim().isEmpty) {
                                                ShowToastDialog.showToast("Please enter product title to generate".tr);
                                                return;
                                              }
                                              if (controller.productDescriptionController.value.text.trim().isEmpty) {
                                                ShowToastDialog.showToast("Please enter product description to generate".tr);
                                                return;
                                              }
                                              controller.generateSpecification();
                                            }),
                                          DsIconButton(
                                            icon: Icons.add_rounded,
                                            semanticLabel: "Specifications".tr,
                                            variant: DsIconButtonVariant.tonal,
                                            onPressed: () {
                                              controller.specificationList.add(ProductSpecificationModel(lable: '', value: ''));
                                            },
                                          ),
                                        ],
                                      ),
                                      children: [
                                        AnimatedBorderContainer(
                                          padding: controller.generateSpecificationGenerated.value
                                              ? const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeLarge)
                                              : EdgeInsets.zero,
                                          isLoading: controller.generateSpecificationGenerated.value,
                                          color: c.surface,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            itemCount: controller.specificationList.length,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemBuilder: (context, index) {
                                              final item = controller.specificationList[index];
                                              return Padding(
                                                key: ValueKey(item), // 👈 ensures correct rebuild
                                                padding: const EdgeInsets.only(bottom: DsSpace.xs),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: TextFieldWidget(
                                                        key: ValueKey('label_$index'),
                                                        // 👈 important
                                                        initialValue: item.lable,
                                                        title: 'Title'.tr,
                                                        hintText: 'Enter Title'.tr,
                                                        onchange: (value) {
                                                          controller.specificationList[index].lable = value;
                                                        },
                                                        controller: null,
                                                      ),
                                                    ),
                                                    const DsGap(DsSpace.sm),
                                                    Expanded(
                                                      child: TextFieldWidget(
                                                        key: ValueKey('value_$index'),
                                                        // 👈 important
                                                        initialValue: item.value,
                                                        title: 'Value'.tr,
                                                        hintText: 'Enter Value'.tr,
                                                        onchange: (value) {
                                                          controller.specificationList[index].value = value;
                                                        },
                                                        controller: null,
                                                      ),
                                                    ),
                                                    _removeRowButton(() {
                                                      controller.specificationList.removeAt(index);
                                                    }),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        if (controller.specificationList.isEmpty) _emptyRowsHint(),
                                        const DsGap(DsSpace.md),
                                      ],
                                    ),
                                    DsFormSection(
                                      title: "Addons".tr,
                                      icon: Icons.add_circle_outline_rounded,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (Constant.openAIStatus != false)
                                            _aiButton(() {
                                              if (controller.productTitleController.value.text.trim().isEmpty) {
                                                ShowToastDialog.showToast("Please enter product title to generate".tr);
                                                return;
                                              }
                                              if (controller.productDescriptionController.value.text.trim().isEmpty) {
                                                ShowToastDialog.showToast("Please enter product description to generate".tr);
                                                return;
                                              }
                                              controller.generateAddOns();
                                            }),
                                          DsIconButton(
                                            icon: Icons.add_rounded,
                                            semanticLabel: "Addons".tr,
                                            variant: DsIconButtonVariant.tonal,
                                            onPressed: () {
                                              controller.addonsList.add(ProductSpecificationModel(lable: '', value: ''));
                                            },
                                          ),
                                        ],
                                      ),
                                      children: [
                                        AnimatedBorderContainer(
                                          padding: controller.generateAddOnsGenerated.value
                                              ? const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeLarge)
                                              : EdgeInsets.zero,
                                          isLoading: controller.generateAddOnsGenerated.value,
                                          color: c.surface,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: controller.addonsList.length,
                                            padding: EdgeInsets.zero,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemBuilder: (context, index) {
                                              final addon = controller.addonsList[index];
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: DsSpace.xs),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: TextFieldWidget(
                                                        key: ValueKey('addon_label_$index'),
                                                        // 👈 unique key per textfield
                                                        title: 'Title'.tr,
                                                        hintText: 'Enter Title'.tr,
                                                        initialValue: addon.lable,
                                                        onchange: (value) {
                                                          controller.addonsList[index].lable = value;
                                                        },
                                                        controller: null,
                                                      ),
                                                    ),
                                                    const DsGap(DsSpace.sm),
                                                    Expanded(
                                                      child: TextFieldWidget(
                                                        key: ValueKey('addon_value_$index'),
                                                        // 👈 unique key per textfield
                                                        title: 'Price'.tr,
                                                        hintText: 'Enter Price'.tr,
                                                        initialValue: addon.value,
                                                        prefix: _currencyPrefix("${Constant.currencyModel!.symbol}".tr),
                                                        textInputAction: TextInputAction.done,
                                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
                                                        textInputType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                                                        onchange: (value) {
                                                          controller.addonsList[index].value = value;
                                                        },
                                                        controller: null,
                                                      ),
                                                    ),
                                                    _removeRowButton(() {
                                                      print("Remove addon at index: $index");
                                                      controller.addonsList.removeAt(index);
                                                    }),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        if (controller.addonsList.isEmpty) _emptyRowsHint(),
                                        const DsGap(DsSpace.md),
                                      ],
                                    ),
                                    if (controller.taxList.isNotEmpty && Constant.taxScope == 'product')
                                      DsFormSection(
                                        title: 'Assign Tax'.tr,
                                        icon: Icons.receipt_long_outlined,
                                        children: [
                                          Obx(
                                            () => ListView.builder(
                                              shrinkWrap: true,
                                              padding: EdgeInsets.zero,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: controller.taxList.length,
                                              itemBuilder: (context, index) {
                                                final tax = controller.taxList[index];
                                                return CheckboxListTile(
                                                  value: tax.isSelected,
                                                  contentPadding: EdgeInsets.zero,
                                                  visualDensity: VisualDensity.compact,
                                                  onChanged: (value) {
                                                    controller.toggleSelection(index, value!);
                                                  },
                                                  title: Text(
                                                    "${tax.title} (${tax.type == "fix" ? Constant.amountShow(amount: tax.tax) : "${tax.tax}%"})",
                                                    style: t.bodyStrong,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          const DsGap(DsSpace.sm),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          bottomBar: controller.isLoading.value
              ? null
              : DsStickyBar(
                  child: Row(
                    children: [
                      ListenableBuilder(
                        listenable: Listenable.merge(trackedFields),
                        builder: (context, _) {
                          final double value = completion();
                          return DsProgressRing(
                            value: value,
                            size: 48,
                            stroke: 5,
                            tone: value >= 1 ? DsTone.success : DsTone.brand,
                            semanticLabel: 'Completion'.tr,
                            center: Text('${(value * 100).round()}%', style: DsTypography.labelSm.copyWith(color: c.textPrimary, fontSize: 11)),
                          );
                        },
                      ),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: DsButton.primary(
                          label: "Save Details".tr,
                          icon: Icons.check_rounded,
                          expand: true,
                          onPressed: () async {
                            print("========${controller.vendorModel.value.subscriptionPlan?.itemLimit.runtimeType}");

                            // if ((Constant.isSubscriptionModelApplied == true || Constant.adminCommission?.isEnabled == true) &&
                            //     controller.vendorModel.value.subscriptionPlan?.itemLimit != '-1' &&
                            //     int.parse(controller.vendorModel.value.subscriptionPlan?.itemLimit != null && controller.vendorModel.value.subscriptionPlan?.itemLimit.toString() != "null"
                            //             ? "${controller.vendorModel.value.subscriptionPlan?.itemLimit}"
                            //             : '0') <=
                            //         controller.productList.length) {
                            //   ShowToastDialog.showToast("Your current subscription plan has reached its maximum product limit. Upgrade now to add more products.".tr);
                            //   return;
                            // }

                            if (controller.itemAttributes.value != null) {
                              if (controller.itemAttributes.value!.attributes != null && controller.itemAttributes.value!.attributes!.isNotEmpty) {
                                for (var element in controller.itemAttributes.value!.attributes!) {
                                  if (element.attributeOptions!.isEmpty) {
                                    ShowToastDialog.showToast(
                                      "${"Please add a attribute".tr} (${controller.selectedAttributesList.where((p0) => p0.id == element.attributeId).first.title}) ${"value".tr}",
                                    );
                                    return;
                                  }
                                }
                              }

                              if (controller.itemAttributes.value!.variants != null && controller.itemAttributes.value!.variants!.isNotEmpty) {
                                for (var element in controller.itemAttributes.value!.variants!) {
                                  if (double.parse(element.variantPrice!.toString()) == 0) {
                                    ShowToastDialog.showToast("Please enter a valid variant price".tr);
                                    return;
                                  }
                                }
                              }
                            }

                            print("==> ${controller.itemAttributes.value!.toJson()}");

                            controller.saveDetails();
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

  // ───────────────────────────── building blocks ─────────────────────────────

  Widget _aiButton(VoidCallback onPressed) {
    return DsButton.ghost(label: "Generate".tr, icon: Icons.auto_awesome, size: DsButtonSize.sm, onPressed: onPressed);
  }

  Widget _currencyPrefix(String symbol) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 14),
      child: Text(symbol, style: DsTypography.titleSm.copyWith(color: c.textSecondary)),
    );
  }

  Widget _removeRowButton(VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: DsIconButton(icon: Icons.remove_circle_outline_rounded, semanticLabel: 'Remove'.tr, color: context.dsColors.danger, onPressed: onPressed),
    );
  }

  Widget _emptyRowsHint() {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpace.md),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
      child: Row(
        children: [
          Icon(Icons.add_rounded, size: 18, color: c.textMuted),
          const DsGap(DsSpace.sm),
          Expanded(child: Text('Tap + to add a row'.tr, style: DsTypography.bodySm.copyWith(color: c.textSecondary))),
        ],
      ),
    );
  }

  Widget _switchTile({required String label, required IconData icon, required DsTone tone, required bool value, required ValueChanged<bool> onChanged}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          DsIconWell(icon: icon, tone: tone, size: 36),
          const DsGap(DsSpace.md),
          Expanded(child: Text(label, style: context.dsText.bodyStrong)),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _imageThumb(AddProductController controller, int index) {
    final c = context.dsColors;
    return Semantics(
      button: true,
      label: 'Remove'.tr,
      child: InkWell(
        borderRadius: DsRadius.brMd,
        onTap: () {
          controller.images.removeAt(index);
        },
        child: SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            children: [
              Positioned.fill(
                child: controller.images[index].runtimeType == XFile
                    ? ClipRRect(borderRadius: DsRadius.brMd, child: Image.file(File(controller.images[index].path), fit: BoxFit.cover, width: 88, height: 88))
                    : DsImage(url: controller.images[index], fit: BoxFit.cover, width: 88, height: 88, radius: DsRadius.md),
              ),
              PositionedDirectional(
                top: DsSpace.xs,
                end: DsSpace.xs,
                child: Container(
                  decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, boxShadow: DsShadows.sm(context)),
                  child: Icon(Icons.close_rounded, size: 18, color: c.danger),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Category dropdown, attribute multi-select, attribute values and variants.
  Widget _categoryAndAttributes(AddProductController controller, bool isDark) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsFieldLabel("Product Categories".tr),
        DropdownButtonFormField<VendorCategoryModel>(
          hint: Text('Select Product Categories'.tr, style: t.body.withColor(c.textMuted)),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
          dropdownColor: c.surfaceRaised,
          borderRadius: DsRadius.brMd,
          isExpanded: true,
          decoration: DsInputDecoration.of(context),
          initialValue: controller.selectedProductCategory.value.id == null ? null : controller.selectedProductCategory.value,
          onChanged: (value) {
            controller.selectedProductCategory.value = value!;
            controller.update();
          },
          style: t.bodyStrong,
          items: controller.vendorCategoryList.map((item) {
            return DropdownMenuItem<VendorCategoryModel>(
              value: item,
              child: Text(item.title.toString(), style: t.bodyStrong),
            );
          }).toList(),
        ),
        const DsGap(DsSpace.lg),
        DsFieldLabel("Attributes".tr),
        DropdownSearch<AttributesModel>.multiSelection(
          items: (String s, LoadProps? data) => controller.attributesList,
          key: controller.myKey1,
          suffixProps: DropdownSuffixProps(
            dropdownButtonProps: DropdownButtonProps(
              focusColor: c.brand,
              color: c.textMuted,
              iconClosed: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
              iconOpened: Icon(Icons.keyboard_arrow_up_rounded, color: c.textMuted),
            ),
          ),
          decoratorProps: DropDownDecoratorProps(
            decoration: DsInputDecoration.of(context, hint: 'Select Attributes'.tr, contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm)),
          ),
          compareFn: (i1, i2) => i1.title == i2.title,
          popupProps: MultiSelectionPopupProps.menu(
            fit: FlexFit.tight,
            showSelectedItems: true,
            menuProps: MenuProps(backgroundColor: c.surfaceRaised, borderRadius: DsRadius.brMd),
            listViewProps: const ListViewProps(physics: BouncingScrollPhysics(), padding: EdgeInsets.only(left: 20)),
            itemBuilder: (context, item, isSelected, bool) {
              return ListTile(
                selectedColor: c.brand,
                selected: isSelected,
                title: Text(item.title.toString(), style: t.bodyLg.w500),
                onTap: () {
                  controller.myKey1.currentState?.popupValidate([item]);
                },
              );
            },
          ),
          itemAsString: (AttributesModel u) => u.title.toString(),
          selectedItems: controller.selectedAttributesList,
          onSaved: (data) {},
          onSelected: (data) {
            if (controller.itemAttributes.value!.attributes != null) {
              controller.selectedAttributesList.clear();
              controller.itemAttributes.value!.attributes!.clear();
              controller.itemAttributes.value!.variants!.clear();
            } else {
              controller.itemAttributes.value = ItemAttribute(attributes: [], variants: []);
            }
            controller.selectedAttributesList.addAll(data);

            for (var element in controller.selectedAttributesList) {
              controller.addAttribute(element.id.toString());
            }
            setState(() {});
          },
        ),
        const DsGap(DsSpace.md),
        controller.itemAttributes.value!.attributes == null || controller.itemAttributes.value!.attributes!.isEmpty
            ? const SizedBox()
            : Container(
                padding: const EdgeInsets.all(DsSpace.md),
                decoration: BoxDecoration(color: c.surfaceAlt.withValues(alpha: 0.6), borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Attributes Value".tr, style: t.titleSm),
                    const DsGap(DsSpace.xs),
                    ListView.builder(
                      itemCount: controller.itemAttributes.value!.attributes!.length,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        String title = "";
                        for (var element in controller.attributesList) {
                          if (controller.itemAttributes.value!.attributes![index].attributeId == element.id) {
                            title = element.title.toString();
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(title, style: t.label.withColor(c.textSecondary))),
                                  DsIconButton(
                                    icon: Icons.add_rounded,
                                    semanticLabel: 'Add Attribute Value'.tr,
                                    variant: DsIconButtonVariant.tonal,
                                    size: 36,
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return addAttributeValueDialog(
                                            controller,
                                            isDark,
                                            index,
                                            controller.itemAttributes.value!.attributes![index].attributeId.toString(),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: DsSpace.sm,
                                runSpacing: DsSpace.sm,
                                children: List.generate(controller.itemAttributes.value!.attributes![index].attributeOptions!.length, (i) {
                                  return InkWell(
                                    splashColor: Colors.transparent,
                                    borderRadius: DsRadius.brPill,
                                    onTap: () {
                                      controller.itemAttributes.value!.attributes![index].attributeOptions!.removeAt(i);

                                      List<List<dynamic>> listArary = [];
                                      for (int i = 0; i < controller.itemAttributes.value!.attributes!.length; i++) {
                                        if (controller.itemAttributes.value!.attributes![i].attributeOptions!.isNotEmpty) {
                                          listArary.add(controller.itemAttributes.value!.attributes![i].attributeOptions!);
                                        }
                                      }

                                      if (listArary.isNotEmpty) {
                                        List<Variants>? variantsTemp = [];
                                        List<dynamic> list = getCombination(listArary);
                                        for (var element in list) {
                                          bool productIsInList = controller.itemAttributes.value!.variants!.any((product) => product.variantSku == element);
                                          if (productIsInList) {
                                            Variants variant = controller.itemAttributes.value!.variants!.firstWhere((product) => product.variantSku == element);
                                            Variants variantsModel = Variants(
                                              variantSku: variant.variantSku,
                                              variantId: variant.variantId,
                                              variantImage: variant.variantImage,
                                              variantPrice: variant.variantPrice,
                                              variantQuantity: variant.variantQuantity,
                                              variantWholesalePrice: variant.variantWholesalePrice,
                                              // Store-panel variant fields this app does not edit
                                              // (STORE spec §3): carried over, never dropped.
                                              wholesaleEnabled: variant.wholesaleEnabled,
                                              wholesaleMinQty: variant.wholesaleMinQty,
                                            );
                                            variantsTemp.add(variantsModel);
                                          }
                                        }
                                        controller.itemAttributes.value!.variants!.clear();
                                        controller.itemAttributes.value!.variants!.addAll(variantsTemp);
                                      } else {
                                        controller.itemAttributes.value!.variants!.clear();
                                      }
                                      controller.update();
                                      setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: DsSpace.xs),
                                      child: _buildChip(isDark, controller.itemAttributes.value!.attributes![index].attributeOptions![i], index, i),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    controller.itemAttributes.value!.variants!.isEmpty
                        ? const SizedBox()
                        : Padding(
                            padding: const EdgeInsets.only(top: DsSpace.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: controller.itemAttributes.value!.variants!.map((e) => _variantCard(controller, e)).toList(),
                            ),
                          ),
                  ],
                ),
              ),
      ],
    );
  }

  /// One variant: SKU + image on top, price / wholesale price / quantity below.
  Widget _variantCard(AddProductController controller, Variants e) {
    final c = context.dsColors;
    final t = context.dsText;
    return Container(
      key: ObjectKey(e),
      margin: const EdgeInsets.only(bottom: DsSpace.sm),
      padding: const EdgeInsets.all(DsSpace.md),
      decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Variant".tr.toUpperCase(), style: t.overline),
                    const DsGap(DsSpace.xxs),
                    Text(e.variantSku.toString(), style: t.titleSm),
                  ],
                ),
              ),
              const DsGap(DsSpace.sm),
              Semantics(
                button: true,
                label: "Image".tr,
                child: InkWell(
                  splashColor: Colors.transparent,
                  borderRadius: DsRadius.brSm,
                  onTap: () {
                    int index = controller.itemAttributes.value!.variants!.indexWhere((element) => element.variantId == e.variantId);
                    onCameraClick(context, index, controller);
                  },
                  child: e.variantImage != null && e.variantImage!.isNotEmpty
                      ? DsImage(height: 52, width: 60, radius: DsRadius.sm, fit: BoxFit.cover, url: e.variantImage.toString())
                      : Container(
                          height: 52,
                          width: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brSm),
                          child: SvgPicture.asset("assets/icons/ic_folder_upload.svg", height: 26),
                        ),
                ),
              ),
            ],
          ),
          const DsGap(DsSpace.md),
          DsAdaptiveGrid(
            minItemWidth: 120,
            equalHeight: false,
            maxColumns: 3,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsFieldLabel("Price".tr),
                  TextFormField(
                    initialValue: e.variantPrice,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9-.]'))],
                    keyboardType: TextInputType.text,
                    onChanged: (value) {
                      e.variantPrice = value;
                    },
                    style: t.bodyStrong,
                    decoration: DsInputDecoration.of(
                      context,
                      hint: "Price".tr,
                      prefix: _variantPrefix("${Constant.currencyModel!.symbol}".tr),
                      contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: 12),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsFieldLabel("Wholesale price (1st tier)".tr),
                  TextFormField(
                    initialValue: e.variantWholesalePrice,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.]'))],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      e.variantWholesalePrice = value.trim();
                    },
                    style: t.bodyStrong,
                    decoration: DsInputDecoration.of(
                      context,
                      hint: "Optional".tr,
                      prefix: _variantPrefix("${Constant.currencyModel!.symbol}"),
                      contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: 12),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsFieldLabel("Quantity".tr),
                  TextFormField(
                    initialValue: e.variantQuantity,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9-.]'))],
                    keyboardType: TextInputType.text,
                    onChanged: (value) {
                      e.variantQuantity = value;
                    },
                    style: t.bodyStrong,
                    decoration: DsInputDecoration.of(context, hint: "Quantity".tr, contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _variantPrefix(String symbol) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: DsSpace.md, end: DsSpace.xs),
      child: Text(symbol, style: DsTypography.label.copyWith(color: context.dsColors.textMuted)),
    );
  }

  /// "This is digital product" dropdown + file upload (ecommerce sections).
  Widget _digitalProduct(AddProductController controller) {
    final c = context.dsColors;
    final t = context.dsText;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsFieldLabel("This is digital product".tr),
        DropdownButtonFormField<String>(
          hint: Text('Select Product Categories'.tr, style: t.body.withColor(c.textMuted)),
          dropdownColor: c.surfaceRaised,
          borderRadius: DsRadius.brMd,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
          decoration: DsInputDecoration.of(context),
          initialValue: controller.selectedDigital.value.isEmpty ? null : controller.selectedDigital.value,
          onChanged: (value) {
            controller.selectedDigital.value = value!;
            controller.update();
          },
          style: t.bodyStrong,
          items: controller.digitalProduct.map((item) {
            return DropdownMenuItem<String>(value: item, child: Text(item.toString(), style: t.bodyStrong));
          }).toList(),
        ),
        const DsGap(DsSpace.md),
        AnimatedSize(
          duration: DsMotion.of(context, DsMotion.base),
          curve: DsMotion.standard,
          alignment: Alignment.topCenter,
          child: controller.selectedDigital.value == "Yes"
              ? Container(
                  padding: const EdgeInsets.all(DsSpace.md),
                  decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
                  child: Row(
                    children: [
                      const DsIconWell(icon: Icons.attach_file_rounded, size: 40),
                      const DsGap(DsSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: "File type : ".tr, style: t.bodySm.withColor(c.textPrimary)),
                                  TextSpan(text: "jpg, jpeg, png, gif, zip, pdf".tr, style: t.bodySm.withColor(c.dangerStrong)),
                                ],
                              ),
                            ),
                            const DsGap(DsSpace.xs),
                            Text("${"File Name : ".tr}${controller.digitalProductFileName.value} ", style: t.caption),
                          ],
                        ),
                      ),
                      const DsGap(DsSpace.sm),
                      DsButton.secondary(
                        label: "Upload Zip".tr,
                        icon: Icons.upload_file_rounded,
                        size: DsButtonSize.sm,
                        onPressed: () async {
                          // file_picker 12+: pickFile() returns the single PlatformFile (FilePickerResult removed).
                          PlatformFile? result = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'zip', 'png', 'gif', 'pdf']);

                          if (result != null) {
                            double sizeInMb = (await result.length() ?? 0) / (1024 * 1024);
                            if (sizeInMb <= double.parse(Constant.digitalProductFileSize)) {
                              controller.digitalFile = File(result.path.toString());
                              controller.digitalProductFileName.value = controller.digitalFile != null ? controller.digitalFile!.path.split('/').last : "";
                            } else {
                              ShowToastDialog.showToast("${'Please select less than'.tr} ${Constant.digitalProductFileSize.toString()} ${"mb file.".tr}");
                            }
                          } else {
                            ShowToastDialog.showToast("Please select zip file!".tr); // User canceled the picker
                          }
                        },
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const DsGap(DsSpace.lg),
      ],
    );
  }

  Dialog addAttributeValueDialog(AddProductController controller, isDark, int index, String attributeId) {
    final c = context.dsColors;
    final t = context.dsText;
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.brXl),
      insetPadding: const EdgeInsets.all(DsSpace.lg),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.xxl),
        child: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const DsIconWell(icon: Icons.tune_rounded, size: 40),
                  const DsGap(DsSpace.md),
                  Expanded(child: Text('Add Attribute Value'.tr, style: t.title)),
                ],
              ),
              const DsGap(DsSpace.xl),
              TextFieldWidget(title: 'Add Attribute Value'.tr, controller: controller.attributesValueController.value, hintText: 'Add Attribute Value'.tr),
              const DsGap(DsSpace.xs),
              DsButton.primary(
                label: "Add".tr,
                icon: Icons.add_rounded,
                expand: true,
                onPressed: () async {
                  if (controller.attributesValueController.value.text.isEmpty) {
                    ShowToastDialog.showToast("Please enter attribute value".tr);
                  } else {
                    Get.back();
                    controller.itemAttributes.value!.attributes![index].attributeOptions!.add(controller.attributesValueController.value.text);

                    List<List<dynamic>> listArary = [];
                    for (int i = 0; i < controller.itemAttributes.value!.attributes!.length; i++) {
                      if (controller.itemAttributes.value!.attributes![i].attributeOptions!.isNotEmpty) {
                        listArary.add(controller.itemAttributes.value!.attributes![i].attributeOptions!);
                      }
                    }

                    List<dynamic> list = getCombination(listArary);

                    for (var element in list) {
                      bool productIsInList = controller.itemAttributes.value!.variants!.any((product) => product.variantSku == element);
                      if (productIsInList) {
                      } else {
                        if (controller.itemAttributes.value!.attributes![index].attributeOptions!.length == 1) {
                          controller.itemAttributes.value!.variants!.clear();
                          Variants variantsModel = Variants(variantSku: element, variantId: Constant.getUuid(), variantImage: "", variantPrice: "0", variantQuantity: "-1");
                          controller.itemAttributes.value!.variants!.add(variantsModel);
                        } else {
                          Variants variantsModel = Variants(variantSku: element, variantId: Constant.getUuid(), variantImage: "", variantPrice: "0", variantQuantity: "-1");
                          controller.itemAttributes.value!.variants!.add(variantsModel);
                        }
                      }
                    }
                    setState(() {});
                    controller.attributesValueController.value.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future buildBottomSheet(BuildContext context, AddProductController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: context.dsColors.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: DsRadius.sheetTop),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final c = context.dsColors;
            final t = context.dsText;
            Widget option(IconData icon, String label, VoidCallback onTap) {
              return Expanded(
                child: DsCard.outlined(
                  onTap: onTap,
                  semanticLabel: label,
                  padding: const EdgeInsets.symmetric(vertical: DsSpace.xl, horizontal: DsSpace.md),
                  child: Column(
                    children: [
                      DsIconWell(icon: icon, size: 52, circle: true),
                      const DsGap(DsSpace.sm),
                      Text(label, textAlign: TextAlign.center, style: t.label),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.sm, DsSpace.xl, DsSpace.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: c.borderStrong, borderRadius: DsRadius.brPill),
                      ),
                    ),
                    const DsGap(DsSpace.lg),
                    Text("Please Select".tr, style: t.title),
                    const DsGap(DsSpace.lg),
                    Row(
                      children: [
                        option(Icons.photo_camera_outlined, "Camera".tr, () => controller.pickFile(source: ImageSource.camera)),
                        const DsGap(DsSpace.md),
                        option(Icons.photo_library_outlined, "Gallery".tr, () => controller.pickFile(source: ImageSource.gallery)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Sale type (retail / wholesale / both) + wholesale price tiers. Once a cart
  /// line reaches a tier's minimum quantity, every unit on that line is charged
  /// that tier's price (the biggest tier reached wins).
  Widget _buildWholesaleSection(AddProductController controller, bool isDark) {
    final c = context.dsColors;
    final t = context.dsText;
    final bool enabled = controller.wholesaleEnabled.value;
    final String saleType = controller.saleType.value;
    // Read so the preview rebuilds on every keystroke in a tier row.
    controller.wholesaleTierRevision.value;
    final List<WholesaleTierInput> tiers = controller.wholesaleTierInputs.toList();
    final String preview = controller.wholesalePreview;
    final TextStyle hintStyle = t.caption;
    final String firstMinQty = controller.enteredWholesaleTiers.isEmpty ? '' : controller.enteredWholesaleTiers.first.minQty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsFieldLabel("Sold as".tr),
        Container(
          padding: const EdgeInsets.all(DsSpace.xs),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: DsRadius.brMd),
          child: Row(
            children: [
              _saleTypeOption(controller, isDark, ProductModel.saleTypeRetail, "Retail".tr, saleType),
              const DsGap(DsSpace.xs),
              _saleTypeOption(controller, isDark, ProductModel.saleTypeWholesale, "Wholesale".tr, saleType),
              const DsGap(DsSpace.xs),
              _saleTypeOption(controller, isDark, ProductModel.saleTypeBoth, "Both".tr, saleType),
            ],
          ),
        ),
        AnimatedSize(
          duration: DsMotion.of(context, DsMotion.base),
          curve: DsMotion.standard,
          alignment: Alignment.topCenter,
          child: saleType == ProductModel.saleTypeWholesale
              ? Padding(
                  padding: const EdgeInsets.only(top: DsSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: c.infoStrong),
                      const DsGap(DsSpace.sm),
                      Expanded(
                        child: Text(
                          firstMinQty.isEmpty
                              ? "Wholesale only: the minimum order quantity is the first tier's minimum quantity.".tr
                              : "${"Wholesale only: customers must order at least".tr} $firstMinQty ${"units".tr}.",
                          style: hintStyle.withColor(c.infoStrong),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const DsGap(DsSpace.lg),
        Container(
          padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.sm, DsSpace.md),
          decoration: BoxDecoration(
            color: enabled ? c.brandSoft : c.surfaceAlt.withValues(alpha: 0.6),
            borderRadius: DsRadius.brMd,
            border: Border.all(color: enabled ? c.brandMuted : c.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconWell(icon: Icons.stacked_bar_chart_rounded, size: 36, tone: enabled ? DsTone.brand : DsTone.neutral),
              const DsGap(DsSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Wholesale pricing".tr, style: t.label),
                    const DsGap(DsSpace.xxs),
                    Text("Charge lower unit prices when a customer orders larger quantities of this product.".tr, style: hintStyle),
                  ],
                ),
              ),
              Switch.adaptive(value: enabled, onChanged: controller.setWholesaleEnabled),
            ],
          ),
        ),
        AnimatedSize(
          duration: DsMotion.of(context, DsMotion.base),
          curve: DsMotion.standard,
          alignment: Alignment.topCenter,
          child: !enabled
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DsGap(DsSpace.md),
                    for (int i = 0; i < tiers.length; i++)
                      DsFadeSlideIn(
                        key: ObjectKey(tiers[i]),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: DsSpace.sm),
                          padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.md, DsSpace.xs, 0),
                          decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brMd, border: Border.all(color: c.border)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 30),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
                                  child: Text('${i + 1}', style: t.labelSm.withColor(c.brandStrong)),
                                ),
                              ),
                              const DsGap(DsSpace.sm),
                              Expanded(
                                child: TextFieldWidget(
                                  title: 'From quantity'.tr,
                                  controller: tiers[i].minQtyController,
                                  hintText: 'e.g. 10'.tr,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  textInputType: TextInputType.number,
                                ),
                              ),
                              const DsGap(DsSpace.sm),
                              Expanded(
                                child: TextFieldWidget(
                                  title: 'Unit price'.tr,
                                  controller: tiers[i].priceController,
                                  hintText: 'Enter Wholesale Price'.tr,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.]'))],
                                  textInputType: const TextInputType.numberWithOptions(decimal: true),
                                  prefix: _currencyPrefix("${Constant.currencyModel!.symbol}"),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 22),
                                child: DsIconButton(
                                  icon: Icons.delete_outline_rounded,
                                  semanticLabel: "Remove tier".tr,
                                  color: c.danger,
                                  onPressed: () => controller.removeWholesaleTier(i),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (tiers.length < ProductModel.maxWholesaleTiers)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DsButton.tonal(label: "Add tier".tr, icon: Icons.add_rounded, size: DsButtonSize.sm, onPressed: controller.addWholesaleTier),
                      ),
                    AnimatedSwitcher(
                      duration: DsMotion.of(context, DsMotion.base),
                      child: preview.isNotEmpty
                          ? Container(
                              key: const ValueKey('wholesale-preview'),
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: DsSpace.md, bottom: DsSpace.xs),
                              padding: const EdgeInsets.all(DsSpace.md),
                              decoration: BoxDecoration(color: c.brandSoft, borderRadius: DsRadius.brMd),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.visibility_outlined, size: 18, color: c.brandStrong),
                                  const DsGap(DsSpace.sm),
                                  Expanded(child: Text(preview, style: t.bodySm.withColor(c.brandStrong).w500)),
                                ],
                              ),
                            )
                          : const SizedBox(key: ValueKey('wholesale-preview-empty'), width: double.infinity),
                    ),
                    const DsGap(DsSpace.sm),
                    Text(
                      "Up to 5 tiers. Each tier needs a minimum quantity of at least 2 and a price below the regular price; a bigger quantity must have a lower price. A variant's own wholesale price (in the variants table) replaces the first tier's price for that variant."
                          .tr,
                      style: hintStyle,
                    ),
                    const DsGap(DsSpace.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Row(
                        children: [
                          DsIconWell(icon: Icons.verified_outlined, size: 36, tone: DsTone.info),
                          const DsGap(DsSpace.md),
                          Expanded(child: Text("Only verified Business customers get wholesale prices".tr, style: t.bodyStrong)),
                          Switch.adaptive(
                            value: controller.wholesaleBusinessOnly.value,
                            onChanged: (value) => controller.wholesaleBusinessOnly.value = value,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _saleTypeOption(AddProductController controller, bool isDark, String type, String label, String selected) {
    final c = context.dsColors;
    final bool isSelected = type == selected;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: DsRadius.brSm,
            onTap: () => controller.setSaleType(type),
            child: AnimatedContainer(
              duration: DsMotion.of(context, DsMotion.base),
              curve: DsMotion.standard,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(vertical: DsSpace.sm, horizontal: DsSpace.xs),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? c.brand : Colors.transparent,
                borderRadius: DsRadius.brSm,
                boxShadow: isSelected ? DsShadows.sm(context) : null,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DsTypography.label.copyWith(color: isSelected ? c.onBrand : c.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Delivery / Takeaway availability for this product (at least one).
  Widget _buildFulfilmentSection(AddProductController controller, bool isDark) {
    final t = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _fulfilmentOption(
              icon: Icons.delivery_dining_outlined,
              label: "Delivery".tr,
              selected: controller.fulfilDelivery.value,
              onSelected: (value) => controller.toggleFulfilment(ProductModel.fulfilmentDelivery, value),
            ),
            const DsGap(DsSpace.md),
            _fulfilmentOption(
              icon: Icons.storefront_outlined,
              label: "Takeaway".tr,
              selected: controller.fulfilTakeaway.value,
              onSelected: (value) => controller.toggleFulfilment(ProductModel.fulfilmentTakeaway, value),
            ),
          ],
        ),
        const DsGap(DsSpace.sm),
        Text("Customers can only order this product with the selected options.".tr, style: t.caption),
      ],
    );
  }

  /// Selectable card replacing the FilterChip; tap toggles like `onSelected(!selected)`.
  Widget _fulfilmentOption({required IconData icon, required String label, required bool selected, required ValueChanged<bool> onSelected}) {
    final c = context.dsColors;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: DsRadius.brMd,
            onTap: () => onSelected(!selected),
            child: AnimatedContainer(
              duration: DsMotion.of(context, DsMotion.base),
              curve: DsMotion.standard,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.md),
              decoration: BoxDecoration(
                color: selected ? c.brandSoft : c.surface,
                borderRadius: DsRadius.brMd,
                border: Border.all(color: selected ? c.brand : c.border, width: selected ? 1.4 : 1),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: selected ? c.brandStrong : c.iconDefault),
                  const DsGap(DsSpace.sm),
                  Expanded(child: Text(label, style: DsTypography.label.copyWith(color: selected ? c.brandStrong : c.textPrimary))),
                  AnimatedSwitcher(
                    duration: DsMotion.of(context, DsMotion.fast),
                    child: Icon(
                      selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(selected),
                      size: 20,
                      color: selected ? c.brand : c.borderStrong,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(bool isDark, String label, int attributesIndex, int attributesOptionIndex) {
    final c = context.dsColors;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.fromLTRB(DsSpace.md, DsSpace.sm - 2, DsSpace.sm, DsSpace.sm - 2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: DsRadius.brPill,
        border: Border.all(color: c.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: DsTypography.label.copyWith(color: c.textPrimary)),
          const DsGap(DsSpace.sm),
          Icon(Icons.close_rounded, color: c.textMuted, size: 16),
        ],
      ),
    );
  }

  List<dynamic> getCombination(List<List<dynamic>> listArray) {
    if (listArray.length == 1) {
      return listArray[0];
    } else {
      List<dynamic> result = [];
      var allCasesOfRest = getCombination(listArray.sublist(1));
      for (var i = 0; i < allCasesOfRest.length; i++) {
        for (var j = 0; j < listArray[0].length; j++) {
          result.add(listArray[0][j] + '-' + allCasesOfRest[i]);
        }
      }
      return result;
    }
  }

  void onCameraClick(BuildContext context, int index, AddProductController controller) {
    final action = CupertinoActionSheet(
      message: Text('Upload image'.tr, style: TextStyle(fontSize: 15.0)),
      actions: <Widget>[
        CupertinoActionSheetAction(
          isDefaultAction: false,
          onPressed: () async {
            Get.back();
            XFile? singleImage = await ImagePicker().pickImage(source: ImageSource.gallery);
            if (singleImage != null) {
              ShowToastDialog.showLoader("Image Upload...".tr);

              String image = await FireStoreUtils.uploadUserImageToFireStorage(File(singleImage.path), controller.itemAttributes.value!.variants![index].variantId.toString());
              ShowToastDialog.closeLoader();
              controller.itemAttributes.value!.variants![index].variantImage = image;
              setState(() {});
            }
          },
          child: Text('Choose image from gallery'.tr),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () async {
            Get.back();
            final XFile? singleImage = await ImagePicker().pickImage(source: ImageSource.camera);
            if (singleImage != null) {
              ShowToastDialog.showLoader("Image Upload...".tr);

              String image = await FireStoreUtils.uploadUserImageToFireStorage(File(singleImage.path), controller.itemAttributes.value!.variants![index].variantId.toString());
              ShowToastDialog.closeLoader();
              controller.itemAttributes.value!.variants![index].variantImage = image;
              setState(() {});
            }
          },
          child: Text('Take a picture'.tr),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr),
        onPressed: () {
          Get.back();
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }
}

/// "Step 2 of 5 · Details" heading above each wizard step.
class _StepHeading extends StatelessWidget {
  final int index;
  final int total;
  final String title;

  const _StepHeading({required this.index, required this.total, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : DsSpace.md, bottom: DsSpace.md),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
              child: Text('${index + 1}', style: DsTypography.labelSm.copyWith(color: c.onBrand)),
            ),
            const DsGap(DsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${'Step'.tr} ${index + 1}/$total".toUpperCase(), style: t.overline),
                  Text(title, style: t.title),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky wizard progress: one segment per step, tap to jump.
class _WizardHeader extends StatelessWidget {
  final List<String> labels;
  final ValueNotifier<int> activeStep;
  final ValueChanged<int> onStepTap;

  const _WizardHeader({required this.labels, required this.activeStep, required this.onStepTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l = context.dsLayout;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      padding: EdgeInsets.fromLTRB(l.gutter, 0, l.gutter, DsSpace.xs),
      child: DsResponsive(
        child: ValueListenableBuilder<int>(
          valueListenable: activeStep,
          builder: (context, active, _) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < labels.length; i++) ...[
                  if (i > 0) const DsGap(DsSpace.xs),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == active,
                      label: '${i + 1}. ${labels[i]}',
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: DsRadius.brSm,
                        onTap: () => onStepTap(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: DsSpace.sm, horizontal: DsSpace.xxs),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: DsMotion.of(context, DsMotion.slow),
                                  curve: DsMotion.emphasized,
                                  height: 4,
                                  decoration: BoxDecoration(borderRadius: DsRadius.brPill, color: i <= active ? c.brand : c.surfaceAlt),
                                ),
                                const DsGap(DsSpace.sm),
                                AnimatedDefaultTextStyle(
                                  duration: DsMotion.of(context, DsMotion.base),
                                  style: DsTypography.labelSm.copyWith(color: i == active ? c.brandStrong : (i < active ? c.textPrimary : c.textMuted)),
                                  child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
