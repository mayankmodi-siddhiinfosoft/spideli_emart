import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/on_boarding_controller.dart';
import '../utils/network_image_widget.dart';
import '../utils/preferences.dart';
import 'auth_screen/login_screen.dart';

/// Archetype H – onboarding: full-bleed illustration per page, progress dots
/// instead of a counter, and the actions pinned in a sticky bar.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OnboardingController>(
      init: OnboardingController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;

        // Reads stay inside the tracked builder.
        final int current = controller.currentPage.value;
        final int total = controller.onboardingList.length;
        final bool isLast = total > 0 && current == total - 1;

        return Scaffold(
          backgroundColor: c.background,
          body: controller.isLoading.value
              ? const Center(child: DsBrandLoader())
              : Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset('assets/images/onboarding_bg.png', fit: BoxFit.cover),
                    ),
                    SafeArea(
                      child: DsResponsive(
                        maxWidth: 620,
                        child: Column(
                          children: [
                            const DsGap(DsSpace.lg),
                            Expanded(
                              child: PageView.builder(
                                controller: controller.pageController,
                                onPageChanged: controller.onPageChanged,
                                itemCount: total,
                                itemBuilder: (context, index) {
                                  final item = controller.onboardingList[index];
                                  return SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.xl),
                                    child: Column(
                                      children: [
                                        Text(
                                          item.title ?? '',
                                          style: t.display,
                                          textAlign: TextAlign.center,
                                        ),
                                        const DsGap(DsSpace.sm),
                                        Text(
                                          item.description ?? '',
                                          style: t.bodyLg.withColor(c.textSecondary),
                                          textAlign: TextAlign.center,
                                        ),
                                        const DsGap(DsSpace.xxxl),
                                        ClipRRect(
                                          borderRadius: DsRadius.brXl,
                                          child: NetworkImageWidget(
                                            imageUrl: item.image ?? '',
                                            width: double.infinity,
                                            height: 440,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const DsGap(DsSpace.lg),
                            _Dots(current: current, total: total),
                            const DsGap(DsSpace.lg),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: controller.isLoading.value
              ? null
              : DsStickyBar(
                  child: isLast
                      ? DsButton.primary(
                          label: "Let’s Get Started".tr,
                          icon: Icons.arrow_forward_rounded,
                          size: DsButtonSize.lg,
                          expand: true,
                          onPressed: () {
                            _finish();
                          },
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: DsButton.secondary(
                                label: "Skip".tr,
                                size: DsButtonSize.lg,
                                expand: true,
                                onPressed: () => _finish(),
                              ),
                            ),
                            const DsGap(DsSpace.md),
                            Expanded(
                              child: DsButton.primary(
                                label: "Next".tr,
                                trailingIcon: Icons.arrow_forward_rounded,
                                size: DsButtonSize.lg,
                                expand: true,
                                onPressed: () {
                                  controller.nextPage();
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

  Future<void> _finish() async {
    await Preferences.setBoolean(Preferences.isFinishOnBoardingKey, true);
    Get.offAll(() => const LoginScreen());
  }
}

/// Animated page indicator (the active dot stretches).
class _Dots extends StatelessWidget {
  final int current;
  final int total;

  const _Dots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Semantics(
      label: "${current + 1}/$total",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: DsMotion.of(context, DsMotion.base),
              curve: DsMotion.emphasized,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 8,
              width: i == current ? 24 : 8,
              decoration: BoxDecoration(
                color: i == current ? c.brand : c.borderStrong,
                borderRadius: DsRadius.brPill,
              ),
            ),
        ],
      ),
    );
  }
}
