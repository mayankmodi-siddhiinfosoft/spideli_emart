import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/view_category_service_controller.dart';
import '../../models/provider_serivce_model.dart';
import '../../screen_ui/on_demand_service/on_demand_home_screen.dart';

/// Archetype B – services of one category.
class ViewCategoryServiceListScreen extends StatelessWidget {
  const ViewCategoryServiceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ViewCategoryServiceController>(
      init: ViewCategoryServiceController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final List<ProviderServiceModel> providers = controller.providerList.toList();

        return DsScaffold.collapsing(
          title: controller.categoryTitle.value,
          subtitle: isLoading ? null : "${providers.length} ${'services'.tr}",
          slivers: [
            if (isLoading)
              const DsSliverResponsive(top: DsSpace.md, sliver: SliverToBoxAdapter(child: DsSkeletonList(itemCount: 6)))
            else if (providers.isEmpty)
              DsSliverResponsive(
                top: DsSpace.xxxl,
                sliver: SliverToBoxAdapter(child: DsEmptyState(icon: Icons.handyman_outlined, title: "No Service Found".tr)),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                top: DsSpace.md,
                bottom: DsSpace.xl,
                sliver: SliverList.builder(
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    ProviderServiceModel providerModel = providers[index];
                    return DsFadeSlideIn(index: index, child: ServiceView(provider: providerModel, controller: controller.onDemandHomeController.value));
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
