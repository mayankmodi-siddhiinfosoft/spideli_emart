import 'package:customer/constant/assets.dart';
import 'package:customer/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/on_boarding_controller.dart';
import '../../utils/network_image_widget.dart';
import '../../utils/preferences.dart';
import '../auth_screens/login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OnboardingController>(
      init: OnboardingController(),
      builder: (controller) {
        final c = context.dsColors;
        final t = context.dsText;
        final l = context.dsLayout;
        final pageCount = controller.onboardingList.length;
        final current = controller.currentPage.value;
        final isLast = current == pageCount - 1;

        return Scaffold(
          backgroundColor: c.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(AppAssets.onBoardingBG, fit: BoxFit.cover),
              // Fade the decorative backdrop into the page surface so text
              // stays readable in light and dark.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.background.withValues(alpha: 0.10), c.background.withValues(alpha: 0.86), c.background],
                    stops: const [0.0, 0.46, 0.68],
                  ),
                ),
              ),
              SafeArea(
                child: DsResponsive(
                  maxWidth: DsLayout.contentMax,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: l.gutter, vertical: DsSpace.lg),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: DsSpace.xs),
                            decoration: BoxDecoration(color: c.surface.withValues(alpha: 0.72), borderRadius: DsRadius.brPill, border: Border.all(color: c.border)),
                            child: RichText(
                              text: TextSpan(
                                style: t.labelSm.tabular,
                                children: [
                                  TextSpan(text: "${current + 1}", style: t.labelSm.tabular.withColor(c.textPrimary).w700),
                                  TextSpan(text: "/$pageCount", style: t.labelSm.tabular.withColor(c.textMuted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const DsGap(DsSpace.md),
                        Expanded(
                          child: PageView.builder(
                            controller: controller.pageController,
                            onPageChanged: controller.onPageChanged,
                            itemCount: pageCount,
                            itemBuilder: (context, index) {
                              final item = controller.onboardingList[index];
                              return SingleChildScrollView(
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: DsRadius.brXxl,
                                      child: NetworkImageWidget(imageUrl: item.image ?? '', width: double.infinity, height: 420, showShimmer: false),
                                    ),
                                    const DsGap(DsSpace.xxxl),
                                    Text(item.title ?? '', style: t.headline.w700, textAlign: TextAlign.center),
                                    const DsGap(DsSpace.sm),
                                    Text(item.description ?? '', style: t.body.withColor(c.textSecondary), textAlign: TextAlign.center),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const DsGap(DsSpace.xl),
                        _Dots(count: pageCount, current: current),
                        const DsGap(DsSpace.xl),
                        isLast
                            ? DsButton.primary(
                                label: "Let’s Get Started".tr,
                                size: DsButtonSize.lg,
                                expand: true,
                                trailingIcon: Icons.arrow_forward_rounded,
                                onPressed: () {
                                  _finish();
                                },
                              )
                            : Row(
                                children: [
                                  Expanded(child: DsButton.secondary(label: "Skip".tr, size: DsButtonSize.lg, expand: true, onPressed: () => _finish())),
                                  const DsGap(DsSpace.md),
                                  Expanded(
                                    child: DsButton.primary(
                                      label: "Next".tr,
                                      size: DsButtonSize.lg,
                                      expand: true,
                                      trailingIcon: Icons.arrow_forward_rounded,
                                      onPressed: () {
                                        controller.nextPage();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ],
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

/// Page indicator: the active page stretches into a brand pill.
class _Dots extends StatelessWidget {
  final int count;
  final int current;
  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: DsMotion.of(context, DsMotion.base),
            curve: DsMotion.emphasized,
            margin: const EdgeInsets.symmetric(horizontal: DsSpace.xs),
            width: i == current ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(color: i == current ? c.brand : c.borderStrong, borderRadius: DsRadius.brPill),
          ),
      ],
    );
  }
}
