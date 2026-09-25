import 'package:driver/controllers/splash_controller.dart';
import 'package:driver/themes/ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Archetype L – brand splash: full-bleed brand gradient, logo lock-up and an
/// indeterminate brand loader while the app boots.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      init: SplashController(),
      builder: (controller) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            body: DecoratedBox(
              decoration: BoxDecoration(gradient: DsGradients.brand(context)),
              child: SafeArea(
                child: Center(
                  child: DsResponsive(
                    // Fill the Center, and center the content inside it.
                    alignment: Alignment.center,
                    maxWidth: 440,
                    padded: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: DsFadeSlideIn.stagger(
                        [
                          Container(
                            padding: const EdgeInsets.all(DsSpace.xl),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: DsRadius.brXxl,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                            ),
                            child: Image.asset(
                              "assets/images/ic_logo.png",
                              height: 100,
                            ),
                          ),
                          const DsGap(DsSpace.xxl),
                          Text(
                            "Welcome to spideli Driver".tr,
                            textAlign: TextAlign.center,
                            style: DsTypography.display.copyWith(color: Colors.white),
                          ),
                          const DsGap(DsSpace.sm),
                          Text(
                            "Your Favorite Ride, Parcel, Rental & Item Delivered Fast!".tr,
                            textAlign: TextAlign.center,
                            style: DsTypography.body.copyWith(color: Colors.white.withValues(alpha: 0.86)),
                          ),
                          const DsGap(DsSpace.huge),
                          const Center(child: DsSpinner(size: 26, color: Colors.white)),
                        ],
                        offset: const Offset(0, 22),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
