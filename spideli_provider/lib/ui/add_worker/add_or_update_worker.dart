import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/constant/show_toast_dialog.dart';
import 'package:spideliprovider/controller/add_worker_controller.dart';
import 'package:spideliprovider/model/provider_service_model.dart';
import 'package:spideliprovider/model/user.dart';
import 'package:spideliprovider/services/firebase_helper.dart';
import 'package:spideliprovider/services/helper.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:spideliprovider/widgets/geoflutterfire/src/geoflutterfire.dart';
import 'package:spideliprovider/widgets/geoflutterfire/src/models/point.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Add / edit worker (archetype F): a profile hero with the availability
/// toggle, then grouped form sections and a sticky Save bar. All controllers,
/// validators, `onSaved` callbacks and the location picker are unchanged.
class AddOrUpdateWorkerScreen extends StatelessWidget {
  const AddOrUpdateWorkerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX<AddOrUpdateWorkerController>(
        init: AddOrUpdateWorkerController(),
        builder: (controller) {
          final c = context.dsColors;
          final t = context.dsText;
          final bool isEdit = controller.user.value.id != "";
          final bool isActive = controller.isActive.value;
          return DsScaffold(
            title: isEdit ? 'Edit Worker'.tr : "Add Worker".tr,
            onBack: () {
              Get.back();
            },
            maxContentWidth: DsLayout.contentMax,
            body: Form(
              key: controller.formKey.value,
              autovalidateMode: controller.validate,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.lg, DsSpace.lg, DsSpace.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: DsFadeSlideIn.stagger([
                    // ── Profile + availability ───────────────────────────
                    DsCard(
                      padding: const EdgeInsets.all(DsSpace.lg),
                      margin: const EdgeInsets.only(bottom: DsSpace.lg),
                      child: Column(
                        children: [
                          if (isEdit) ...[
                            DsAvatar(
                              imageUrl: controller.user.value.profilePictureURL.toString(),
                              name: controller.user.value.fullName(),
                              size: 92,
                              ring: true,
                            ),
                            const DsGap(DsSpace.md),
                          ],
                          Row(
                            children: [
                              DsIconWell(
                                icon: isActive ? Icons.verified_user_outlined : Icons.pause_circle_outline_rounded,
                                tone: isActive ? DsTone.success : DsTone.neutral,
                                size: 40,
                              ),
                              const DsGap(DsSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Active'.tr, style: t.titleSm),
                                    const DsGap(DsSpace.xxs),
                                    Text(
                                      isActive ? 'This worker can be assigned to bookings.'.tr : 'This worker is paused.'.tr,
                                      style: t.bodySm,
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                splashRadius: 40.0,
                                value: controller.isActive.value,
                                onChanged: (value) {
                                  controller.isActive.value = value;
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ── Personal details ─────────────────────────────────
                    DsFormSection(
                      title: 'Personal details'.tr,
                      icon: Icons.person_outline_rounded,
                      children: [
                        _FormField(
                          label: 'First Name'.tr,
                          hint: 'First Name'.tr,
                          controller: controller.firstName.value,
                          validator: validateName,
                          prefixIcon: Icons.badge_outlined,
                          onSaved: (String? val) {
                            controller.firstName.value.text = val.toString();
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        _FormField(
                          label: 'Last Name'.tr,
                          hint: 'Last Name'.tr,
                          controller: controller.lastName.value,
                          validator: validateName,
                          prefixIcon: Icons.badge_outlined,
                          onSaved: (String? val) {
                            controller.lastName.value.text = val.toString();
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        _FormField(
                          label: 'Email Address'.tr,
                          hint: 'Email Address'.tr,
                          controller: controller.email.value,
                          validator: validateEmail,
                          prefixIcon: Icons.mail_outline_rounded,
                          // The decoration (not the field) is disabled when
                          // editing an existing worker. Keyed off the loaded
                          // worker rather than `Get.arguments`, which is the
                          // *current* route's arguments and so reads as null
                          // while a picker is on top of this screen.
                          decorationEnabled: controller.user.value.id.isEmpty,
                          onSaved: (String? val) {
                            controller.email.value.text = val.toString();
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        _FormField(
                          label: 'Phone Number'.tr,
                          hint: 'Phone Number'.tr,
                          controller: controller.mobile.value,
                          validator: validateEmptyField,
                          prefixIcon: Icons.call_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          bottomSpacing: DsSpace.sm,
                        ),
                      ],
                    ),
                    // ── Work details ─────────────────────────────────────
                    DsFormSection(
                      title: 'Work details'.tr,
                      icon: Icons.work_outline_rounded,
                      children: [
                        _FormField(
                          label: 'Address'.tr,
                          hint: 'Address'.tr,
                          controller: controller.address.value,
                          validator: validateEmptyField,
                          prefixIcon: Icons.location_on_outlined,
                          suffix: Icon(Icons.my_location_rounded, size: 20, color: c.brand),
                          readOnly: true,
                          textInputAction: TextInputAction.next,
                          onTap: () => controller.pickLocation(context),
                        ),
                        _FormField(
                          label: 'Salary'.tr,
                          hint: 'Salary'.tr,
                          controller: controller.salary.value,
                          validator: validateEmptyField,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          prefix: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                            child: Text(currencyData!.symbol.toString(), style: t.bodyStrong.withColor(c.textSecondary)),
                          ),
                          onSaved: (String? val) {
                            controller.salary.value.text = val.toString();
                          },
                          textInputAction: TextInputAction.next,
                          bottomSpacing: DsSpace.sm,
                        ),
                      ],
                    ),
                    // ── Account (new workers only) ───────────────────────
                    if (controller.user.value.id == "")
                      DsFormSection(
                        title: 'Account'.tr,
                        icon: Icons.lock_outline_rounded,
                        children: [
                          _FormField(
                            label: 'Password'.tr,
                            hint: 'Password'.tr,
                            controller: controller.password.value,
                            validator: validatePassword,
                            prefixIcon: Icons.key_outlined,
                            obscurable: true,
                            onSaved: (String? val) {
                              controller.password.value.text = val.toString();
                            },
                            textInputAction: TextInputAction.next,
                            bottomSpacing: DsSpace.sm,
                          ),
                        ],
                      ),
                  ]),
                ),
              ),
            ),
            bottomBar: DsStickyBar(
              child: DsButton.primary(
                label: 'Save'.tr,
                icon: Icons.check_rounded,
                size: DsButtonSize.lg,
                expand: true,
                onPressed: () {
                  _validate(controller, context);
                },
              ),
            ),
          );
        });
  }

  _validate(AddOrUpdateWorkerController controller, BuildContext context) async {
    if (controller.formKey.value.currentState?.validate() ?? false) {
      // Without a picked point the worker would be stored on the null island
      // (0, 0) and never match a nearby booking.
      if (controller.latValue.value == 0.0 && controller.longValue.value == 0.0) {
        ShowToastDialog.showToast('Please select the location'.tr);
        return;
      }
      controller.formKey.value.currentState!.save();
      ShowToastDialog.showLoader('Saving Worker...'.tr);

      User? user = controller.user.value;

      GeoFirePoint myLocation = Geoflutterfire().point(latitude: controller.latValue.value, longitude: controller.longValue.value);

      user.firstName = controller.firstName.value.text;
      user.lastName = controller.lastName.value.text;
      user.email = controller.email.value.text;
      user.phoneNumber = controller.mobile.value.text;
      user.salary = controller.salary.value.text;
      user.address = controller.address.value.text;
      user.geoFireData = GeoFireData(geohash: myLocation.hash, geoPoint: GeoPoint(controller.latValue.value, controller.longValue.value));
      user.latitude = controller.latValue.value;
      user.longitude = controller.longValue.value;
      user.active = controller.isActive.value;

      if (user.id.isNotEmpty) {
        try {
          await FireStoreUtils.firebaseUpdateWorker(user);
          ShowToastDialog.closeLoader();
          Get.back(result: true);
        } catch (e) {
          // A failed write used to leave the loader up with no explanation.
          ShowToastDialog.closeLoader();
          log("Worker update failed: $e");
          ShowToastDialog.showToast("Could not save the worker, please try again".tr);
        }
      } else {
        // Closes its own loader on every path.
        await controller.signUpWithWorkerEmailAndPassword(user, controller.password.value.text, context);
      }
    } else {
      controller.validate = AutovalidateMode.onUserInteraction;
    }
  }
}

/// Labelled DS-styled [TextFormField]. Used instead of [DsTextField] because
/// these fields need `onSaved` (the form calls `save()`) and a decoration-only
/// disabled state, which the DS field does not expose.
class _FormField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback? onTap;
  final bool obscurable;
  final bool decorationEnabled;
  final bool readOnly;
  final double bottomSpacing;

  const _FormField({
    required this.label,
    this.hint,
    required this.controller,
    this.validator,
    this.onSaved,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onTap,
    this.obscurable = false,
    this.decorationEnabled = true,
    this.readOnly = false,
    this.bottomSpacing = DsSpace.lg,
  });

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  late bool _obscured = widget.obscurable;

  @override
  Widget build(BuildContext context) {
    Widget? suffix = widget.suffix;
    if (widget.obscurable) {
      suffix = IconButton(
        tooltip: _obscured ? 'Show password'.tr : 'Hide password'.tr,
        icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsFieldLabel(widget.label),
          TextFormField(
            controller: widget.controller,
            cursorColor: context.dsColors.brand,
            textAlignVertical: TextAlignVertical.center,
            style: DsTypography.bodyStrong.copyWith(color: context.dsColors.textPrimary),
            validator: widget.validator,
            onSaved: widget.onSaved,
            onTap: widget.onTap,
            readOnly: widget.readOnly,
            obscureText: _obscured,
            obscuringCharacter: '●',
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            decoration: DsInputDecoration.of(
              context,
              hint: widget.hint,
              prefixIcon: widget.prefixIcon,
              prefix: widget.prefix,
              suffix: suffix,
              enabled: widget.decorationEnabled,
            ),
          ),
        ],
      ),
    );
  }
}
