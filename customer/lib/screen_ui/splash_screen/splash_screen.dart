import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/assets.dart';
import '../../controllers/splash_controller.dart';
import '../../themes/ds/ds.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      init: SplashController(),
      builder: (controller) {
        final t = context.dsText;
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: DsGradients.brand(context)),
            child: SafeArea(
              child: Stack(
                children: [
                  // Soft light blobs give the flat brand fill some depth.
                  Positioned(top: -90, right: -70, child: _Blob(size: 260, opacity: 0.16)),
                  Positioned(bottom: -60, left: -80, child: _Blob(size: 220, opacity: 0.10)),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DsFadeSlideIn(
                          offset: const Offset(0, 24),
                          child: Container(
                            padding: const EdgeInsets.all(DsSpace.xxl),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: DsRadius.brXxl,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                            ),
                            child: Image.asset(AppAssets.icAppLogo, height: 96, width: 96),
                          ),
                        ),
                        const DsGap(DsSpace.xl),
                        DsFadeSlideIn(
                          index: 1,
                          child: Text("spideli".tr, style: t.display.copyWith(color: Colors.white, letterSpacing: 0.4)),
                        ),
                        const DsGap(DsSpace.sm),
                        DsFadeSlideIn(
                          index: 2,
                          child: Text(
                            "Everything you need, delivered".tr,
                            textAlign: TextAlign.center,
                            style: t.body.copyWith(color: Colors.white.withValues(alpha: 0.82)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: DsSpace.giant,
                    child: Center(child: DsSpinner(size: 22, color: Colors.white.withValues(alpha: 0.85))),
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

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
      ),
    );
  }
}
