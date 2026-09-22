import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:vendor/controller/splash_controller.dart';
import 'package:vendor/themes/ds/ds.dart';

/// Brand splash. All routing decisions live in [SplashController]; this
/// widget only paints: a brand gradient with soft light blooms, the logo
/// scaling in, the tagline fading up and a quiet progress indicator.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      init: SplashController(),
      builder: (controller) {
        final l = context.dsLayout;
        final double logoSize = l.value(phone: 132.0, tablet: 168.0, desktop: 180.0);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            body: Container(
              decoration: BoxDecoration(gradient: DsGradients.brand(context)),
              child: Stack(
                children: [
                  // Soft light blooms for depth.
                  Positioned(top: -120, right: -80, child: _Bloom(size: 320, alpha: 0.14)),
                  Positioned(bottom: -140, left: -100, child: _Bloom(size: 360, alpha: 0.10)),
                  SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: DsSpace.xxl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.82, end: 1),
                                    duration: DsMotion.of(context, DsMotion.slower),
                                    curve: DsMotion.spring,
                                    builder: (_, v, child) => Opacity(opacity: ((v - 0.82) / 0.18).clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
                                    child: Semantics(image: true, label: "Welcome to spideli Store".tr, child: Image.asset("assets/images/ic_logo.png", height: logoSize)),
                                  ),
                                  const DsGap(DsSpace.xxl),
                                  DsFadeSlideIn(
                                    delay: const Duration(milliseconds: 220),
                                    child: Text(
                                      "Welcome to spideli Store".tr,
                                      textAlign: TextAlign.center,
                                      style: DsTypography.headline.copyWith(color: Colors.white),
                                    ),
                                  ),
                                  const DsGap(DsSpace.sm),
                                  DsFadeSlideIn(
                                    delay: const Duration(milliseconds: 320),
                                    child: Text(
                                      "Your spideli, Your Products, Delivered Fast!".tr,
                                      textAlign: TextAlign.center,
                                      style: DsTypography.bodyLg.copyWith(color: Colors.white.withValues(alpha: 0.86)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: DsSpace.xxxl),
                          child: DsSpinner(size: 22, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Bloom extends StatelessWidget {
  final double size;
  final double alpha;
  const _Bloom({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Colors.white.withValues(alpha: alpha), Colors.white.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
