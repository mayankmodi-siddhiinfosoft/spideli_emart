import 'package:customer/screen_ui/on_demand_service/on_demand_home_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/view_all_popular_service_controller.dart';
import '../../models/provider_serivce_model.dart';

/// Archetype B – catalogue list with a pinned search field.
class ViewAllPopularServiceScreen extends StatelessWidget {
  const ViewAllPopularServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ViewAllPopularServiceController>(
      init: ViewAllPopularServiceController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final List<ProviderServiceModel> providers = controller.providerList.toList();

        return DsScaffold.collapsing(
          title: "All Services".tr,
          subtitle: isLoading ? null : "${providers.length} ${'available'.tr}",
          slivers: [
            DsSliverResponsive(
              top: DsSpace.sm,
              bottom: DsSpace.md,
              sliver: SliverToBoxAdapter(
                child: DsSearchBar(
                  hint: "Search Service".tr,
                  controller: controller.searchTextFiledController.value,
                  onChanged: (value) => controller.getFilterData(value.toString()),
                ),
              ),
            ),
            if (isLoading)
              const DsSliverResponsive(sliver: SliverToBoxAdapter(child: DsSkeletonList(itemCount: 6)))
            else if (providers.isEmpty)
              DsSliverResponsive(
                top: DsSpace.xxxl,
                sliver: SliverToBoxAdapter(child: DsEmptyState(icon: Icons.search_off_rounded, title: "No service Found".tr)),
              )
            else
              DsSliverResponsive(
                maxWidth: DsLayout.wideMax,
                bottom: DsSpace.xl,
                sliver: SliverList.builder(
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    ProviderServiceModel data = providers[index];
                    return DsFadeSlideIn(index: index, child: ServiceView(provider: data, controller: controller.onDemandHomeController.value));
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
