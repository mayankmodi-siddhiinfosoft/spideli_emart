import 'package:spideliworker/controller/splash_controller.dart';
import 'package:spideliworker/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Launch screen: the brand logo on a soft brand wash, easing in, with a
/// quiet spinner while the controller decides where to route.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
        init: SplashController(),
        builder: (controller) {
          final c = context.dsColors;
          final l = context.dsLayout;
          final double logoWidth = l.isPhone ? 200 : 240;
          return Scaffold(
            backgroundColor: c.surface,
            body: DecoratedBox(
              decoration: BoxDecoration(gradient: DsGradients.subtle(context)),
              child: SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: DsFadeSlideIn(
                        offset: const Offset(0, 12),
                        duration: DsMotion.slower,
                        child: Semantics(
                          image: true,
                          label: 'spideli'.tr,
                          child: Image.asset(
                            "assets/images/app_logo.png",
                            width: logoWidth,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: DsSpace.huge,
                      child: DsFadeSlideIn(
                        delay: DsMotion.slow,
                        child: Center(child: DsSpinner(size: 22, color: c.brand)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
