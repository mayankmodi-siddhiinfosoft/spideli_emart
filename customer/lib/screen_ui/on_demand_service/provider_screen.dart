import 'package:customer/screen_ui/on_demand_service/on_demand_home_screen.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../controllers/provider_controller.dart';
import '../../models/provider_serivce_model.dart';

/// Archetype B – provider profile: gradient identity hero over the list of
/// services that provider offers.
class ProviderScreen extends StatelessWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ProviderController>(
      init: ProviderController(),
      builder: (controller) {
        final bool isLoading = controller.isLoading.value;
        final user = controller.userModel.value;
        final List<ProviderServiceModel> providers = controller.providerList.toList();

        return DsScaffold.hero(
          hero: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DsAvatar(imageUrl: user?.profilePictureURL ?? '', name: user?.fullName(), size: 96, ring: true),
              const DsGap(DsSpace.md),
              Text(user?.fullName() ?? '', textAlign: TextAlign.center, style: DsTypography.headline.copyWith(color: Colors.white)),
              const DsGap(DsSpace.sm),
              _ContactLine(asset: "assets/icons/ic_mail.svg", value: user?.email ?? ''),
              _ContactLine(asset: "assets/icons/ic_mobile.svg", value: user?.phoneNumber ?? ''),
            ],
          ),
          heroOverlap: DsCard(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg, vertical: DsSpace.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MetaBlock(value: _getRating(controller), label: "Rating".tr, icon: Icons.star_rounded, tone: DsTone.warning),
                Container(width: 1, height: 36, color: context.dsColors.divider),
                _MetaBlock(value: '${providers.length}', label: "Services".tr, icon: Icons.home_repair_service_outlined, tone: DsTone.brand),
              ],
            ),
          ),
          slivers: [
            if (isLoading)
              const DsSliverResponsive(top: DsSpace.xl, sliver: SliverToBoxAdapter(child: DsSkeletonList(itemCount: 4)))
            else ...[
              DsSliverResponsive(
                top: DsSpace.sm,
                sliver: SliverToBoxAdapter(child: DsSectionHeader(title: "Services".tr, icon: Icons.home_repair_service_outlined)),
              ),
              if (providers.isEmpty)
                DsSliverResponsive(sliver: SliverToBoxAdapter(child: DsEmptyState(compact: true, icon: Icons.handyman_outlined, title: "No Services Found".tr)))
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
          ],
        );
      },
    );
  }

  String _getRating(ProviderController controller) {
    final reviewsCount = double.tryParse(controller.userModel.value?.reviewsCount?.toString() ?? "0") ?? 0;
    final reviewsSum = double.tryParse(controller.userModel.value?.reviewsSum?.toString() ?? "0") ?? 0;

    if (reviewsCount == 0) return "0";
    final avg = reviewsSum / reviewsCount;
    return avg.toStringAsFixed(1);
  }
}

/// White-on-gradient contact row (email / phone) for the provider hero.
class _ContactLine extends StatelessWidget {
  final String asset;
  final String value;

  const _ContactLine({required this.asset, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: DsSpace.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(asset, height: 16, width: 16, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          const DsGap(DsSpace.sm),
          Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: DsTypography.bodyStrong.copyWith(color: Colors.white))),
        ],
      ),
    );
  }
}

/// Small metric block used in the provider overlap card.
class _MetaBlock extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final DsTone tone;

  const _MetaBlock({required this.value, required this.label, required this.icon, required this.tone});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final t = context.dsText;
    final toneColors = c.tone(tone);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: toneColors.strong),
            const DsGap(DsSpace.xs),
            Text(value, style: t.titleSm.tabular),
          ],
        ),
        const DsGap(DsSpace.xxs),
        Text(label, style: t.caption),
      ],
    );
  }
}
