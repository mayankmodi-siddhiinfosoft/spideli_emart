import 'package:spideliworker/controller/on_boarding_controller.dart';
import 'package:spideliworker/services/preferences.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:spideliworker/ui/login/login_screen.dart';
import 'package:spideliworker/utils/dark_theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

/// Onboarding: a full-bleed illustration per page, an animated pill page
/// indicator and the copy on a width-capped column, with "Next" as the
/// primary action and "Skip" as a quiet ghost button beneath it.
class OnBoardingScreen extends StatelessWidget {
  const OnBoardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Subscribes the page to theme changes.
    Provider.of<DarkThemeProvider>(context);
    return GetX<OnBoardingController>(
      init: OnBoardingController(),
      builder: (controller) {
        // Read synchronously so this GetX tracks the page and the loader.
        final bool isLoading = controller.isLoading.value;
        final int selected = controller.selectedPageIndex.value;
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;

        return Scaffold(
          backgroundColor: c.background,
          body: SafeArea(
            child: isLoading
                ? const _OnBoardingSkeleton()
                : Column(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs),
                          child: selected == 2
                              ? const SizedBox(height: 48)
                              : DsButton.ghost(
                                  label: 'Skip'.tr,
                                  size: DsButtonSize.sm,
                                  onPressed: () {
                                    Preferences.setBoolean(Preferences.isFinishOnBoardingKey, true);
                                    Get.offAll(const LoginScreen());
                                  },
                                ),
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                            controller: controller.pageController,
                            onPageChanged: controller.selectedPageIndex.call,
                            itemCount: controller.onBoardingList.length,
                            itemBuilder: (context, index) {
                              return DsResponsive(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: l.gutter),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: DsImage(
                                          url: controller.onBoardingList[index].image.toString(),
                                          fit: BoxFit.contain,
                                          radius: DsRadius.xl,
                                          width: double.infinity,
                                        ),
                                      ),
                                      const DsGap(DsSpace.xxl),
                                      Text(
                                        controller.onBoardingList[index].title.toString().tr,
                                        textAlign: TextAlign.center,
                                        style: t.display,
                                      ),
                                      const DsGap(DsSpace.md),
                                      Text(
                                        controller.onBoardingList[index].description.toString().tr,
                                        textAlign: TextAlign.center,
                                        style: t.bodySecondary,
                                      ),
                                      const DsGap(DsSpace.xl),
                                    ],
                                  ),
                                ),
                              );
                            }),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: DsSpace.xl),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            controller.onBoardingList.length,
                            (index) => AnimatedContainer(
                              duration: DsMotion.of(context, DsMotion.base),
                              curve: DsMotion.standard,
                              margin: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
                              width: selected == index ? 32 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: selected == index ? c.brand : c.borderStrong,
                                borderRadius: DsRadius.brPill,
                              ),
                            ),
                          ),
                        ),
                      ),
                      DsStickyBar(
                        child: DsButton.primary(
                          label: 'Next'.tr,
                          trailingIcon: Icons.arrow_forward_rounded,
                          size: DsButtonSize.lg,
                          expand: true,
                          onPressed: () {
                            if (controller.selectedPageIndex.value == 2) {
                              Preferences.setBoolean(Preferences.isFinishOnBoardingKey, true);
                              Get.offAll(const LoginScreen());
                            } else {
                              controller.pageController.jumpToPage(controller.selectedPageIndex.value + 1);
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
}

class _OnBoardingSkeleton extends StatelessWidget {
  const _OnBoardingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DsSpace.xxl),
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            Expanded(flex: 6, child: DsSkeleton.box(width: double.infinity, radius: DsRadius.xl)),
            const DsGap(DsSpace.xxl),
            DsSkeleton.line(width: 220, height: 22),
            const DsGap(DsSpace.md),
            DsSkeleton.line(width: 280),
            const DsGap(DsSpace.sm),
            DsSkeleton.line(width: 200),
            const Spacer(),
            DsSkeleton.box(width: double.infinity, height: 56, radius: DsRadius.pill),
          ],
        ),
      ),
    );
  }
}
