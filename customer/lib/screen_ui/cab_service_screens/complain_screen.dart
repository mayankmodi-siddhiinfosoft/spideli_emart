import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/complain_controller.dart';
import '../../constant/constant.dart';
import '../../themes/text_field_widget.dart';

/// Ride complaint (archetype E — short form): a gradient hero explaining the
/// form, a tinted status card once the report has one, a single form section
/// and a sticky submit bar.
class ComplainScreen extends StatelessWidget {
  const ComplainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ComplainController>(
      init: ComplainController(),
      builder: (controller) {
        return Obx(() {
          final l = context.dsLayout;
          return DsScaffold(
            title: "Complain".tr,
            onBack: () => Get.back(),
            resizeToAvoidBottomInset: true,
            body: controller.isLoading.value
                ? const DsSkeletonForm(fields: 2)
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(l.gutter, DsSpace.lg, l.gutter, DsSpace.xxxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: DsFadeSlideIn.stagger([
                        _ComplaintHero(orderId: controller.order.value.id),
                        Obx(() {
                          final status = controller.status.value;
                          if (status == '' || status.isNotEmpty != true) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: DsSpace.lg),
                            child: DsCard.tinted(
                              tone: DsTone.fromStatus(status),
                              child: Row(
                                children: [
                                  Expanded(child: Text("Status".tr, style: context.dsText.label)),
                                  DsStatusChip(label: " : $status".tr, status: status),
                                ],
                              ),
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpace.lg),
                          child: DsFormSection(
                            title: "Complain".tr,
                            icon: Icons.report_gmailerrorred_rounded,
                            children: [
                              Obx(() => TextFieldWidget(title: "Title".tr, hintText: "Title".tr, controller: controller.title.value)),
                              const DsGap(DsSpace.md),
                              Obx(() => TextFieldWidget(title: "Complain".tr, hintText: 'Type Description....'.tr, controller: controller.comment.value, maxLine: 8)),
                              const DsGap(DsSpace.sm),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
            bottomBar: controller.isLoading.value
                ? null
                : DsStickyBar(
                    child: DsButton.primary(label: "Save".tr, icon: Icons.send_rounded, size: DsButtonSize.lg, expand: true, onPressed: () => controller.submitComplain()),
                  ),
          );
        });
      },
    );
  }
}

/// Header explaining what the form is for, with the ride id when there is one.
class _ComplaintHero extends StatelessWidget {
  final String? orderId;

  const _ComplaintHero({this.orderId});

  @override
  Widget build(BuildContext context) {
    final t = context.dsText;
    final id = orderId;
    return DsCard.gradient(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DsIconWell(icon: Icons.support_agent_rounded, size: 44, onBrand: true),
          const DsGap(DsSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tell us what went wrong".tr, style: t.title.withColor(Colors.white)),
                const DsGap(DsSpace.xs),
                Text("We review every report and get back to you.".tr, style: t.bodySm.withColor(Colors.white.withValues(alpha: 0.86))),
                if (id != null && id.isNotEmpty) ...[
                  const DsGap(DsSpace.md),
                  DsCard.glass(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.sm),
                    radius: DsRadius.sm,
                    child: Text("${'Order Id:'.tr} ${Constant.orderId(orderId: id)}", style: t.labelSm.withColor(Colors.white).tabular),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
