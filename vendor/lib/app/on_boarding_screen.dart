import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../themes/ds/ds.dart';
import '../utils/network_image_widget.dart';
import '../utils/preferences.dart';
import '../controller/on_boarding_controller.dart';
import 'auth_screen/login_screen.dart';

/// Onboarding carousel: a framed illustration per page, a bold title and
/// description, an animated page indicator and a bottom action area that
/// morphs into "Let's Get Started" on the last page.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OnboardingController>(
      init: OnboardingController(),
      builder: (controller) {
        final pageCount = controller.onboardingList.length;
        final c = context.dsColors;
        final t = context.dsText;
        final bool isLast = controller.currentPage.value == pageCount - 1;
        return Scaffold(
          backgroundColor: c.background,
          body: controller.isLoading.value
              ? const _OnboardingSkeleton()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/onboarding_bg.png', fit: BoxFit.cover),
                    // Keeps the artwork from fighting the content in dark mode.
                    if (c.isDark) ColoredBox(color: c.background.withValues(alpha: 0.86)),
                    SafeArea(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(DsSpace.xl, DsSpace.lg, DsSpace.xl, DsSpace.xl),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _PageDots(count: pageCount, current: controller.currentPage.value),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                                      decoration: BoxDecoration(color: c.surface.withValues(alpha: 0.9), borderRadius: DsRadius.brPill, border: Border.all(color: c.border)),
                                      child: RichText(
                                        textScaler: MediaQuery.textScalerOf(context),
                                        text: TextSpan(
                                          style: t.labelSm,
                                          children: [
                                            TextSpan(text: "${controller.currentPage.value + 1}", style: t.labelSm.copyWith(color: c.textPrimary)),
                                            TextSpan(text: "/$pageCount", style: t.labelSm.copyWith(color: c.textMuted)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const DsGap(DsSpace.lg),
                                Expanded(
                                  child: PageView.builder(
                                    controller: controller.pageController,
                                    onPageChanged: controller.onPageChanged,
                                    itemCount: pageCount,
                                    itemBuilder: (context, index) {
                                      final item = controller.onboardingList[index];
                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          final double imageHeight = (constraints.maxHeight * 0.6).clamp(180.0, 500.0);
                                          return SingleChildScrollView(
                                            child: Column(
                                              children: DsFadeSlideIn.stagger([
                                                Container(
                                                  height: imageHeight,
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(color: c.surface, borderRadius: DsRadius.brXxl, boxShadow: DsShadows.md(context)),
                                                  clipBehavior: Clip.antiAlias,
                                                  child: NetworkImageWidget(imageUrl: item.image ?? '', width: double.infinity, height: imageHeight),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.only(top: DsSpace.xxl),
                                                  child: Text(item.title ?? '', style: t.display.copyWith(color: c.brandStrong), textAlign: TextAlign.center),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.only(top: DsSpace.sm),
                                                  child: Text(item.description ?? '', style: t.bodyLg.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
                                                ),
                                              ]),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const DsGap(DsSpace.xl),
                                AnimatedSwitcher(
                                  duration: DsMotion.of(context, DsMotion.base),
                                  switchInCurve: DsMotion.emphasized,
                                  transitionBuilder: (child, animation) => FadeTransition(
                                    opacity: animation,
                                    child: SizeTransition(sizeFactor: animation, child: child),
                                  ),
                                  child: isLast
                                      ? DsButton.primary(
                                          key: const ValueKey('start'),
                                          label: "Let’s Get Started".tr,
                                          trailingIcon: Icons.arrow_forward_rounded,
                                          size: DsButtonSize.lg,
                                          expand: true,
                                          onPressed: () {
                                            _finish();
                                          },
                                        )
                                      : Row(
                                          key: const ValueKey('nav'),
                                          children: [
                                            Expanded(
                                              child: DsButton.secondary(label: "Skip".tr, size: DsButtonSize.lg, onPressed: () => _finish()),
                                            ),
                                            DsGap.lg,
                                            Expanded(
                                              child: DsButton.primary(
                                                label: "Next".tr,
                                                trailingIcon: Icons.arrow_forward_rounded,
                                                size: DsButtonSize.lg,
                                                onPressed: () {
                                                  controller.nextPage();
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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

/// Animated page indicator: the current page is a wide brand pill.
class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Semantics(
      label: '${current + 1} / $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < count; i++)
            AnimatedContainer(
              duration: DsMotion.of(context, DsMotion.base),
              curve: DsMotion.emphasized,
              margin: const EdgeInsetsDirectional.only(end: 6),
              width: i == current ? 26 : 8,
              height: 8,
              decoration: BoxDecoration(color: i == current ? c.brand : c.borderStrong, borderRadius: DsRadius.brPill),
            ),
        ],
      ),
    );
  }
}

class _OnboardingSkeleton extends StatelessWidget {
  const _OnboardingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DsShimmer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(DsSpace.xl),
              child: Column(
                children: [
                  Row(children: [DsSkeleton.line(width: 60, height: 8), const Spacer(), DsSkeleton.box(width: 44, height: 24, radius: DsRadius.pill)]),
                  const DsGap(DsSpace.lg),
                  Expanded(flex: 3, child: DsSkeleton.box(radius: DsRadius.xxl)),
                  const DsGap(DsSpace.xxl),
                  DsSkeleton.line(width: 220, height: 24),
                  const DsGap(DsSpace.md),
                  DsSkeleton.line(width: 280),
                  const DsGap(DsSpace.sm),
                  DsSkeleton.line(width: 200),
                  const Spacer(),
                  Row(children: [Expanded(child: DsSkeleton.box(height: 56)), const DsGap(DsSpace.lg), Expanded(child: DsSkeleton.box(height: 56))]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
