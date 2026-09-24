import 'package:cached_network_image/cached_network_image.dart';
import 'package:spideliprovider/constant/constants.dart';
import 'package:spideliprovider/controller/on_boarding_controller.dart';
import 'package:spideliprovider/services/preferences.dart';
import 'package:spideliprovider/themes/ds/ds.dart';
import 'package:spideliprovider/ui/auth/auth_screen.dart';
import 'package:spideliprovider/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class OnBoardingScreen extends StatelessWidget {
  const OnBoardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes this screen to theme changes (colors come from the DS).
    Provider.of<DarkThemeProvider>(context);
    final c = context.dsColors;
    final t = context.dsText;
    return GetX<OnBoardingController>(
      init: OnBoardingController(),
      builder: (controller) {
        final int page = controller.selectedPageIndex.value;
        final int pages = controller.onBoardingList.length;
        final bool loading = controller.isLoading.value;
        return DsScaffold(
          backgroundColor: c.background,
          appBar: DsAppBar(
            backgroundColor: c.background,
            leading: page == 0
                ? null
                : DsIconButton(
                    icon: Icons.arrow_back,
                    semanticLabel: 'Back'.tr,
                    onPressed: () {
                      controller.pageController.jumpToPage(controller.selectedPageIndex.value - 1);
                    },
                  ),
          ),
          body: loading
              ? const _OnBoardingSkeleton()
              : DsResponsive(
                  maxWidth: DsLayout.contentMax,
                  padded: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: controller.pageController,
                          onPageChanged: controller.selectedPageIndex.call,
                          itemCount: controller.onBoardingList.length,
                          itemBuilder: (context, index) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.symmetric(vertical: DsSpace.xl),
                                    decoration: BoxDecoration(gradient: DsGradients.subtle(context), borderRadius: DsRadius.brXxl),
                                    clipBehavior: Clip.antiAlias,
                                    child: Padding(
                                      padding: const EdgeInsets.all(DsSpace.xxl),
                                      child: CachedNetworkImage(
                                        imageUrl: controller.onBoardingList[index].image.toString(),
                                        placeholder: (context, url) => loader(),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                                  child: Text(controller.onBoardingList[index].title.toString().tr, textAlign: TextAlign.center, style: t.display),
                                ),
                                const DsGap(DsSpace.md),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: DsSpace.lg),
                                  child: Text(controller.onBoardingList[index].description.toString().tr, textAlign: TextAlign.center, style: t.bodyLg.withColor(c.textSecondary)),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Progress dots – read from the tracked builder so the
                      // GetX observer rebuilds them on page change.
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: DsSpace.xl),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            pages,
                            (index) => AnimatedContainer(
                              duration: DsMotion.of(context, DsMotion.base),
                              curve: DsMotion.emphasized,
                              margin: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                              width: page == index ? 38 : 10,
                              height: 10,
                              decoration: BoxDecoration(color: page == index ? c.brand : c.borderStrong, borderRadius: DsRadius.brPill),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          bottomBar: loading
              ? null
              : DsStickyBar(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DsButton.primary(
                        label: 'Next'.tr,
                        expand: true,
                        size: DsButtonSize.lg,
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: () {
                          if (controller.selectedPageIndex.value == 2) {
                            Preferences.setBoolean(Preferences.isFinishOnBoardingKey, true);
                            Get.offAll(AuthScreen());
                          } else {
                            controller.pageController.jumpToPage(controller.selectedPageIndex.value + 1);
                          }
                        },
                      ),
                      const DsGap(DsSpace.sm),
                      page == 2
                          ? const SizedBox(height: 48)
                          : DsButton.ghost(
                              label: 'Skip'.tr,
                              onPressed: () {
                                Preferences.setBoolean(Preferences.isFinishOnBoardingKey, true);
                                Get.offAll(AuthScreen());
                              },
                            ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// Loading placeholder that keeps the onboarding layout (media block, title,
/// two text lines, dots) so nothing jumps when the slides arrive.
class _OnBoardingSkeleton extends StatelessWidget {
  const _OnBoardingSkeleton();

  @override
  Widget build(BuildContext context) {
    return DsResponsive(
      maxWidth: DsLayout.contentMax,
      padded: true,
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const DsGap(DsSpace.xl),
            Expanded(
              child: DsSkeleton.box(width: double.infinity, radius: DsRadius.xxl),
            ),
            const DsGap(DsSpace.xl),
            DsSkeleton.line(width: 220, height: 24),
            const DsGap(DsSpace.md),
            DsSkeleton.line(width: double.infinity),
            const DsGap(DsSpace.sm),
            DsSkeleton.line(width: 240),
            const DsGap(DsSpace.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [DsSkeleton.line(width: 38, height: 10), const DsGap(DsSpace.sm), DsSkeleton.line(width: 10, height: 10), const DsGap(DsSpace.sm), DsSkeleton.line(width: 10, height: 10)],
            ),
            const DsGap(DsSpace.xxl),
          ],
        ),
      ),
    );
  }
}
